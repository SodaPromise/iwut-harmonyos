import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { generateBarcode, scanCore } from '@kit.ScanKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { copyText } from '../services/Platform';

const ARKUI_QR_MAX_BYTES = 512;
const SCAN_KIT_TEXT_MAX_LENGTH = 512;
const SHARE_QR_MAX_BYTES = 1800;

@Component
export struct CourseShareSheet {
  @Prop @Watch('refreshQr') value: string = '';
  @Prop link: string = '';
  @Prop ink: string = '#172136';
  @Prop muted: string = '#52627A';
  @Prop tile: string = '#F2F5FA';
  t: (key: string) => string = (key: string): string => key;
  onMessage: (message: string) => void = () => {};
  @State qrText: string = '';
  @State qr: image.PixelMap | null = null;
  @State problem: string = '';
  private qrRequest: number = 0;
  private active: boolean = false;
  private sharing: boolean = false;

  aboutToAppear(): void {
    this.active = true;
    this.refreshQr();
  }

  aboutToDisappear(): void {
    this.active = false;
    this.qrRequest++;
    this.releaseQr();
  }

  private releaseQr(): void {
    const qr = this.qr;
    this.qr = null;
    if (qr) void qr.release().catch(() => {});
  }

  private refreshQr(): void {
    if (!this.active) return;
    const request = ++this.qrRequest;
    this.releaseQr();
    this.qrText = '';
    this.problem = '';
    const value = this.value;
    if (value) void this.makeQr(value, request);
  }

  private async makeQr(value: string, request: number): Promise<void> {
    try {
      const bytes = util.TextEncoder.create('utf-8').encodeInto(value);
      if (bytes.byteLength <= ARKUI_QR_MAX_BYTES) {
        this.qrText = value;
        return;
      }
      if (bytes.byteLength > SHARE_QR_MAX_BYTES) {
        this.problem = this.t('share.codeTooLarge');
        return;
      }
      const qr = await this.makeLongQr(value, bytes);
      if (request === this.qrRequest) this.qr = qr;
      else await qr.release();
    } catch (_) {
      if (request === this.qrRequest) this.problem = this.t('share.codeRenderFailed');
    }
  }

  private async makeLongQr(value: string, bytes: Uint8Array): Promise<image.PixelMap> {
    const options: generateBarcode.CreateOptions = {
      scanType: scanCore.ScanType.QR_CODE, width: 800, height: 800, margin: 10,
      level: generateBarcode.ErrorCorrectionLevel.LEVEL_M
    };
    if (value.length <= SCAN_KIT_TEXT_MAX_LENGTH) {
      try {
        return await generateBarcode.createBarcode(value, options);
      } catch (_) {
        // Try the byte overload when Scan Kit rejects the text.
      }
    }
    const content = new ArrayBuffer(bytes.byteLength);
    new Uint8Array(content).set(bytes);
    return generateBarcode.createBarcode(content, options);
  }

  private async copy(): Promise<void> {
    try {
      await copyText(this.link);
      this.onMessage(this.t('share.codeCopied'));
    } catch (_) {
      this.onMessage(this.t('scan.copyFailed'));
    }
  }

  private async share(): Promise<void> {
    if (this.sharing) return;
    this.sharing = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const data = new systemShare.SharedData({
        utd: utd.UniformDataType.HYPERLINK, content: this.link, title: this.t('scan.courseShareTitle')
      });
      const controller = new systemShare.ShareController(data);
      await controller.show(context, { previewMode: systemShare.SharePreviewMode.DETAIL,
        selectionMode: systemShare.SelectionMode.SINGLE });
    } catch (_) {
      this.onMessage(this.t('scan.executeFailed'));
    } finally {
      this.sharing = false;
    }
  }

  build() {
    Column({ space: 15 }) {
      Text(this.t('scan.courseShareTitle')).width('100%').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.ink)
      Text(this.t('scan.courseShareDesc')).width('100%').fontSize(13).fontColor(this.muted)
      if (this.qrText) {
        Column() {
          QRCode(this.qrText).width('100%').height('100%').backgroundColor(Color.White).color(Color.Black)
        }.width('74%').aspectRatio(1).constraintSize({ maxWidth: 260 })
          .padding(12).backgroundColor(Color.White).borderRadius(10)
          .accessibilityText(this.t('scan.courseShareTitle'))
      } else if (this.qr) {
        Image(this.qr).width('74%').aspectRatio(1).constraintSize({ maxWidth: 260 })
          .objectFit(ImageFit.Contain).padding(9).backgroundColor(Color.White).borderRadius(10).draggable(false)
          .accessibilityText(this.t('scan.courseShareTitle'))
      } else if (this.problem) {
        Text(this.problem).width('100%').fontSize(13).fontColor(this.muted)
      } else {
        LoadingProgress().width(34).height(34).color('#317CF4').margin(12)
      }
      Row({ space: 10 }) {
        Button(this.t('share.copyCode'), { type: ButtonType.Normal }).layoutWeight(1).height(44).borderRadius(11)
          .fontColor(this.ink).backgroundColor(this.tile).onClick(() => { void this.copy(); })
        Button(this.t('share.shareCode'), { type: ButtonType.Normal }).layoutWeight(1).height(44).borderRadius(11)
          .fontColor(Color.White).backgroundColor('#317CF4').onClick(() => { void this.share(); })
      }.width('100%')
    }.width('100%').padding({ left: 18, right: 18, top: 13, bottom: 18 })
  }
}
