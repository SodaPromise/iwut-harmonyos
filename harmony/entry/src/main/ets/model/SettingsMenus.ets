import { Data, Settings } from './Iwut';
import { MenuGroup, MenuRow } from '../components/Menu';

export function settingsMenu(page: string, data: Data, t: (key: string) => string,
  calendarBusy: boolean = false): MenuGroup[] {
  const s = data.settings;
  switch (page) {
    case 'general':
      return [
        new MenuGroup(t('settings.interaction'), [
          new MenuRow('haptic', t('settings.haptic'), '', s.haptic),
          new MenuRow('openCourseOnLaunch', t('settings.openCourseOnLaunch'), '', s.openCourseOnLaunch),
        ]),
        new MenuGroup(t('settings.notification'), notificationRows(s, t, calendarBusy)),
        new MenuGroup(t('settings.privacy'), [
          new MenuRow('telemetry', t('settings.telemetry'), '鸿蒙版未接入遥测', false, false),
        ]),
        new MenuGroup(t('settings.storage'), [
          new MenuRow('clearCache', t('settings.clearCache')),
          new MenuRow('exportLogs', t('settings.exportLogs')),
        ]),
      ];
    case 'appearance':
      return [
        new MenuGroup(t('appearance.themeGroup'), [
          new MenuRow('theme', t('appearance.theme'), t(themeKey(s.theme))),
          new MenuRow('background', t('appearance.bg'), t(s.backgroundUri ? 'appearance.bgSet' : 'appearance.bgNone')),
        ]),
        new MenuGroup(t('appearance.languageGroup'), [
          new MenuRow('language', t('appearance.language'), t(languageKey(s.language))),
        ]),
      ];
    case 'calendar':
      return [
        new MenuGroup(t('calendarSet.courseGroup'), [
          new MenuRow('manage', t('calendarSet.courseManage'),
            data.courses.length ? t('calendarSet.courseCount').replace('{n}', countCourses(data).toString()) :
              t('calendarSet.noCourses')),
        ]),
        new MenuGroup(t('calendarSet.dataGroup'), [
          new MenuRow('academicSync', t('calendarSet.academicSync'),
            data.coursesSyncedAt ? data.coursesSyncedAt : t('calendarSet.neverSynced'), s.autoRefreshCourses),
          new MenuRow('export', t('calendarSet.exportCourses')),
          new MenuRow('import', t('calendarSet.importCourses')),
        ]),
        new MenuGroup(t('calendarSet.displayGroup'), [
          new MenuRow('scrollWeekend', t('calendarSet.scrollWeekend'), '', s.scrollWeekend),
          new MenuRow('showMidday', t('calendarSet.showMidday'), '', s.showMidday),
          new MenuRow('showOtherWeek', t('calendarSet.showOtherWeek'), '', s.showOtherWeek),
        ]),
        new MenuGroup(t('calendarSet.syncGroup'), [
          new MenuRow('syncCalendar', t('calendarSet.syncCalendar'), '', s.syncCalendar, !calendarBusy),
        ]),
        new MenuGroup(t('calendarSet.customGroup'), [
          new MenuRow('palette', t('calendarSet.palette'), s.palette),
          new MenuRow('visual', t('calendarSet.visualStyle')),
        ]),
      ];
    case 'visual':
      return [
        new MenuGroup(t('scheduleVisual.backgroundGroup'), [
          slider('backgroundImageOpacity', t('scheduleVisual.bgOpacity'), s.backgroundImageOpacity, 100, '%'),
          slider('backgroundImageBlurRadius', t('scheduleVisual.bgBlur'), s.backgroundImageBlurRadius, 30, 'px'),
        ]),
        new MenuGroup(t('scheduleVisual.cellsGroup'), [
          slider('courseCellOpacity', t('scheduleVisual.courseCellOpacity'), s.courseCellOpacity, 100, '%'),
          slider('otherWeekCellOpacity', t('scheduleVisual.otherWeekCellOpacity'), s.otherWeekCellOpacity, 100, '%'),
          slider('locatorCellOpacity', t('scheduleVisual.locatorCellOpacity'), s.locatorCellOpacity, 100, '%'),
        ]),
        new MenuGroup(t('scheduleVisual.actionsGroup'), [new MenuRow('resetVisual', t('scheduleVisual.reset'))]),
      ];
    case 'about':
      return [
        new MenuGroup(t('about.infoGroup'), [
          new MenuRow('version', t('about.version'), '0.3.31 · HarmonyOS'),
          new MenuRow('commit', t('about.commit'), '10335a5'),
        ]),
        new MenuGroup(t('about.updateGroup'), [new MenuRow('update', t('about.checkUpdate'))]),
        new MenuGroup(t('about.linksGroup'), [
          new MenuRow('website', t('about.website')),
          new MenuRow('github', t('about.github')),
          new MenuRow('agreement', t('about.userAgreement')),
          new MenuRow('privacy', t('about.privacyPolicy')),
        ]),
        new MenuGroup(t('about.feedbackGroup'), [
          new MenuRow('issues', t('about.githubIssues'), t('about.recommended')),
          new MenuRow('feedback', t('about.inAppFeedback'), '鸿蒙版暂未接入', undefined, false),
        ]),
      ];
    case 'developer':
      return [
        new MenuGroup('', [new MenuRow('developer', t('developer.enable'), '', s.developer)]),
        new MenuGroup(t('developer.debugSection'), [new MenuRow('logs', t('developer.viewLogs'))]),
        new MenuGroup(t('developer.sentrySection'), [
          new MenuRow('sentry', t('developer.sentryTest'), '鸿蒙版暂未接入', undefined, false),
        ]),
        new MenuGroup(t('settings.storage'), [new MenuRow('clearAll', t('developer.clearAllData'))]),
      ];
    default:
      return [];
  }
}

function notificationRows(s: Settings, t: (key: string) => string, calendarBusy: boolean): MenuRow[] {
  const rows: MenuRow[] = [
    new MenuRow('courseReminder', t('settings.courseReminder'), '系统日历', s.courseReminder, !calendarBusy)
  ];
  if (s.courseReminder) {
    rows.push(new MenuRow('reminderMinutes', t('settings.reminderTime'),
      t('settings.reminderTimeMins').replace('{n}', s.reminderMinutes.toString()), undefined, !calendarBusy));
  }
  rows.push(new MenuRow('examReminder', t('settings.examReminder'), '系统日历', s.examReminder, !calendarBusy),
    new MenuRow('courseDnd', '考前免打扰', '在系统设置中开启'));
  return rows;
}

export function themeKey(mode: string): string {
  if (mode === 'dark') return 'appearance.themeDark';
  if (mode === 'light') return 'appearance.themeLight';
  return 'appearance.themeSystem';
}

export function languageKey(language: string): string {
  if (language === 'en') return 'appearance.langEn';
  if (language === 'zh') return 'appearance.langZh';
  return 'appearance.langSystem';
}

function slider(id: string, label: string, value: number, max: number, unit: string): MenuRow {
  const row = new MenuRow(id, label, value + unit);
  row.slider = value;
  row.maximum = max;
  return row;
}

function countCourses(data: Data): number {
  return new Set(data.courses.map(course => course.name)).size;
}
