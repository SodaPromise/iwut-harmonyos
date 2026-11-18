import { WebNetErrorList, webview } from '@kit.ArkWeb';
import { BIND_PROFILE_PAGE, BIND_PROFILE_ROOT, bindingHttpsRedirect } from '../model/AcademicBinding';
import { AcademicResult } from '../model/Iwut';

@Component
export struct CampusWeb {
  url: string = '';
  prefix: string = '';
  script: string = '';
  documentScripts: ScriptItem[] = [];
  binding: boolean = false;
  controller: webview.WebviewController = new webview.WebviewController();
  onResult: (value: AcademicResult) => void = () => {};
  @State loading: boolean = true;
  @State failure: string = '';
  private epoch: number = 0;
  private timer: number = -1;
  private readPending: boolean = false;
  private pendingNavigation: number = -1;
  private replacedUrl: string = '';
  private profileFallbackUsed: boolean = false;
  private upgraded: Set<string> = new Set<string>();

  aboutToDisappear(): void {
    this.clear();
    if (this.pendingNavigation !== -1) clearTimeout(this.pendingNavigation);
    this.pendingNavigation = -1;
  }

  private showFailure(message: string): void {
    this.clear();
    this.loading = false;
    this.failure = message;
  }

  private navigate(url: string, replacedUrl: string = ''): void {
    this.clear();
    this.replacedUrl = replacedUrl;
    this.failure = '';
    this.loading = true;
    if (this.pendingNavigation !== -1) clearTimeout(this.pendingNavigation);
    this.pendingNavigation = setTimeout(() => {
      this.pendingNavigation = -1;
      try {
        this.controller.loadUrl(url);
      } catch (_) {
        this.showFailure('无法打开页面，请重新载入。');
      }
    }, 0);
  }

  private isReplacedNavigation(url: string): boolean {
    return this.pendingNavigation !== -1 || (this.replacedUrl.length > 0 && this.replacedUrl === url);
  }

  private recoverProfilePage(url: string): boolean {
    if (!this.binding || this.profileFallbackUsed || url !== BIND_PROFILE_ROOT) return false;
    this.profileFallbackUsed = true;
    this.navigate(BIND_PROFILE_PAGE, url);
    return true;
  }

  private intercept(request: WebResourceRequest): boolean {
    const url = request.getRequestUrl();
    if (this.binding && request.isMainFrame()) {
      const secureUrl = bindingHttpsRedirect(url);
      if (secureUrl && request.getRequestMethod().toUpperCase() === 'GET') {
        if (!this.upgraded.has(secureUrl)) {
          this.upgraded.add(secureUrl);
          this.navigate(secureUrl, url);
        } else if (this.pendingNavigation === -1) {
          this.showFailure('学校登录页面反复重定向，请重新载入。');
        }
        return true;
      }
      if (!url.startsWith('https://')) {
        this.showFailure('学校登录页面暂时无法打开，请重新载入。');
        return true;
      }
    }
    return !(url.startsWith('https://') || (!this.prefix && url.startsWith('http://')) ||
      (this.binding && !request.isMainFrame() && url === 'about:blank'));
  }

  private reload(): void {
    if (this.binding) {
      this.profileFallbackUsed = false;
      this.upgraded.clear();
      this.navigate(this.url);
    } else {
      this.failure = '';
      this.controller.refresh();
    }
  }

  private clear(): void {
    this.epoch++;
    if (this.timer >= 0) clearInterval(this.timer);
    this.timer = -1;
  }

  private poll(url: string): void {
    if (!this.prefix || !this.script || !url.startsWith(this.prefix)) return;
    this.clear();
    const epoch = this.epoch;
    const start = Date.now();
    const expression = 'location.href.startsWith(' + JSON.stringify(this.prefix) +
      ') ? (window.__iwutAcademicResult || "") : ""';
    this.controller.runJavaScript(this.script).catch(() => {
      if (epoch === this.epoch) this.showFailure('无法读取教务页面。请重试。');
    });
    this.timer = setInterval(async () => {
      if (epoch !== this.epoch) return;
      if (Date.now() - start > 65000) {
        this.showFailure('等待教务数据超时，请确认登录和校园网连接。');
        return;
      }
      if (this.readPending) return;
      this.readPending = true;
      try {
        const raw = await this.controller.runJavaScript(expression);
        if (epoch !== this.epoch || !raw || raw === '""' || raw === 'null') return;
        const body: string = raw.startsWith('"') ? JSON.parse(raw) as string : raw;
        if (!body.startsWith('{') || body.length > 2000000) return;
        const result = JSON.parse(body) as AcademicResult;
        if (typeof result.type !== 'string') return;
        this.clear();
        this.onResult(result);
      } catch (_) {
        // A navigation can interrupt an in-flight read. The next loaded page owns the timer.
      } finally {
        this.readPending = false;
      }
    }, 450);
  }

  build() {
    Column() {
      if (this.loading) {
        Progress({ value: 28, total: 100, type: ProgressType.Linear }).width('100%').color('#3B75E8')
      }
      if (this.failure) {
        Row({ space: 10 }) {
          Text(this.failure).layoutWeight(1).fontSize(13).fontColor('#70420B')
          Button('重新载入', { type: ButtonType.Normal }).fontSize(12).onClick(() => this.reload())
        }.padding(12).width('100%').backgroundColor('#FFF0D8')
      }
      Web({ src: this.url, controller: this.controller })
        .layoutWeight(1)
        .width('100%')
        .javaScriptAccess(true)
        .javaScriptOnDocumentStart(this.documentScripts)
        .domStorageAccess(true)
        .fileAccess(false)
        .mixedMode(MixedMode.None)
        .onLoadIntercept(event => this.intercept(event.data))
        .onPageBegin(event => {
          if (this.isReplacedNavigation(event?.url ?? '')) return;
          this.clear();
          this.failure = '';
          this.loading = true;
        })
        .onPageEnd(event => {
          if (this.isReplacedNavigation(event?.url ?? '')) return;
          this.replacedUrl = '';
          this.loading = false;
          if (event && !this.failure) this.poll(event.url);
        })
        .onHttpErrorReceive(event => {
          if (!event?.request.isMainFrame()) return;
          const url = event.request.getRequestUrl();
          if (this.isReplacedNavigation(url)) return;
          const statusCode = event.response.getResponseCode();
          if (statusCode === 404 && this.recoverProfilePage(url)) return;
          if (this.binding) this.showFailure('学校登录页面载入失败（HTTP ' + statusCode + '）。');
        })
        .onErrorReceive(event => {
          if (!event?.request.isMainFrame()) return;
          const url = event.request.getRequestUrl();
          if (this.isReplacedNavigation(url)) return;
          const code = event.error.getErrorCode();
          if (this.binding && code === WebNetErrorList.ERR_ABORTED) return;
          if (code === WebNetErrorList.ERR_HTTP_RESPONSE_CODE_FAILURE && this.recoverProfilePage(url)) return;
          this.showFailure('页面载入失败。请确认网络，校内服务可能需要连接校园网。');
        })
    }.width('100%').layoutWeight(1)
  }
}
