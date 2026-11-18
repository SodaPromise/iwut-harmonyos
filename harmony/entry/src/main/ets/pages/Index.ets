import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { ButtonModifier, SymbolGlyphModifier } from '@kit.ArkUI';
import lazy { uiMaterial } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import lazy { intelligentScene } from '@kit.BasicServicesKit';
import lazy { HdsTabs, hdsMaterial } from '@kit.UIDesignKit';
import { CampusWeb } from '../components/CampusWeb';
import { CourseEditor } from '../components/CourseEditor';
import { CourseDetailCard, QuickCourseCard } from '../components/CourseOverlays';
import { CourseShareSheet } from '../components/CourseShareSheet';
import { ExamSchedule } from '../components/ExamSchedule';
import { LabImport } from '../components/LabImport';
import { WlanPage } from '../components/WlanPage';
import { MenuGroup, MenuGroups, MenuRow } from '../components/Menu';
import { Timetable } from '../components/Timetable';
import {
  AcademicResult, AcademicRoute, Course, Data, Exam, Grade, LocalData, Palette, Period, Profile, Settings,
  Shortcut, ShortcutGroup, UpstreamResources, campusDay, courseColor, courseTime, coursesForCampusDay,
  currentWeek, homeCourseTiming, homeGreetingKey, localDate, shortcutVisible, validCourses, validPalette
} from '../model/Iwut';
import { alignQuickSlot, CourseSlotRange, overlappingWeeks, QuickCourseDraft, quickCourseRecords, weekList } from '../model/CourseDraft';
import { languageKey, settingsMenu, themeKey } from '../model/SettingsMenus';
import { AcademicCalendarResult, examEnd, examStart, syncAcademicCalendar } from '../services/AcademicSchedule';
import { campusMiniAppScripts } from '../services/CampusMiniApps';
import { updateScheduleCards } from '../services/ScheduleCards';
import { readWlanAccount, removeWlanAccount } from '../services/Wlan';
import {
  clickFeedback, copyText, courseBackup, courseShareLink, courseShareText, envelopeCourses, envelopePalette, pasteText,
  pickBackground, readCourseBackup, saveFile, scan, scanResult, ShareEnvelope
} from '../services/Platform';

const TAB_BAR_HEIGHT = 58;
const PAGE_TOP_INSET = 8;
const PAGE_TITLE_HEIGHT = 44;
const SUBPAGE_TITLE_HEIGHT = 64;
const TAB_ANIMATION = 260;
const TAB_FADE = 220;

interface Option {
  id: string;
  label: string;
}

@Entry
@Component
struct Index {
  @State data: Data = new Data();
  @State mainTab: number = 0;
  @State pageStack: NavPathStack = new NavPathStack();
  @State tabFade: number = 1;
  @State tabTapped: number = -1;
  @State menuRevision: number = 0;
  @State accepted: boolean = false;
  @State setup: boolean = false;
  @State week: number = 1;
  @State tomorrow: boolean = false;
  @State loaded: boolean = false;
  @StorageLink('iwutSystemDark') @Watch('syncSystemBars') systemDark: boolean = false;
  @State webTitle: string = '';
  @State webUrl: string = '';
  @State webPrefix: string = '';
  @State webScript: string = '';
  private webDocumentScripts: ScriptItem[] = [];
  @State choiceTitle: string = '';
  @State choiceOptions: Option[] = [];
  @State selection: Course | null = null;
  @State courseModal: string = '';
  @State quickSlot: CourseSlotRange = { day: 1, sectionStart: 1, sectionEnd: 2 };
  @State editPrefill: QuickCourseDraft | null = null;
  @State courseShareVisible: boolean = false;
  @State sharePayload: string = '';
  @State gradeTerm: string = '';
  @State examTab: number = 0;
  @State qrText: string = '';
  @State logQuery: string = '';
  @State logs: string[] = [];
  @State currentTime: number = Date.now();
  @State storageProblem: string = '';
  @State quietSync: boolean = false;
  @StorageLink('iwutSharedLink') @Watch('incomingShare') sharedLink: string = '';
  @StorageLink('iwutShortcut') @Watch('incomingShortcut') shortcut: string = '';
  private timer: number = -1;
  private context?: common.UIAbilityContext;
  private resources?: UpstreamResources;
  private storage?: LocalData;
  private browser: webview.WebviewController = new webview.WebviewController();
  private activeAcademic: string = '';
  private quietRoute?: AcademicRoute;
  private quietBrowser: webview.WebviewController = new webview.WebviewController();
  private quietTimer: number = -1;
  private attemptedSync: number = 0;
  private chooseAction: (id: string) => void = () => {};
  @State doingIntegration: boolean = false;
  private integrationPending: boolean = false;
  private calendarCheckedOnLaunch: boolean = false;
  private scanning: boolean = false;
  private shortcutIcons: Record<string, Resource> = {
    'bar-chart-outline': $r('app.media.shortcut_bar_chart_outline'),
    'calendar-clear-outline': $r('app.media.shortcut_calendar_clear_outline'),
    'book-outline': $r('app.media.shortcut_book_outline'),
    'easel-outline': $r('app.media.shortcut_easel_outline'),
    'library-outline': $r('app.media.shortcut_library_outline'),
    'card-outline': $r('app.media.shortcut_card_outline'),
    'flash-outline': $r('app.media.shortcut_flash_outline'),
    'wifi-outline': $r('app.media.shortcut_wifi_outline'),
    'newspaper-outline': $r('app.media.shortcut_newspaper_outline')
  };
  private tabs: string[] = ['nav.home', 'nav.course', 'nav.function', 'nav.user'];
  private tabIcons: Resource[] = [
    $r('sys.symbol.house'), $r('sys.symbol.calendar'), $r('sys.symbol.square_grid_2x2'), $r('sys.symbol.person')
  ];
  private floatingTabs: boolean = deviceInfo.sdkApiVersion >= 23 && canIUse('SystemCapability.UIDesign.HDSComponent.Core');
  private titleButtonStyle: ButtonModifier = new ButtonModifier();
  private titleMaterialSupported: boolean = false;

  aboutToAppear(): void {
    if (deviceInfo.apiAvailable('26.0.0')) {
      this.titleMaterialSupported = uiMaterial.isImmersiveMaterialSupported();
      this.titleButtonStyle.systemMaterial(new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN,
        interactive: true,
        lightEffect: {}
      }));
    }
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.resources = new UpstreamResources(this.context);
    this.storage = new LocalData(this.context);
    this.data = this.storage.read();
    this.accepted = this.data.onboarding;
    this.mainTab = this.data.settings.openCourseOnLaunch ? 1 : 0;
    this.week = currentWeek(this.data.termStart, new Date());
    this.loaded = true;
    this.record('应用启动');
  }

  onPageShow(): void {
    this.syncNativeTheme();
    this.syncSystemBars();
    this.currentTime = Date.now();
    if (this.timer === -1) this.timer = setInterval(() => {
      this.currentTime = Date.now();
      this.maybeSync();
    }, 60000);
    this.incomingShare();
    this.incomingShortcut();
    this.maybeSync();
    if (!this.calendarCheckedOnLaunch) {
      this.calendarCheckedOnLaunch = true;
      void this.refreshIntegrations();
    }
  }

  onPageHide(): void {
    if (this.timer >= 0) clearInterval(this.timer);
    this.timer = -1;
    this.stopQuietSync();
  }

  aboutToDisappear(): void {
    this.onPageHide();
  }

  onBackPress(): boolean {
    if (this.courseShareVisible) {
      this.courseShareVisible = false;
      return true;
    }
    if (this.courseModal) {
      this.courseModal = '';
      return true;
    }
    if (this.page() === 'browser' && !this.activeAcademic) {
      try {
        if (this.browser.accessBackward()) {
          this.browser.backward();
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  private page(): string {
    const names = this.pageStack.getAllPathName();
    return names.length ? names[names.length - 1] : '';
  }

  private go(page: string): void {
    this.pageStack.pushPathByName(page, null, true);
  }

  private back(): void {
    this.pageStack.pop(true);
  }

  private t(key: string): string {
    return this.resources?.t(key, this.data.settings.language) ?? key;
  }

  private dark(): boolean {
    const mode = this.data.settings.theme;
    return mode === 'dark' || (mode === 'system' && this.systemDark);
  }

  private syncNativeTheme(): void {
    if (!this.floatingTabs) return;
    const theme = this.data.settings.theme;
    let colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (theme === 'dark') colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    if (theme === 'light') colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    try {
      this.context?.setColorMode(colorMode);
    } catch (_) {
      this.record('无法更新底栏主题');
    }
  }

  private syncSystemBars(): void {
    void this.applySystemBarColors();
  }

  private async applySystemBarColors(): Promise<void> {
    const contentColor = this.ink();
    try {
      await this.context?.windowStage.getMainWindowSync().setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: contentColor,
        navigationBarColor: '#00000000',
        navigationBarContentColor: contentColor
      });
    } catch (_) {
      this.record('无法更新系统栏样式');
    }
  }

  private ink(): string { return this.dark() ? '#EDF3FF' : '#172136'; }
  private muted(): string { return this.dark() ? '#ADB9D0' : '#52627A'; }
  private bg(): string { return this.dark() ? '#131922' : '#F2F5FA'; }
  private surface(): string { return this.dark() ? '#202B3B' : '#FFFFFF'; }
  private line(): string { return this.dark() ? '#35425A' : '#E8EDF4'; }
  private blue(): string { return this.dark() ? '#9DBAFF' : '#2459C4'; }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message, duration: 2300 });
  }

  private record(message: string): void {
    this.logs = this.logs.slice(-99).concat(new Date().toLocaleTimeString() + '  ' + message);
  }

  private persist(update: (next: Data) => void): void {
    const previousTheme = this.data.settings.theme;
    const next = new Data(this.data);
    update(next);
    this.data = next;
    this.menuRevision++;
    if (next.settings.theme !== previousTheme) {
      this.syncNativeTheme();
      this.syncSystemBars();
    }
    this.storage?.save(next).then(() => { this.storageProblem = ''; }).catch(() => {
      this.storageProblem = '保存失败，请检查设备剩余空间。';
    });
  }

  private setting(update: (settings: Settings) => void): void {
    this.persist(next => update(next.settings));
  }

  private confirm(title: string, message: string, confirmText: string, action: () => void,
    destructive: boolean = false): void {
    this.getUIContext().getPromptAction().showDialog({
      title, message,
      buttons: [
        { text: this.t('common.cancel'), color: this.muted() },
        { text: confirmText, color: destructive ? '#D92841' : this.blue() }
      ]
    }).then(result => { if (result.index === 1) action(); }).catch(() => {});
  }

  private choices(title: string, options: Option[], action: (id: string) => void): void {
    this.choiceTitle = title;
    this.choiceOptions = options;
    this.chooseAction = action;
    this.go('choice');
  }

  private academic(kind: string): void {
    const route = this.resources?.routes.find(value => value.kind === kind);
    if (!route) {
      if (kind === 'bind') this.toast(this.t('user.bindFailedSub'));
      return;
    }
    const label = kind === 'bind' ? this.t('user.bindScreenTitle')
      : kind === 'exam' ? this.t('exam.importTitle')
      : kind === 'grade' ? this.t('grade.queryTitle')
      : this.t('course.importTitle').replace('{type}', this.t('course.' + kind));
    this.openAcademic(route, label);
  }

  private openAcademic(route: AcademicRoute, label: string): void {
    this.openWeb(route.url, label, route);
  }

  private openWeb(url: string, title: string, api?: AcademicRoute, miniApp: boolean = false): void {
    this.stopQuietSync();
    this.browser = new webview.WebviewController();
    this.webTitle = title;
    this.webUrl = url;
    this.webPrefix = api?.prefix ?? '';
    this.webScript = api ? this.resources?.text(api.kind + '.js') ?? '' : '';
    this.activeAcademic = api?.kind ?? '';
    this.webDocumentScripts = miniApp
      ? campusMiniAppScripts(url, this.data.profile, this.resources?.text('rpc.js') ?? '') : [];
    this.go('browser');
  }

  private academicResult(result: AcademicResult): void {
    if (this.page() !== 'browser') return;
    const kind = this.activeAcademic;
    const stamp = new Date().toLocaleString();
    if (kind === 'bind' && result.type === 'profileUnavailable') {
      this.toast(this.t('user.bindProfileUnavailable'));
      this.back();
      return;
    }
    if (kind === 'bind' && result.type === 'info' && typeof result.studentId === 'string' && result.studentId.trim()) {
      const profile: Profile = {
        name: result.name ?? '', studentId: result.studentId, college: result.college ?? '',
        eduLevel: result.eduLevel ?? '', cardId: result.cardId ?? ''
      };
      this.persist(next => { next.profile = profile; });
      if (!this.data.onboarding) this.setup = true;
      this.toast(this.t('user.bindSuccess'));
    } else if ((kind === 'bachelor' && result.type === 'courses') ||
      (kind === 'master' && result.type === 'masterRows')) {
      if (!this.applyImportedCourses(kind, result)) {
        this.toast(this.t('course.parseFailed'));
        return;
      }
      this.toast(this.t('course.importSuccess'));
    } else if (kind === 'grade' && result.type === 'gradeRows' && Array.isArray(result.grades)) {
      this.persist(next => { next.grades = result.grades ?? []; next.gradesSyncedAt = stamp; });
      this.gradeTerm = '';
      this.toast(this.t('grade.querySuccess'));
    } else if (kind === 'exam' && result.type === 'examRows' && Array.isArray(result.exams)) {
      this.persist(next => {
        next.exams = result.exams ?? [];
        next.notArranged = result.notArranged ?? [];
        next.examTerm = result.term ?? '';
        next.examsSyncedAt = new Date().toISOString();
      });
      this.afterScheduleChange();
      this.toast(this.t('exam.importSuccess'));
    } else {
      this.record('教务操作失败 · ' + kind);
      this.toast(result.message?.slice(0, 110) || this.t(kind === 'bind' ? 'user.bindFailedSub' : 'course.importFailSub'));
      return;
    }
    this.record('教务操作完成 · ' + kind);
    this.back();
  }

  private applyImportedCourses(kind: string, result: AcademicResult): boolean {
    if ((kind !== 'bachelor' || result.type !== 'courses') && (kind !== 'master' || result.type !== 'masterRows')) {
      return false;
    }
    const courses = validCourses(result.data ?? result.courses ?? []);
    if (courses.length === 0) return false;
    this.persist(next => {
      courses.forEach(course => { course.source = 'imported'; });
      next.courses = validCourses(courses.concat(next.courses.filter(course => course.source !== 'imported')));
      if (typeof result.termStart === 'string' && Number.isFinite(localDate(result.termStart).getTime())) {
        next.termStart = result.termStart.slice(0, 10);
      }
      next.academicCourseKind = kind;
      next.coursesSyncedAt = new Date().toLocaleString();
      next.coursesSyncedTime = Date.now();
    });
    this.week = currentWeek(this.data.termStart, new Date());
    this.afterScheduleChange();
    return true;
  }

  private maybeSync(): void {
    const now = Date.now();
    if (!this.loaded || !this.data.onboarding || !this.data.settings.autoRefreshCourses || this.quietSync ||
      this.page() === 'browser' || now - Math.max(this.attemptedSync, this.data.coursesSyncedTime) < 1800000) return;
    const route = this.resources?.routes.find(item => item.kind === this.data.academicCourseKind);
    if (!route) return;
    this.attemptedSync = now;
    this.quietRoute = route;
    this.quietBrowser = new webview.WebviewController();
    this.quietSync = true;
    this.quietTimer = setTimeout(() => {
      this.record('静默同步结束 · 校园会话可能需要重新登录');
      this.stopQuietSync();
    }, 45000);
  }

  private stopQuietSync(): void {
    if (this.quietTimer >= 0) clearTimeout(this.quietTimer);
    this.quietTimer = -1;
    this.quietSync = false;
  }

  private quietResult(result: AcademicResult): void {
    if (!this.quietSync || !this.quietRoute) return;
    const updated = this.applyImportedCourses(this.quietRoute.kind, result);
    this.stopQuietSync();
    this.record(updated ? '已静默同步课程' : '静默课表同步未返回有效数据');
  }

  private courseImport(): void {
    this.choices(this.t('course.selectImportType'), [
      { id: 'bachelor', label: this.t('course.bachelor') },
      { id: 'master', label: this.t('course.master') },
      { id: 'lab', label: this.t('course.lab') },
    ], id => {
      if (id === 'lab') {
        if (!this.data.termStart) this.toast(this.t('course.labNeedBaseTimetable'));
        else this.go('lab');
      } else {
        this.academic(id);
      }
    });
  }

  private chosenPalette(): Palette {
    const palettes = (this.resources?.palettes ?? []).concat(this.data.customPalettes);
    return palettes.find(item => item.name === this.data.settings.palette) ??
      palettes[0] ?? { name: '默认', version: 1, colors: ['#678DE5'] };
  }

  private periods(): Period[] { return this.resources?.periods ?? []; }

  private weekdays(): string[] {
    if (this.t('nav.home') === '首页') return ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  }

  private homeCourses(tomorrow: boolean): Course[] {
    return coursesForCampusDay(this.data.courses, campusDay(this.data.termStart, this.currentTime, tomorrow));
  }

  private homeDateLabel(): string {
    const date = campusDay(this.data.termStart, this.currentTime);
    return this.t(date.vacation ? 'home.vacationContext' : 'home.weekContext')
      .replace('{week}', date.week.toString())
      .replace('{weekday}', this.weekdays()[date.weekday - 1])
      .replace('{m}', date.month.toString()).replace('{d}', date.day.toString());
  }

  private homeCourseFinished(course: Course): boolean {
    return homeCourseTiming(course, this.periods(), this.currentTime).finished;
  }

  private homeCourseColor(course: Course, detail: boolean): string {
    if (!this.tomorrow && this.homeCourseFinished(course)) {
      if (detail) return this.dark() ? '#737373' : '#828994';
      return this.dark() ? '#858585' : '#6E7580';
    }
    return detail ? this.muted() : this.ink();
  }

  private homeCountdown(course: Course, index: number): string {
    if (this.tomorrow || index !== this.homeCourses(false).findIndex(item => !this.homeCourseFinished(item))) return '';
    const timing = homeCourseTiming(course, this.periods(), this.currentTime);
    if (!timing.countdown) return '';
    return this.t(timing.countdown === 'start' ? 'home.countdownStartIn' : 'home.countdownEndIn')
      .replace('{n}', timing.minutes.toString());
  }

  private upcoming(): Exam[] {
    return this.data.exams.filter(item => {
      const end = Date.parse(item.endAt ?? '');
      return Number.isFinite(end) && end >= this.currentTime;
    }).sort((a, b) => Date.parse(a.startAt ?? '') - Date.parse(b.startAt ?? ''));
  }

  private openShortcut(shortcut: Shortcut): void {
    if (shortcut.route === '/grade') { this.go('grade'); return; }
    if (shortcut.route === '/exam') { this.go('exam'); return; }
    const url = shortcut.uri;
    if (!url) return;
    const title = this.t(shortcut.labelKey);
    if (shortcut.lan) {
      this.confirm(this.t('fn.lanTitle'), this.t('fn.lanDesc').replace('{app}', title),
        this.t('fn.lanConfirm'), () => this.openWeb(url, title, undefined, true));
    } else this.openWeb(url, title, undefined, true);
  }

  private profileGroups(): MenuGroup[] {
    const others: MenuRow[] = [new MenuRow('about', this.t('user.menuAbout'))];
    if (this.data.settings.developer) others.push(new MenuRow('developer', this.t('developer.title')));
    return [
      new MenuGroup(this.t('user.menuTools'), [new MenuRow('wlan', this.t('user.menuWlan'))]),
      new MenuGroup(this.t('user.menuSettings'), [
        new MenuRow('general', this.t('user.menuGeneral')),
        new MenuRow('appearance', this.t('user.menuAppearance')),
        new MenuRow('calendar', this.t('user.menuSchedule')),
      ]),
      new MenuGroup(this.t('user.menuOther'), others),
    ];
  }

  private title(page: string): string {
    const titles: Record<string, string> = {
      'general': 'settings.generalTitle', 'appearance': 'appearance.title', 'calendar': 'calendarSet.title',
      'visual': 'scheduleVisual.title', 'about': 'about.title', 'developer': 'developer.title', 'logs': 'developer.logsTitle',
      'wlan': 'wlan.title', 'grade': 'grade.title', 'exam': 'exam.title', 'manage': 'courseManage.title', 'palette': 'palette.title',
      'edit': 'courseAdd.titleEdit', 'privacy': 'about.privacyPolicy', 'agreement': 'about.userAgreement',
      'courseMenu': 'calendarSet.courseGroup', 'lab': 'course.labImportTitle'
    };
    if (page === 'choice') return this.choiceTitle;
    if (page === 'browser') return this.webTitle;
    if (page === 'qr') return '分享二维码';
    if (page === 'edit' && !this.selection) return this.t('courseAdd.titleAdd');
    return this.t(titles[page] ?? 'nav.home');
  }

  private async refreshIntegrations(change?: (settings: Settings) => void,
    confirmation?: (result: AcademicCalendarResult) => string): Promise<void> {
    const context = this.context;
    if (!context) return;
    if (this.doingIntegration) {
      if (!change) this.integrationPending = true;
      return;
    }
    const working = new Data(this.data);
    if (change) change(working.settings);
    const settings = working.settings;
    if (!change && !settings.syncCalendar && !settings.courseReminder && !settings.examReminder &&
      working.calendarEventIds.length === 0 && working.reminderIds.length === 0) return;
    this.doingIntegration = true;
    let applied = false;
    try {
      const result = await syncAcademicCalendar(context, working, this.periods(), change !== undefined);
      applied = true;
      this.calendarCheckedOnLaunch = !result.cleanupPending;
      if (result.cleanupPending) this.toast('部分旧日程或提醒暂未移除，应用会在下次同步时重试。');
      else if (confirmation) this.toast(confirmation(result));
    } catch (error) {
      this.calendarCheckedOnLaunch = false;
      const message = (error as Error).message || '系统日历更新失败。';
      this.record('系统日历更新失败 · ' + message);
      this.toast(message);
    } finally {
      this.persist(next => {
        next.calendarEventIds = working.calendarEventIds;
        next.reminderIds = working.reminderIds;
        if (applied && change) change(next.settings);
      });
      this.finishCalendarUpdate();
    }
  }

  private finishCalendarUpdate(): void {
    this.doingIntegration = false;
    if (this.integrationPending) {
      this.integrationPending = false;
      void this.refreshIntegrations();
    }
  }

  private afterScheduleChange(): void {
    if (this.context) updateScheduleCards(this.context, this.data);
    void this.refreshIntegrations();
  }

  private async showExamDndSettings(): Promise<void> {
    const context = this.context;
    if (!context) return;
    const now = Date.now();
    const exam = this.data.exams.filter(item => examStart(item) > now)
      .sort((left, right) => examStart(left) - examStart(right))[0];
    const status = canIUse('SystemCapability.Applications.IntelligentScene') ?
      await intelligentScene.isDoNotDisturbEnabled().catch(() => undefined) : undefined;
    if (this.page() !== 'general') return;
    let message = '';
    if (exam) {
      const start = examStart(exam);
      const end = examEnd(exam);
      const date = exam.date ?? '';
      message = '下一场考试 · ' + exam.courseName + '\n' + (date && exam.startTime ?
        date + ' ' + exam.startTime : new Date(start).toLocaleString());
      if (end > start) message += ' – ' + (exam.endTime || new Date(end).toLocaleTimeString());
      message += '\n\n';
    } else {
      message = '当前没有已安排的考试。\n\n';
    }
    if (status !== undefined) message += status ? '当前已开启免打扰。\n' : '当前免打扰已关闭。\n';
    message += '请在系统设置的「情景模式」中开启免打扰。也可以从控制中心开启。';
    this.confirm('考前免打扰', message, '打开系统设置', () => {
      context.startAbility({
        bundleName: 'com.huawei.hmos.settings',
        abilityName: 'com.huawei.hmos.settings.MainAbility'
      }).catch(() => this.toast('请从系统设置的「情景模式」或控制中心开启免打扰。'));
    });
  }

  private toggle(id: string, value: boolean): void {
    if (id === 'syncCalendar') {
      void this.refreshIntegrations(settings => { settings.syncCalendar = value; },
        result => !value ? '已关闭课表同步，已开启的提醒仍由系统日历发送。' : result.courseEvents > 0 ?
          this.t('calendarSet.syncedToast') : '已开启课表同步，当前没有可同步的课程。');
      return;
    }
    if (id === 'academicSync') {
      if (value && !this.data.academicCourseKind) {
        this.toast(this.t('calendarSet.autoRefreshNeedsImport'));
        this.setting(settings => { settings.autoRefreshCourses = false; });
        return;
      }
      this.setting(settings => { settings.autoRefreshCourses = value; });
      if (value) this.maybeSync();
      else this.stopQuietSync();
      return;
    }
    if (id === 'courseReminder') {
      void this.refreshIntegrations(settings => { settings.courseReminder = value; }, result =>
        !value ? '已关闭课前提醒。' : result.courseReminders > 0 ?
          '已在系统日历安排课前提醒。' : '已开启课前提醒，当前没有可安排提醒的课程。');
      return;
    }
    if (id === 'examReminder') {
      void this.refreshIntegrations(settings => { settings.examReminder = value; }, result =>
        !value ? '已关闭考试提醒。' : result.examReminders > 0 ?
          '已在系统日历安排考前一小时提醒。' : '已开启考试提醒，当前没有可安排提醒的考试。');
      return;
    }
    this.setting(settings => {
      switch (id) {
        case 'haptic': settings.haptic = value; break;
        case 'openCourseOnLaunch': settings.openCourseOnLaunch = value; break;
        case 'scrollWeekend': settings.scrollWeekend = value; break;
        case 'showMidday': settings.showMidday = value; break;
        case 'showOtherWeek': settings.showOtherWeek = value; break;
        case 'developer': settings.developer = value; break;
      }
    });
  }

  private slider(id: string, value: number): void {
    this.setting(settings => {
      switch (id) {
        case 'backgroundImageOpacity': settings.backgroundImageOpacity = value; break;
        case 'backgroundImageBlurRadius': settings.backgroundImageBlurRadius = value; break;
        case 'courseCellOpacity': settings.courseCellOpacity = value; break;
        case 'otherWeekCellOpacity': settings.otherWeekCellOpacity = value; break;
        case 'locatorCellOpacity': settings.locatorCellOpacity = value; break;
      }
    });
  }

  private menuAction(id: string): void {
    switch (id) {
      case 'manage':
      case 'calendar':
      case 'visual':
      case 'palette':
      case 'logs':
      case 'agreement':
      case 'privacy':
        this.go(id);
        break;
      case 'reimport': this.courseImport(); break;
      case 'theme':
        this.choices(this.t('appearance.theme'), ['system', 'light', 'dark'].map((value): Option => ({
          id: value, label: this.t(themeKey(value))
        })), value => this.setting(settings => { settings.theme = value; }));
        break;
      case 'language':
        this.choices(this.t('appearance.language'), ['system', 'zh', 'en'].map((value): Option => ({
          id: value, label: this.t(languageKey(value))
        })), value => this.setting(settings => { settings.language = value; }));
        break;
      case 'background':
        this.choices(this.t('appearance.bg'), [
          { id: 'pick', label: this.t('appearance.bgPickFromAlbum') },
          { id: 'remove', label: this.t('appearance.bgRemove') },
        ], value => {
          if (value === 'pick') void this.changeBackground();
          else this.setting(settings => { settings.backgroundUri = ''; });
        });
        break;
      case 'reminderMinutes':
        this.choices(this.t('settings.reminderTime'), ['5', '10', '15', '20', '30', '60', '90', '120']
          .map((value): Option => ({ id: value, label: this.t('settings.reminderTimeMins').replace('{n}', value) })),
          value => {
            void this.refreshIntegrations(settings => { settings.reminderMinutes = Number(value); }, result =>
              result.courseReminders > 0 ? '已更新课前提醒时间。' : '已保存提醒时间，当前没有可安排提醒的课程。');
          });
        break;
      case 'courseDnd':
        void this.showExamDndSettings();
        break;
      case 'resetVisual':
        this.setting(settings => {
          const defaults = new Settings();
          settings.backgroundImageOpacity = defaults.backgroundImageOpacity;
          settings.backgroundImageBlurRadius = defaults.backgroundImageBlurRadius;
          settings.courseCellOpacity = defaults.courseCellOpacity;
          settings.otherWeekCellOpacity = defaults.otherWeekCellOpacity;
          settings.locatorCellOpacity = defaults.locatorCellOpacity;
        });
        break;
      case 'export': void this.writeExport('iwut-courses.json', courseBackup(this.data)); break;
      case 'import': void this.importFile(); break;
      case 'exportLogs': void this.writeExport('iwut-harmony.log', this.logs.join('\n')); break;
      case 'version': void this.copy('0.3.31'); break;
      case 'commit': void this.copy('10335a5'); break;
      case 'website': this.openWeb('https://iwut.tokenteam.net/', this.t('about.website')); break;
      case 'github': this.openWeb('https://github.com/TokenTeam/iwut', 'GitHub'); break;
      case 'issues': this.openWeb('https://github.com/TokenTeam/iwut/issues', 'GitHub Issues'); break;
      case 'update': this.openWeb('https://github.com/TokenTeam/iwut/releases', this.t('about.checkUpdate')); break;
      case 'clearCache':
        this.confirm(this.t('settings.clearCacheTitle'), this.t('settings.clearCacheDesc'),
          this.t('settings.clearCacheConfirm'), () => {
            try {
              webview.WebStorage.deleteAllData();
              this.toast(this.t('settings.cacheCleared'));
            } catch (_) { this.toast(this.t('settings.clearCacheFailed')); }
          });
        break;
      case 'clearAll':
        this.confirm(this.t('developer.clearAllData'), this.t('developer.clearAllDataDesc'),
          this.t('developer.clearAllDataConfirm'), () => { void this.resetAll(); });
        break;
    }
  }

  private async resetAll(): Promise<void> {
    if (this.doingIntegration) return;
    this.doingIntegration = true;
    const working = new Data(this.data);
    working.settings = new Settings();
    try {
      if (this.context && (working.calendarEventIds.length > 0 || working.reminderIds.length > 0)) {
        const result = await syncAcademicCalendar(this.context, working, this.periods(), true);
        if (result.cleanupPending) throw new Error('部分系统日程或提醒未能移除。');
      }
      if (await readWlanAccount()) await removeWlanAccount();
      webview.WebCookieManager.clearAllCookiesSync();
      this.data = new Data();
      this.syncNativeTheme();
      this.syncSystemBars();
      this.pageStack.clear();
      this.mainTab = 0;
      this.accepted = false;
      this.setup = false;
      await this.storage?.save(this.data);
    } catch (_) {
      this.persist(next => {
        next.calendarEventIds = working.calendarEventIds;
        next.reminderIds = working.reminderIds;
      });
      this.toast(this.t('developer.clearAllDataFailed'));
    } finally {
      this.finishCalendarUpdate();
    }
  }

  private async changeBackground(): Promise<void> {
    if (!this.context) return;
    try {
      const path = await pickBackground(this.context);
      if (path) {
        this.setting(settings => { settings.backgroundUri = path; });
        this.toast(this.t('appearance.bgSetSuccess'));
      }
    } catch (_) { this.toast(this.t('appearance.bgSetFailed')); }
  }

  private async copy(value: string): Promise<void> {
    try {
      await copyText(value);
      this.toast(this.t('scan.contentCopied'));
    } catch (_) { this.toast(this.t('scan.copyFailed')); }
  }

  private async writeExport(name: string, content: string): Promise<void> {
    if (!this.context) return;
    try {
      if (await saveFile(this.context, name, content)) this.toast('文件已保存');
    } catch (_) { this.toast(this.t('settings.exportFailed')); }
  }

  private async importFile(): Promise<void> {
    if (!this.context) return;
    try {
      const backup = await readCourseBackup(this.context);
      if (backup === null) return;
      this.confirm(this.t('calendarSet.importCourses'),
        this.t('calendarSet.importCoursesDesc').replace('{n}', backup.courses.length.toString()),
        this.t('calendarSet.importCoursesConfirm'), () => {
          this.persist(next => {
            next.courses = backup.courses;
            next.termStart = backup.termStart;
            next.academicCourseKind = '';
            next.coursesSyncedAt = '';
            next.coursesSyncedTime = 0;
            next.settings.autoRefreshCourses = false;
          });
          this.week = currentWeek(this.data.termStart, new Date());
          this.afterScheduleChange();
          this.toast(this.t('calendarSet.coursesImported'));
        });
    } catch (_) { this.toast(this.t('calendarSet.invalidCourseData')); }
  }

  private async scanCode(): Promise<void> {
    if (!this.context || this.scanning) return;
    this.scanning = true;
    try {
      const raw = await scan(this.context);
      this.handleSharedData(raw);
    } catch (error) {
      if ((error as BusinessError).code !== 1000500002) this.toast(this.t('scan.executeFailed'));
    } finally {
      this.scanning = false;
    }
  }

  private incomingShare(): void {
    if (!this.sharedLink || !this.loaded || !this.data.onboarding) return;
    const raw = this.sharedLink;
    this.sharedLink = '';
    this.handleSharedData(raw);
  }

  private incomingShortcut(): void {
    if (this.shortcut !== 'wlan' || !this.loaded || !this.data.onboarding) return;
    this.shortcut = '';
    this.mainTab = 3;
    this.pageStack.clear();
    this.go('wlan');
  }

  private handleSharedData(raw: string): void {
    const result = scanResult(raw);
    const palette = envelopePalette(result);
    const courses = envelopeCourses(result);
    if (palette) {
      this.confirm(this.t('share.receiveTitle'), palette.name, this.t('scan.importPalette'), () => this.savePalette(palette));
    } else if (courses.length > 0) {
      const name = courses[0].name;
      const replace = this.data.courses.some(item => item.name === name);
      const description = this.t(replace ? 'scan.courseOverwriteDesc' : 'scan.coursePreviewDesc').replace('{name}', name);
      this.confirm(this.t('scan.coursePreviewTitle'), description,
        this.t(replace ? 'scan.importCourseOverwrite' : 'scan.importCourse'), () => {
          this.persist(next => {
            const retained = replace ? next.courses.filter(item => item.name !== name) : next.courses;
            next.courses = validCourses(retained.concat(courses));
          });
          this.afterScheduleChange();
          this.toast(this.t('scan.courseImported').replace('{name}', name));
        });
    } else if (raw) {
      this.confirm(this.t('scan.resultTitle'), raw.slice(0, 320), this.t('scan.copyContent'), () => { void this.copy(raw); });
    }
  }

  private savePalette(palette: Palette): void {
    this.persist(next => {
      next.customPalettes = next.customPalettes.filter(item => item.name !== palette.name).concat(palette);
      next.settings.palette = palette.name;
    });
  }

  private async pastePalette(): Promise<void> {
    try {
      const text = await pasteText();
      const wrapped = envelopePalette(scanResult(text));
      const palette = wrapped ?? JSON.parse(text) as Palette;
      if (!validPalette(palette)) throw new Error('Invalid palette');
      this.savePalette(palette);
    } catch (_) { this.toast(this.t('palette.formatError')); }
  }

  private showQr(data: string): void {
    if (data.length > 1500) {
      this.toast('内容过长，已改为复制到剪贴板。');
      void this.copy(data);
      return;
    }
    this.qrText = data;
    this.go('qr');
  }

  private showCourseDetails(course: Course): void {
    if (this.data.settings.haptic) clickFeedback();
    this.selection = course;
    this.courseModal = 'detail';
  }

  private openQuickAdd(slot: CourseSlotRange): void {
    this.quickSlot = alignQuickSlot(slot);
    this.courseModal = 'quick';
  }

  private openCourseEditor(course: Course | null, prefill: QuickCourseDraft | null = null): void {
    this.courseModal = '';
    this.selection = course;
    this.editPrefill = prefill;
    this.go('edit');
  }

  private addQuickCourse(draft: QuickCourseDraft): void {
    if (!draft.name.trim() || !draft.weeks.length) return;
    const commit = (): void => {
      this.persist(next => { next.courses = validCourses(next.courses.concat(quickCourseRecords(draft))); });
      this.courseModal = '';
      this.afterScheduleChange();
      this.toast(this.t('schedule.quickAdd.added'));
    };
    const conflicts = overlappingWeeks(this.data.courses, draft.slot, draft.weeks);
    if (conflicts.length) {
      this.confirm(this.t('schedule.quickAdd.conflictTitle'),
        this.t('schedule.quickAdd.conflictDesc').replace('{weeks}', weekList(conflicts)),
        this.t('schedule.quickAdd.conflictConfirm'), commit);
    } else {
      commit();
    }
  }

  private startCourseShare(records: Course[]): void {
    const value = courseShareText(records);
    if (!value) return;
    this.courseModal = '';
    this.sharePayload = value;
    this.courseShareVisible = true;
  }

  private quickSlotTime(): string {
    const start = this.periods().find(period => period.number === this.quickSlot.sectionStart)?.start;
    const end = this.periods().find(period => period.number === this.quickSlot.sectionEnd)?.end;
    return start && end ? start + ' – ' + end : '';
  }

  private selectedCourses(): Course[] {
    const name = this.selection?.name;
    return name ? this.data.courses.filter(course => course.name === name) : [];
  }

  private saveCourses(records: Course[]): void {
    const previous = this.selection?.name;
    this.persist(next => {
      next.courses = validCourses(next.courses.filter(course => course.name !== previous).concat(records));
    });
    this.afterScheduleChange();
    this.toast(this.t(previous ? 'courseAdd.courseUpdated' : 'courseAdd.courseAdded'));
    this.back();
  }

  private deleteCourse(course: Course): void {
    this.confirm(this.t('courseManage.deleteCourseTitle'),
      this.t('courseManage.deleteCourseDesc').replace('{name}', course.name), this.t('common.delete'), () => {
        this.persist(next => { next.courses = next.courses.filter(item => item.name !== course.name); });
        this.afterScheduleChange();
        this.toast(this.t('courseManage.deleted').replace('{name}', course.name));
        this.back();
      }, true);
  }

  private distinctCourses(): Course[] {
    const seen = new Set<string>();
    return this.data.courses.filter(course => {
      if (seen.has(course.name)) return false;
      seen.add(course.name);
      return true;
    }).sort((a, b) => a.name.localeCompare(b.name));
  }

  private startDate(): void {
    const date = localDate(this.data.termStart);
    this.getUIContext().showDatePickerDialog({
      selected: Number.isFinite(date.getTime()) ? date : new Date(),
      onAccept: value => {
        if (value.year === undefined || value.month === undefined || value.day === undefined) return;
        const start = new Date(value.year, value.month, value.day);
        const month = (start.getMonth() + 1).toString().padStart(2, '0');
        const day = start.getDate().toString().padStart(2, '0');
        this.persist(next => { next.termStart = start.getFullYear() + '-' + month + '-' + day; });
        this.week = currentWeek(this.data.termStart, new Date());
        this.afterScheduleChange();
      },
    });
  }

  @Builder
  private titleText(title: string) {
    Text(title).layoutWeight(1).height(PAGE_TITLE_HEIGHT).fontSize(32).fontWeight(FontWeight.Bold)
      .fontColor(this.ink()).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  private largeTitle(title: string, caption: string = '', showScanMenu: boolean = false) {
    Column({ space: 5 }) {
      if (showScanMenu) {
        Navigation()
          .mode(NavigationMode.Stack).hideBackButton(true).hideToolBar(true)
          .title({ builder: this.homeTitleRow, height: PAGE_TITLE_HEIGHT }, { backgroundColor: Color.Transparent })
          .width('100%').height(PAGE_TITLE_HEIGHT)
      } else {
        Row() {
          this.titleText(title)
        }.width('100%')
      }
      if (caption) Text(caption).fontSize(14).fontColor(this.muted())
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private homeTitleRow() {
    Row({ space: 12 }) {
      this.titleText(this.homeGreeting())
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.plus_circle')).fontSize(28).fontColor([this.ink()])
      }.width(44).height(PAGE_TITLE_HEIGHT).padding(0).backgroundColor(Color.Transparent)
        .attributeModifier(this.titleButtonStyle)
        .accessibilityText(this.t('common.add'))
        .bindMenu([{
          value: this.t('scan.title'),
          symbolIcon: new SymbolGlyphModifier($r('sys.symbol.qrcode')),
          action: () => { void this.scanCode(); }
        }], { placement: Placement.BottomRight })
    }.width('100%').height(PAGE_TITLE_HEIGHT).alignItems(VerticalAlign.Center)
  }

  @Builder
  private empty(title: string, subtitle: string) {
    Column({ space: 8 }) {
      Text(title).fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.ink())
      Text(subtitle).fontSize(13).fontColor(this.muted()).textAlign(TextAlign.Center)
    }.width('100%').padding(25).backgroundColor(this.surface()).borderRadius(16)
  }

  @Builder
  private courseCard(course: Course) {
    Row({ space: 12 }) {
      Column({ space: 6 }) {
        Text(course.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.ink()).maxLines(2)
        Text(courseTime(course, this.periods()) + (course.room ? '  ·  ' + course.room : ''))
          .fontSize(13).fontColor(this.muted())
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('›').fontColor(this.muted()).fontSize(23)
    }.padding(15).width('100%').backgroundColor(this.surface()).borderRadius(14)
      .onClick(() => this.showCourseDetails(course))
  }

  private homeGreeting(subtitle: boolean = false): string {
    const key = homeGreetingKey(new Date(this.currentTime).getHours());
    return this.t(subtitle ? key + 'Sub' : key);
  }

  private homeFinishedCount(): number {
    return this.homeCourses(false).filter(course => this.homeCourseFinished(course)).length;
  }

  @Builder
  private homeHeader() {
    Column({ space: 13 }) {
      this.largeTitle(this.homeGreeting(), this.homeGreeting(true), true)
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.calendar')).fontSize(14).fontColor([this.muted()])
        Text(this.homeDateLabel()).layoutWeight(1).fontSize(13).fontColor(this.muted())
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 12 })
  }

  @Builder
  private homeDayTab(label: string, tomorrow: boolean) {
    Button({ type: ButtonType.Capsule }) {
      Row({ space: 7 }) {
        Text(this.t(label)).fontSize(15).fontWeight(FontWeight.Bold)
          .fontColor(this.tomorrow === tomorrow ? '#FFFFFF' : this.ink())
        if (this.homeCourses(tomorrow).length > 0) {
          Text(this.homeCourses(tomorrow).length.toString()).fontSize(12).fontWeight(FontWeight.Bold)
            .fontColor(this.tomorrow === tomorrow ? '#FFFFFF' : this.muted())
            .textAlign(TextAlign.Center).constraintSize({ minWidth: 21 }).height(21)
            .padding({ left: 5, right: 5 }).borderRadius(11)
            .backgroundColor(this.tomorrow === tomorrow ? '#30FFFFFF' : this.bg())
        }
      }.padding({ left: 13, right: 13 })
    }.height(38).padding(0)
      .backgroundColor(this.tomorrow === tomorrow ? '#2559BD' : this.surface())
      .accessibilityGroup(true)
      .onClick(() => { this.tomorrow = tomorrow; })
  }

  @Builder
  private homeCourseCard(course: Course, index: number) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(course.name).layoutWeight(1).fontSize(16).fontWeight(FontWeight.Bold)
          .fontColor(this.homeCourseColor(course, false)).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.homeCountdown(course, index)) {
          Text(this.homeCountdown(course, index)).fontSize(11).fontWeight(FontWeight.Medium).fontColor(this.blue())
            .padding({ left: 6, right: 6, top: 2, bottom: 2 }).backgroundColor(this.bg()).borderRadius(6)
        }
      }.width('100%')
      Row({ space: 5 }) {
        SymbolGlyph($r('sys.symbol.clock')).fontSize(12).fontColor([this.homeCourseColor(course, true)])
        Text(courseTime(course, this.periods()).replace(' – ', '–'))
          .fontSize(12).fontColor(this.homeCourseColor(course, true))
        if (course.room) {
          SymbolGlyph($r('sys.symbol.position')).fontSize(12).fontColor([this.homeCourseColor(course, true)])
            .margin({ left: 9 })
          Text(course.room).layoutWeight(1).fontSize(12).fontColor(this.homeCourseColor(course, true))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }.width('100%')
    }.alignItems(HorizontalAlign.Start).width('100%')
      .padding({ left: 15, right: 12, top: 12, bottom: 12 }).backgroundColor(this.surface())
      .border({ width: { left: 4 }, color: !this.tomorrow && this.homeCourseFinished(course) ?
        this.line() : courseColor(course, this.chosenPalette()) })
      .borderRadius(14).clip(true)
      .onClick(() => this.showCourseDetails(course))
  }

  @Builder
  private homeSchedule() {
    Row({ space: 8 }) {
      this.homeDayTab('home.tabToday', false)
      this.homeDayTab('home.tabTomorrow', true)
      Blank()
      if (!this.tomorrow && this.homeFinishedCount() > 0) {
        Text(this.homeFinishedCount() + '/' + this.homeCourses(false).length)
          .fontSize(12).fontColor(this.muted())
      }
    }.width('100%')
    if (this.homeCourses(this.tomorrow).length === 0) {
      this.empty(this.t(this.data.courses.length > 0 ?
        (this.tomorrow ? 'home.emptyTomorrowNone' : 'home.emptyTodayNone') : 'home.emptyNoCourses'),
        this.t(this.data.courses.length > 0 ?
          (this.tomorrow ? 'home.emptyTomorrowNoneSub' : 'home.emptyTodayNoneSub') : 'home.emptyNoCoursesSub'))
    }
    ForEach(this.homeCourses(this.tomorrow), (course: Course, index: number) => {
      this.homeCourseCard(course, index)
    }, (course: Course, index: number) => JSON.stringify(course) + index)
  }

  @Builder
  private home() {
    Column({ space: 14 }) {
      this.homeHeader()
      this.homeSchedule()
      if (this.upcoming().length > 0) {
        Text(this.t('home.nextExam')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.ink()).width('100%')
        this.homeExamCard(this.upcoming()[0])
      }
    }.width('100%')
  }

  @Builder
  private courseHeader() {
    Navigation()
      .mode(NavigationMode.Stack).hideBackButton(true).hideToolBar(true)
      .title({ builder: this.courseTitleRow, height: PAGE_TITLE_HEIGHT }, { backgroundColor: Color.Transparent })
      .width('100%').height(PAGE_TITLE_HEIGHT)
  }

  @Builder
  private courseTitleRow() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.line_3_horizontal')).fontSize(24).fontColor([this.ink()])
      }.width(44).height(PAGE_TITLE_HEIGHT).padding(0).backgroundColor(Color.Transparent)
        .attributeModifier(this.titleButtonStyle)
        .accessibilityText(this.t('calendarSet.courseGroup'))
        .onClick(() => { this.go('courseMenu'); })
      Row({ space: 4 }) {
        this.weekArrow(-1, $r('sys.symbol.chevron_left'))
        Text(this.t('common.weekN').replace('{n}', this.week.toString())).fontSize(19)
          .fontWeight(FontWeight.Bold).fontColor(this.ink()).textAlign(TextAlign.Center)
          .constraintSize({ minWidth: 80 }).height(44)
          .onClick(() => {
            const options: Option[] = [];
            for (let week = 1; week <= 20; week++) {
              options.push({ id: week.toString(), label: this.t('common.weekN').replace('{n}', week.toString()) });
            }
            this.choices(this.t('nav.course'), options, id => { this.week = Number(id); });
          })
        this.weekArrow(1, $r('sys.symbol.chevron_right'))
      }.layoutWeight(1).justifyContent(FlexAlign.Center)
      Row().width(44).height(PAGE_TITLE_HEIGHT)
    }.width('100%').padding({ left: 13, right: 13 })
  }

  @Builder
  private weekArrow(step: number, icon: Resource) {
    Button({ type: ButtonType.Normal }) {
      SymbolGlyph(icon).fontSize(20).fontColor([this.muted()])
    }.width(40).height(44).padding(0).backgroundColor(Color.Transparent)
      .enabled(this.week + step >= 1 && this.week + step <= 20)
      .opacity(this.week + step >= 1 && this.week + step <= 20 ? 1 : 0)
      .accessibilityText(this.t('common.weekN').replace('{n}', (this.week + step).toString()))
      .onClick(() => { this.week += step; })
  }

  @Builder
  private course() {
    Column({ space: 12 }) {
      this.courseHeader()
      if (this.data.courses.length === 0) {
        this.empty(this.t('home.emptyNoCourses'), this.t('home.emptyNoCoursesSub'))
        Button(this.t('course.selectImportType')).width('100%').onClick(() => { this.courseImport(); })
      } else {
        Stack() {
          if (this.data.settings.backgroundUri) {
            Image('file://' + this.data.settings.backgroundUri).width('100%').height('100%')
              .objectFit(ImageFit.Cover).opacity(this.data.settings.backgroundImageOpacity / 100)
              .blur(this.data.settings.backgroundImageBlurRadius)
          }
          Timetable({
            courses: this.data.courses, week: this.week, termStart: this.data.termStart, now: this.currentTime,
            showMidday: this.data.settings.showMidday, showOtherWeek: this.data.settings.showOtherWeek,
            weekendScroll: this.data.settings.scrollWeekend, darkMode: this.dark(),
            surface: this.data.settings.backgroundUri ? '#00000000' : this.surface(),
            courseOpacity: this.data.settings.courseCellOpacity, otherOpacity: this.data.settings.otherWeekCellOpacity,
            locatorOpacity: this.data.settings.locatorCellOpacity, weekdays: this.weekdays(),
            monthSuffix: this.t('common.monthSuffix'),
            dayParts: [this.t('schedule.sidebar.morning'), this.t('schedule.sidebar.afternoon'), this.t('schedule.sidebar.night')],
            otherWeekTag: this.t('schedule.otherWeekTag'), periods: this.periods(), palette: this.chosenPalette(),
            onSelect: (course: Course) => this.showCourseDetails(course),
            onAdd: (slot: CourseSlotRange) => this.openQuickAdd(slot)
          })
        }.clip(true).borderRadius(14)
      }
    }.width('100%')
  }

  @Builder
  private shortcuts() {
    Column({ space: 21 }) {
      this.largeTitle(this.t('fn.title'), this.t('fn.subtitle'))
      if (!this.data.profile) {
        this.empty(this.t('user.bindTitle'), this.t('user.bindSubtitle'))
        Button(this.t('course.goBind')).width('100%').onClick(() => { this.mainTab = 3; })
      } else {
        ForEach(this.resources?.shortcuts ?? [], (group: ShortcutGroup) => {
        if (group.items.some(shortcut => shortcutVisible(shortcut, this.data.profile))) {
          Column({ space: 9 }) {
            Text(this.t(group.titleKey)).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.ink()).width('100%')
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(group.items.filter(shortcut => shortcutVisible(shortcut, this.data.profile)), (shortcut: Shortcut) => {
                Column({ space: 7 }) {
                  Stack() {
                    if (this.shortcutIcons[shortcut.icon]) {
                      Image(this.shortcutIcons[shortcut.icon]).width(20).height(20)
                        .objectFit(ImageFit.Contain).fillColor(shortcut.color).draggable(false)
                    } else {
                      SymbolGlyph($r('sys.symbol.square_grid_2x2')).fontSize(20).fontColor([shortcut.color])
                    }
                  }.width(44).height(44).borderRadius(14)
                    .backgroundColor((this.dark() ? '#18' : '#12') + shortcut.color.slice(1))
                  Text(this.t(shortcut.labelKey)).fontSize(12).fontColor(this.ink()).textAlign(TextAlign.Center)
                }.width('25%').height(87).padding({ top: 8 }).justifyContent(FlexAlign.Center)
                  .onClick(() => { this.openShortcut(shortcut); })
              }, (shortcut: Shortcut) => shortcut.labelKey)
            }.width('100%').backgroundColor(this.surface()).borderRadius(15)
          }.width('100%')
        }
        }, (group: ShortcutGroup) => group.titleKey)
      }
    }.width('100%')
  }

  @Builder
  private user() {
    Column({ space: 19 }) {
      this.largeTitle(this.t('nav.user'))
      Row({ space: 13 }) {
        Image($r('app.media.start_icon')).width(46).height(46).borderRadius(12)
        Column({ space: 7 }) {
          Text(this.data.profile?.name || this.t('user.bindTitle')).fontSize(19)
            .fontWeight(FontWeight.Medium).fontColor(this.ink())
          Text(this.data.profile ? this.data.profile.studentId + ' ' + this.data.profile.college : this.t('user.bindSubtitle'))
            .fontSize(12).fontColor(this.muted())
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text('›').fontSize(23).fontColor(this.muted())
      }.width('100%').padding(16).backgroundColor(this.surface()).borderRadius(16)
        .onClick(() => {
          if (!this.data.profile) this.academic('bind');
          else this.confirm(this.t('user.unbindTitle'), this.t('user.unbindDesc'), this.t('user.unbind'), () => {
            this.persist(next => { next.profile = null; });
            webview.WebCookieManager.clearAllCookiesSync();
          });
        })
      MenuGroups({
        groups: this.profileGroups(), textColor: this.ink(), muted: this.muted(), card: this.surface(), divider: this.line(),
        onAction: (id: string) => this.go(id)
      })
    }.width('100%')
  }

  @Builder
  private onboarding() {
    Column({ space: 20 }) {
      Image($r('app.media.start_icon')).width(82).height(82).borderRadius(21)
      Text(this.t(this.setup ? 'onboarding.setupTitle' : 'onboarding.appName')).fontSize(35)
        .fontWeight(FontWeight.Bold).fontColor(this.ink())
      if (this.setup) {
        Text(this.t('onboarding.setupSubtitle')).fontSize(14).fontColor(this.muted()).textAlign(TextAlign.Center)
        MenuGroups({
          groups: [
            new MenuGroup(this.t('onboarding.scheduleSection'), [
              new MenuRow('importNow', this.t(this.data.courses.length ? 'onboarding.importDoneTitle' : 'onboarding.importNow')),
              new MenuRow('importLater', this.t('onboarding.importLater'))
            ]),
            new MenuGroup(this.t('onboarding.optionsSection'), [
              new MenuRow('courseReminder', this.t('settings.courseReminder'), '', this.data.settings.courseReminder),
              new MenuRow('syncCalendar', this.t('calendarSet.syncCalendar'), '', this.data.settings.syncCalendar)
            ])
          ],
          textColor: this.ink(), muted: this.muted(), card: this.surface(), divider: this.line(),
          onAction: (id: string) => { if (id === 'importNow') this.courseImport(); else this.toast(this.t('onboarding.selected')); },
          onToggle: (id: string, value: boolean) => this.toggle(id, value)
        })
        Button(this.t('onboarding.startUsing')).width('100%').onClick(() => {
          this.persist(next => { next.onboarding = true; });
          this.incomingShare();
          this.incomingShortcut();
        })
      } else {
        Button(this.t('onboarding.login')).width('100%').onClick(() => {
          if (this.accepted) this.academic('bind');
          else this.toast(this.t('onboarding.legalRequired'));
        })
        Row() {
          Checkbox().select(this.accepted).onChange(value => { this.accepted = value; })
          Column({ space: 5 }) {
            Text(this.t('onboarding.legalAcceptPrefix')).fontSize(12).fontColor(this.muted())
            Row({ space: 8 }) {
              Text(this.t('about.userAgreement')).fontSize(13).fontColor(this.blue()).onClick(() => this.go('agreement'))
              Text(this.t('onboarding.legalAcceptAnd')).fontSize(12).fontColor(this.muted())
              Text(this.t('about.privacyPolicy')).fontSize(13).fontColor(this.blue()).onClick(() => this.go('privacy'))
            }
          }.alignItems(HorizontalAlign.Start)
        }
        Button(this.t('onboarding.skipLogin'), { type: ButtonType.Normal }).onClick(() => {
          if (this.accepted) this.setup = true;
          else this.toast(this.t('onboarding.legalRequired'));
        })
        Row({ space: 18 }) {
          Text(this.t('about.website')).fontSize(13).fontColor(this.blue())
            .onClick(() => this.openWeb('https://iwut.tokenteam.net/', this.t('about.website')))
          Text('GitHub').fontSize(13).fontColor(this.blue())
            .onClick(() => this.openWeb('https://github.com/TokenTeam/iwut', 'GitHub'))
        }
      }
    }.width('100%').constraintSize({ maxWidth: 520 })
      .padding({ left: 26, right: 26, top: PAGE_TOP_INSET, bottom: 26 })
  }

  private tabStyle(key: string, index: number): BottomTabBarStyle {
    return BottomTabBarStyle.of({
      normal: new SymbolGlyphModifier(this.tabIcons[index]).fontColor([this.muted()]),
      selected: new SymbolGlyphModifier(this.tabIcons[index]).fontColor([this.blue()])
    }, this.t(key))
      .layoutMode(LayoutMode.VERTICAL)
      .labelStyle({ selectedColor: this.blue(), unselectedColor: this.muted(), maxLines: 1 });
  }

  private tabFeedback(): void {
    if (this.data.settings.haptic) clickFeedback();
  }

  private tabActivated(index: number): void {
    this.tabFeedback();
    this.tabTapped = index;
  }

  private tabChanged(index: number): void {
    const tapped = this.tabTapped;
    this.tabTapped = -1;
    this.mainTab = index;
    if (tapped !== index) return;
    this.tabFade = 0.82;
    this.getUIContext().animateTo({ duration: TAB_FADE, curve: Curve.Friction }, () => {
      this.tabFade = 1;
    });
  }

  @Builder
  private tabPages() {
    ForEach(this.tabs, (key: string, index: number) => {
      TabContent() {
        Scroll() {
          Column() {
            if (index === 0) this.home()
            else if (index === 1) this.course()
            else if (index === 2) this.shortcuts()
            else this.user()
          }
          .width('100%').constraintSize({ maxWidth: 1000 })
          .padding({
            left: index === 1 ? 4 : 17, right: index === 1 ? 4 : 17, top: PAGE_TOP_INSET,
            bottom: this.floatingTabs ? 22 + TAB_BAR_HEIGHT : 22
          })
        }.scrollBar(BarState.Off).width('100%').height('100%').align(Alignment.Top)
        .opacity(this.tabFade)
      }.tabBar(this.tabStyle(key, index))
    }, (key: string) => key)
  }

  @Builder
  private mainTabs() {
    if (this.floatingTabs) {
      HdsTabs({ barPosition: BarPosition.End, index: this.mainTab }) {
        this.tabPages()
      }
      .width('100%').height('100%')
      .vertical(false).scrollable(true).animationDuration(TAB_ANIMATION).barHeight(TAB_BAR_HEIGHT).barOverlap(true)
      .barFloatingStyle({
        gradientMask: { maskColor: this.bg() },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      })
      .onTabBarClick((index: number) => this.tabActivated(index))
      .onChange(index => this.tabChanged(index))
    } else {
      Tabs({ barPosition: BarPosition.End, index: this.mainTab }) {
        this.tabPages()
      }
      .width('100%').height('100%')
      .vertical(false).scrollable(true).animationDuration(TAB_ANIMATION).barHeight(TAB_BAR_HEIGHT)
      .barBackgroundColor(this.surface())
      .onTabBarClick((index: number) => this.tabActivated(index))
      .onChange(index => this.tabChanged(index))
    }
  }

  @Builder
  private subpageHeader(name: string) {
    Column() {
      Row({ space: 14 }) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.arrow_left')).fontSize(22).fontColor([this.ink()])
        }.width(44).height(PAGE_TITLE_HEIGHT).padding(0).backgroundColor(Color.Transparent)
          .attributeModifier(this.titleButtonStyle).accessibilityText('返回')
          .onClick(() => { if (!this.onBackPress()) this.back(); })
        Text(this.title(name)).fontSize(name === 'exam' ? 21 : 19)
          .fontWeight(FontWeight.Bold).fontColor(this.ink()).layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.width('100%').height(SUBPAGE_TITLE_HEIGHT).padding({ left: 14, right: 16 })
        .alignItems(VerticalAlign.Center).clip(false)
    }
    .width('100%').padding({ top: PAGE_TOP_INSET }).backgroundColor(this.surface())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  private routeContent(name: string) {
    Column() {
      this.subpageHeader(name)
      if (name === 'browser') {
        CampusWeb({
          url: this.webUrl, prefix: this.webPrefix, script: this.webScript, controller: this.browser,
          documentScripts: this.webDocumentScripts, binding: this.activeAcademic === 'bind',
          onResult: (value: AcademicResult) => this.academicResult(value)
        })
      } else {
        Scroll() {
          Column({ space: 17 }) {
            this.subpage(name)
          }.width('100%').constraintSize({ maxWidth: 850 }).padding(17)
        }.width('100%').layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(this.bg())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  @Builder
  private routeMap(name: string) {
    NavDestination() {
      this.routeContent(name)
    }
    .hideTitleBar(true)
    .backgroundColor(this.bg())
    .onBackPressed(() => this.onBackPress())
  }

  @Builder
  private menu(groups: MenuGroup[]) {
    ForEach([this.menuRevision], (revision: number) => {
      MenuGroups({
        groups: groups, textColor: this.ink(), muted: this.muted(), card: this.surface(), divider: this.line(),
        onAction: (id: string) => this.menuAction(id),
        onToggle: (id: string, value: boolean) => this.toggle(id, value),
        onSlide: (id: string, value: number) => this.slider(id, value)
      })
    }, (revision: number) => 'menu:' + revision)
  }

  @Builder
  private gradePage() {
    Button(this.t(this.data.grades.length ? 'grade.requery' : 'grade.queryNow')).width('100%')
      .onClick(() => { this.academic('grade'); })
    if (this.data.gradesSyncedAt) {
      Text(this.t('grade.lastRefreshed').replace('{time}', this.data.gradesSyncedAt))
        .fontSize(12).fontColor(this.muted()).width('100%')
    }
    if (this.data.grades.length === 0) {
      this.empty(this.t('grade.emptyTitle'), this.t('grade.emptySub'))
    } else {
      Button(this.t('grade.termFilter') + ' · ' + (this.gradeTerm || this.t('grade.rangeAll')),
        { type: ButtonType.Normal }).onClick(() => {
        const terms = Array.from(new Set(this.data.grades.map(item => item.term).filter(item => item.length > 0)));
        const options: Option[] = [{ id: '', label: this.t('grade.rangeAll') }];
        terms.sort((a, b) => b.localeCompare(a)).forEach(item => { options.push({ id: item, label: item }); });
        this.choices(this.t('grade.selectTerm'), options, value => { this.gradeTerm = value; });
      })
      ForEach(this.data.grades.filter(item => !this.gradeTerm || item.term === this.gradeTerm), (item: Grade) => {
        Row({ space: 12 }) {
          Column({ space: 6 }) {
            Text(item.courseName || this.t('grade.unknownCourse')).fontSize(16).fontColor(this.ink())
            Text([item.term, item.courseNature, this.t('grade.creditValue').replace('{n}', item.credits)]
              .filter(value => value.length > 0).join(' · ')).fontSize(12).fontColor(this.muted())
            if (item.retakeLabel) Text(item.retakeLabel).fontSize(12).fontColor(this.muted())
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text(item.totalScore).fontSize(21).fontWeight(FontWeight.Bold).fontColor(this.blue())
        }.width('100%').padding(15).borderRadius(14).backgroundColor(this.surface())
      }, (item: Grade, index: number) => item.id + ':' + index)
    }
    Text(this.t('grade.disclaimer')).fontSize(12).fontColor(this.muted())
  }

  @Builder
  private homeExamCard(item: Exam) {
    Column({ space: 7 }) {
      Text(item.courseName || this.t('exam.unknownCourse')).fontSize(16)
        .fontWeight(FontWeight.Medium).fontColor(this.ink())
      if (item.date) Text(item.date + '  ' + (item.startTime ?? '') + ' – ' + (item.endTime ?? ''))
        .fontSize(13).fontColor(this.muted())
      Text(item.place || item.teacher || this.t('exam.noPlace')).fontSize(13).fontColor(this.muted())
      if (item.seatNo) Text(this.t('exam.seatNo') + ' ' + item.seatNo).fontSize(13).fontColor(this.blue())
    }.width('100%').alignItems(HorizontalAlign.Start).padding(15).backgroundColor(this.surface()).borderRadius(14)
      .onClick(() => { this.go('exam'); })
  }

  @Builder
  private examPage() {
    ExamSchedule({
      exams: this.data.exams, notArranged: this.data.notArranged, term: this.data.examTerm,
      refreshedAt: this.data.examsSyncedAt, now: this.currentTime, tab: this.examTab,
      reminderEnabled: this.data.settings.examReminder, darkMode: this.dark(), immersive: this.titleMaterialSupported,
      ink: this.ink(), muted: this.muted(), blue: this.blue(), card: this.surface(),
      pageBackground: this.bg(), divider: this.line(), weekdays: this.weekdays(), buttonStyle: this.titleButtonStyle,
      t: (key: string) => this.t(key), onTab: (tab: number) => { this.examTab = tab; },
      onReminder: () => { this.go('general'); }, onRefresh: () => { this.academic('exam'); }
    })
  }

  @Builder
  private manageCourses() {
    Row({ space: 8 }) {
      Button(this.t('courseManage.addCourse')).layoutWeight(1)
        .onClick(() => this.openCourseEditor(null))
      Button(this.data.termStart || '学期开始日期', { type: ButtonType.Normal }).layoutWeight(1)
        .onClick(() => this.startDate())
    }.width('100%')
    if (this.data.courses.length === 0) {
      this.empty(this.t('calendarSet.noCourses'), this.t('courseManage.noCoursesHint'))
    }
    ForEach(this.distinctCourses(), (course: Course) => { this.courseCard(course) },
      (course: Course) => course.name + ':' + course.sectionStart + ':' + course.room)
    if (this.data.courses.length > 0) {
      Button(this.t('courseManage.clearAll'), { type: ButtonType.Normal }).fontColor('#B72E3B').width('100%')
        .onClick(() => {
          this.confirm(this.t('courseManage.clearAllTitle'), this.t('courseManage.clearAllDesc'),
            this.t('courseManage.clearAllConfirm'), () => {
              this.persist(next => { next.courses = []; next.academicCourseKind = ''; next.coursesSyncedAt = ''; });
              this.afterScheduleChange();
            });
        })
    }
  }

  @Builder
  private palettePage() {
    ForEach((this.resources?.palettes ?? []).concat(this.data.customPalettes), (palette: Palette, index: number) => {
      Row({ space: 10 }) {
        Column({ space: 7 }) {
          Text(palette.name).fontSize(15).fontColor(this.ink()).width('100%')
          Row({ space: 4 }) {
            ForEach(palette.colors.slice(0, 12), (color: string) => {
              Blank().width(17).height(12).backgroundColor(color).borderRadius(4)
            }, (color: string, i: number) => color + i)
          }.width('100%')
        }.layoutWeight(1)
        if (this.data.settings.palette === palette.name) Text('✓').fontColor(this.blue()).fontSize(19)
      }.padding(13).width('100%').backgroundColor(this.surface()).borderRadius(13)
        .onClick(() => this.setting(settings => { settings.palette = palette.name; }))
    }, (palette: Palette, index: number) =>
      palette.name + index + ':' + (this.data.settings.palette === palette.name))
    MenuGroups({
      groups: [new MenuGroup(this.t('palette.actions'), [
        new MenuRow('pastePalette', this.t('palette.importFromClipboard')),
        new MenuRow('scanPalette', this.t('palette.scanImport')),
        new MenuRow('qrPalette', this.t('palette.shareScanCode')),
        new MenuRow('copyPalette', this.t('palette.exportToClipboard')),
      ])],
      textColor: this.ink(), muted: this.muted(), card: this.surface(), divider: this.line(),
      onAction: (id: string) => {
        if (id === 'pastePalette') void this.pastePalette();
        else if (id === 'scanPalette') void this.scanCode();
        else if (id === 'copyPalette') void this.copy(JSON.stringify(this.chosenPalette()));
        else {
          const envelope: ShareEnvelope = {
            app: 'iwut', version: 1, action: 'import', type: 'schedule.palette', payload: this.chosenPalette()
          };
          this.showQr(JSON.stringify(envelope));
        }
      }
    })
  }

  @Builder
  private subpage(name: string) {
    if (name === 'choice') {
      MenuGroups({
        groups: [new MenuGroup('', this.choiceOptions.map(option => new MenuRow(option.id, option.label)))],
        textColor: this.ink(), muted: this.muted(), card: this.surface(), divider: this.line(),
        onAction: (id: string) => { this.back(); this.chooseAction(id); }
      })
    } else if (name === 'about') {
      Image($r('app.media.start_icon')).width(74).height(74).borderRadius(18).onClick(() => {
        this.confirm(this.t('developer.title'), this.t('developer.enable'), this.t('common.confirm'), () => {
          this.setting(settings => { settings.developer = true; });
        });
      })
      Text(this.t('about.appName')).fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.ink())
      this.menu(settingsMenu(name, this.data, key => this.t(key)))
    } else if (['general', 'appearance', 'calendar', 'visual', 'developer'].includes(name)) {
      this.menu(settingsMenu(name, this.data, key => this.t(key), this.doingIntegration))
    } else if (name === 'courseMenu') {
      this.menu([new MenuGroup('', [
        new MenuRow('manage', this.t('course.drawer.manage')),
        new MenuRow('reimport', this.t('course.drawer.reimport')),
        new MenuRow('calendar', this.t('course.drawer.settings'))
      ])])
    } else if (name === 'manage') {
      this.manageCourses()
    } else if (name === 'edit') {
      CourseEditor({
        initial: this.selectedCourses(), prefill: this.editPrefill, weekdays: this.weekdays(), periods: this.periods(),
        onSave: (records: Course[]) => this.saveCourses(records),
        onShare: (records: Course[]) => this.startCourseShare(records),
        onDelete: () => { if (this.selection) this.deleteCourse(this.selection); },
        t: (key: string) => this.t(key), ink: this.ink(), muted: this.muted(), card: this.surface(),
        blue: this.blue(), tile: this.bg(), line: this.line()
      })
    } else if (name === 'grade') {
      this.gradePage()
    } else if (name === 'exam') {
      this.examPage()
    } else if (name === 'palette') {
      this.palettePage()
    } else if (name === 'lab') {
      LabImport({
        termStart: this.data.termStart, profileStudentId: this.data.profile?.studentId ?? '',
        periods: this.periods(), textColor: this.ink(), muted: this.muted(),
        onImported: (courses: Course[]) => {
          this.persist(next => { next.courses = validCourses(next.courses.filter(item => item.source !== 'lab').concat(courses)); });
          this.afterScheduleChange();
          this.back();
          this.toast(this.t('course.labImportSuccessSub').replace('{n}', courses.length.toString()));
        }
      })
    } else if (name === 'wlan') {
      WlanPage({
        t: (key: string) => this.t(key), ink: this.ink(), muted: this.muted(), card: this.surface(), line: this.line(),
        openPortal: () => this.openWeb('http://172.30.21.100/', this.t('wlan.title'))
      })
    } else if (name === 'qr') {
      QRCode(this.qrText).width(254).height(254).backgroundColor(Color.White).color(Color.Black)
      Button(this.t('scan.copyContent'), { type: ButtonType.Normal }).onClick(() => { void this.copy(this.qrText); })
    } else if (name === 'agreement' || name === 'privacy') {
      Text(this.resources?.text(name === 'agreement' ? 'USER_AGREEMENT.md' : 'PRIVACY_POLICY.md') ?? '')
        .fontSize(14).fontColor(this.ink()).lineHeight(22).width('100%').textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
    } else if (name === 'logs') {
      TextInput({ text: this.logQuery, placeholder: this.t('developer.logsSearch') })
        .onChange(value => { this.logQuery = value; })
      Row({ space: 8 }) {
        Button(this.t('developer.logsCopy')).onClick(() => { void this.copy(this.logs.join('\n')); })
        Button(this.t('developer.logsClear'), { type: ButtonType.Normal }).onClick(() => { this.logs = []; })
      }
      ForEach(this.logs.filter(line => line.includes(this.logQuery)), (line: string, index: number) => {
        Text(line).fontColor(this.ink()).fontSize(13).width('100%')
      }, (line: string, index: number) => line + index)
    }
  }

  @Builder
  private appContent() {
    Column() {
      if (this.loaded) {
        if (!this.data.onboarding) {
          Scroll() {
            this.onboarding()
          }.width('100%').layoutWeight(1)
        } else {
          Navigation(this.pageStack) {
            this.mainTabs()
          }
          .mode(NavigationMode.Stack)
          .hideTitleBar(true)
          .hideToolBar(true)
          .navDestination(this.routeMap)
          .width('100%').layoutWeight(1)
          .backgroundColor(this.bg())
        }
        if (this.storageProblem) {
          Text(this.storageProblem).fontSize(13).padding(8).backgroundColor('#FFF0D8').fontColor('#70420B').width('100%')
        }
        if (this.quietSync && this.quietRoute) {
          Column() {
            CampusWeb({
              url: this.quietRoute.url, prefix: this.quietRoute.prefix,
              script: this.resources?.text(this.quietRoute.kind + '.js') ?? '', controller: this.quietBrowser,
              onResult: (value: AcademicResult) => this.quietResult(value)
            })
          }.width(1).height(1).opacity(0).hitTestBehavior(HitTestMode.None)
        }
      }
    }.height('100%').width('100%').backgroundColor(this.bg())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  private courseShareContent() {
    CourseShareSheet({
      value: this.sharePayload, link: courseShareLink(this.sharePayload),
      ink: this.ink(), muted: this.muted(), tile: this.bg(),
      t: (key: string) => this.t(key), onMessage: (message: string) => this.toast(message)
    })
  }

  build() {
    Stack() {
      this.appContent()
      if (this.courseModal) {
        Row().width('100%').height('100%').backgroundBlurStyle(BlurStyle.Thin)
          .backgroundColor('#26000000')
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))
          .onClick(() => { this.courseModal = ''; })
      }
      if (this.courseModal === 'detail' && this.selection) {
        CourseDetailCard({
          course: this.selection, periods: this.periods(), weekday: this.weekdays()[this.selection.day - 1],
          color: courseColor(this.selection, this.chosenPalette()), textColor: this.ink(), muted: this.muted(),
          card: this.surface(), tile: this.bg(), addAvailable: this.mainTab === 1,
          t: (key: string) => this.t(key),
          onClose: () => { this.courseModal = ''; },
          onEdit: () => this.openCourseEditor(this.selection),
          onShare: () => this.startCourseShare(this.selectedCourses()),
          onAdd: () => {
            const course = this.selection;
            if (course) {
              const slot: CourseSlotRange = {
                day: course.day, sectionStart: course.sectionStart, sectionEnd: course.sectionEnd
              };
              this.openQuickAdd(slot);
            }
          }
        })
      } else if (this.courseModal === 'quick') {
        QuickCourseCard({
          slot: this.quickSlot, week: this.week, weekday: this.weekdays()[this.quickSlot.day - 1],
          time: this.quickSlotTime(), textColor: this.ink(), muted: this.muted(), card: this.surface(),
          tile: this.bg(), blue: this.blue(), t: (key: string) => this.t(key),
          onClose: () => { this.courseModal = ''; },
          onSave: (draft: QuickCourseDraft) => this.addQuickCourse(draft),
          onCustom: (draft: QuickCourseDraft) => this.openCourseEditor(null, draft)
        })
      }
    }.width('100%').height('100%')
      .bindSheet(this.courseShareVisible, this.courseShareContent(), {
        preferType: SheetType.BOTTOM, height: SheetSize.FIT_CONTENT, dragBar: true, showClose: false,
        backgroundColor: this.surface(), maskColor: '#63000000',
        onDisappear: () => { this.courseShareVisible = false; }
      })
  }
}
