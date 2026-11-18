import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { i18n } from '@kit.LocalizationKit';

export interface Course {
  name: string;
  room: string;
  teacher: string;
  day: number;
  sectionStart: number;
  sectionEnd: number;
  weekStart: number;
  weekEnd: number;
  source?: string;
  startTime?: string;
  endTime?: string;
  note?: string;
  seat?: number;
  timeMode?: string;
}

export interface Grade {
  id: string;
  term: string;
  courseName: string;
  courseCode: string;
  courseNature: string;
  totalScore: string;
  credits: string;
  retakeLabel: string;
}

export interface Exam {
  id: string;
  courseName: string;
  courseCode: string;
  date?: string;
  startTime?: string;
  endTime?: string;
  startAt?: string;
  endAt?: string;
  place?: string;
  seatNo?: string;
  teacher: string;
  description?: string;
  rawStatus?: string;
}

export interface Profile {
  name: string;
  studentId: string;
  college: string;
  eduLevel: string;
  cardId: string;
}

export interface Palette {
  name: string;
  version: number;
  colors: string[];
  overrides?: Record<string, string>;
}

export interface Period {
  number: number;
  start: string;
  end: string;
}

interface AudienceMatch {
  studentIds?: string[];
  studentIdPrefixes?: string[];
  colleges?: string[];
  eduLevels?: string[];
  hasCardId?: boolean;
}

interface Audience {
  requireBound?: boolean;
  allow?: AudienceMatch[];
  deny?: AudienceMatch[];
}

export interface Shortcut {
  icon: string;
  labelKey: string;
  color: string;
  route?: string;
  uri?: string;
  lan?: boolean;
  filter?: Audience;
}

export interface ShortcutGroup {
  titleKey: string;
  items: Shortcut[];
}

export function shortcutVisible(shortcut: Shortcut, user: Profile | null): boolean {
  const filter = shortcut.filter;
  if (filter === undefined) return true;
  if (user === null) return filter.requireBound !== true && filter.allow === undefined;
  if (filter.deny?.some(rule => matches(rule, user))) return false;
  return filter.allow === undefined || filter.allow.some(rule => matches(rule, user));
}

function matches(rule: AudienceMatch, user: Profile): boolean {
  if (!rule.studentIds && !rule.studentIdPrefixes && !rule.colleges && !rule.eduLevels && rule.hasCardId === undefined) {
    return false;
  }
  return (rule.studentIds?.includes(user.studentId) ?? true) &&
    (rule.studentIdPrefixes?.some(prefix => prefix.length > 0 && user.studentId.startsWith(prefix)) ?? true) &&
    (rule.colleges?.includes(user.college) ?? true) && (rule.eduLevels?.includes(user.eduLevel) ?? true) &&
    (rule.hasCardId === undefined || Boolean(user.cardId) === rule.hasCardId);
}

export class Settings {
  language: string = 'system';
  theme: string = 'system';
  palette: string = '默认';
  backgroundUri: string = '';
  reminderMinutes: number = 30;
  backgroundImageOpacity: number = 25;
  backgroundImageBlurRadius: number = 0;
  courseCellOpacity: number = 100;
  otherWeekCellOpacity: number = 14;
  locatorCellOpacity: number = 100;
  haptic: boolean = true;
  openCourseOnLaunch: boolean = false;
  courseReminder: boolean = false;
  examReminder: boolean = false;
  courseDnd: boolean = false;
  telemetry: boolean = false;
  autoRefreshCourses: boolean = false;
  scrollWeekend: boolean = false;
  showMidday: boolean = false;
  showOtherWeek: boolean = true;
  syncCalendar: boolean = false;
  developer: boolean = false;

  constructor(saved?: Settings) {
    if (!saved) return;
    this.language = saved.language ?? this.language;
    this.theme = saved.theme ?? this.theme;
    this.palette = saved.palette ?? this.palette;
    this.backgroundUri = saved.backgroundUri ?? this.backgroundUri;
    this.reminderMinutes = saved.reminderMinutes ?? this.reminderMinutes;
    this.backgroundImageOpacity = saved.backgroundImageOpacity ?? this.backgroundImageOpacity;
    this.backgroundImageBlurRadius = saved.backgroundImageBlurRadius ?? this.backgroundImageBlurRadius;
    this.courseCellOpacity = saved.courseCellOpacity ?? this.courseCellOpacity;
    this.otherWeekCellOpacity = saved.otherWeekCellOpacity ?? this.otherWeekCellOpacity;
    this.locatorCellOpacity = saved.locatorCellOpacity ?? this.locatorCellOpacity;
    this.haptic = saved.haptic ?? this.haptic;
    this.openCourseOnLaunch = saved.openCourseOnLaunch ?? this.openCourseOnLaunch;
    this.courseReminder = saved.courseReminder ?? this.courseReminder;
    this.examReminder = saved.examReminder ?? this.examReminder;
    this.courseDnd = saved.courseDnd ?? this.courseDnd;
    this.telemetry = saved.telemetry ?? this.telemetry;
    this.autoRefreshCourses = saved.autoRefreshCourses ?? this.autoRefreshCourses;
    this.scrollWeekend = saved.scrollWeekend ?? this.scrollWeekend;
    this.showMidday = saved.showMidday ?? this.showMidday;
    this.showOtherWeek = saved.showOtherWeek ?? this.showOtherWeek;
    this.syncCalendar = saved.syncCalendar ?? this.syncCalendar;
    this.developer = saved.developer ?? this.developer;
  }
}

export class Data {
  settings: Settings = new Settings();
  courses: Course[] = [];
  grades: Grade[] = [];
  exams: Exam[] = [];
  notArranged: Exam[] = [];
  customPalettes: Palette[] = [];
  profile: Profile | null = null;
  onboarding: boolean = false;
  termStart: string = '';
  academicCourseKind: string = '';
  examTerm: string = '';
  coursesSyncedAt: string = '';
  coursesSyncedTime: number = 0;
  examsSyncedAt: string = '';
  gradesSyncedAt: string = '';
  calendarEventIds: number[] = [];
  reminderIds: number[] = [];

  constructor(saved?: Data) {
    if (!saved) return;
    this.settings = new Settings(saved.settings);
    this.courses = saved.courses ?? this.courses;
    this.grades = saved.grades ?? this.grades;
    this.exams = saved.exams ?? this.exams;
    this.notArranged = saved.notArranged ?? this.notArranged;
    this.customPalettes = saved.customPalettes ?? this.customPalettes;
    this.profile = saved.profile ?? this.profile;
    this.onboarding = saved.onboarding ?? this.onboarding;
    this.termStart = saved.termStart ?? this.termStart;
    this.academicCourseKind = saved.academicCourseKind ?? this.academicCourseKind;
    this.examTerm = saved.examTerm ?? this.examTerm;
    this.coursesSyncedAt = saved.coursesSyncedAt ?? this.coursesSyncedAt;
    this.coursesSyncedTime = saved.coursesSyncedTime ?? this.coursesSyncedTime;
    this.examsSyncedAt = saved.examsSyncedAt ?? this.examsSyncedAt;
    this.gradesSyncedAt = saved.gradesSyncedAt ?? this.gradesSyncedAt;
    this.calendarEventIds = saved.calendarEventIds ?? this.calendarEventIds;
    this.reminderIds = saved.reminderIds ?? this.reminderIds;
  }
}

export interface AcademicRoute {
  kind: string;
  url: string;
  prefix: string;
}

export interface AcademicResult {
  type: string;
  message?: string;
  termStart?: string;
  term?: string;
  name?: string;
  studentId?: string;
  college?: string;
  eduLevel?: string;
  cardId?: string;
  data?: Course[];
  courses?: Course[];
  grades?: Grade[];
  exams?: Exam[];
  notArranged?: Exam[];
}

export class UpstreamResources {
  private context: common.Context;
  private zh: Record<string, string>;
  private en: Record<string, string>;
  shortcuts: ShortcutGroup[];
  routes: AcademicRoute[];
  palettes: Palette[];
  periods: Period[];

  constructor(context: common.Context) {
    this.context = context;
    this.zh = JSON.parse(this.text('zh.json')) as Record<string, string>;
    this.en = JSON.parse(this.text('en.json')) as Record<string, string>;
    this.shortcuts = JSON.parse(this.text('functions.json')) as ShortcutGroup[];
    this.routes = JSON.parse(this.text('academic.json')) as AcademicRoute[];
    this.palettes = JSON.parse(this.text('palettes.json')) as Palette[];
    this.periods = JSON.parse(this.text('periods.json')) as Period[];
  }

  text(name: string): string {
    const data = this.context.resourceManager.getRawFileContentSync(name);
    return util.TextDecoder.create('utf-8').decodeToString(data);
  }

  t(key: string, language: string): string {
    const english = language === 'en' || (language === 'system' && i18n.System.getSystemLanguage().startsWith('en'));
    return (english ? this.en[key] : this.zh[key]) ?? this.zh[key] ?? key;
  }
}

export class LocalData {
  private storage: preferences.Preferences;
  private pending: Promise<void> = Promise.resolve();

  constructor(context: common.Context) {
    this.storage = preferences.getPreferencesSync(context, { name: 'iwut-client' });
  }

  read(): Data {
    const saved = this.storage.getSync('data', '') as string;
    if (!saved) return new Data();
    try {
      return new Data(JSON.parse(saved) as Data);
    } catch (_) {
      return new Data();
    }
  }

  save(data: Data): Promise<void> {
    const snapshot = JSON.stringify(data);
    this.pending = this.pending.catch(() => {}).then(async () => {
      await this.storage.put('data', snapshot);
      await this.storage.flush();
    });
    return this.pending;
  }
}

export function validCourses(rows: Course[]): Course[] {
  if (!Array.isArray(rows)) return [];
  const unique = new Set<string>();
  const output: Course[] = [];
  for (const row of rows) {
    if (!row || typeof row.name !== 'string' || row.name.trim().length === 0) continue;
    const day = Number(row.day);
    const sectionStart = Number(row.sectionStart);
    const sectionEnd = Number(row.sectionEnd);
    const weekStart = Number(row.weekStart);
    const weekEnd = Number(row.weekEnd);
    if (![day, sectionStart, sectionEnd, weekStart, weekEnd].every(value => Number.isInteger(value)) ||
      day < 1 || day > 7 || sectionStart < 1 || sectionStart > sectionEnd || sectionEnd > 16 ||
      weekStart < 1 || weekStart > weekEnd || weekEnd > 20) continue;
    const course: Course = {
      name: row.name.trim(), teacher: typeof row.teacher === 'string' ? row.teacher : '',
      room: typeof row.room === 'string' ? row.room : '',
      day, sectionStart, sectionEnd, weekStart, weekEnd,
      source: row.source, startTime: row.startTime, endTime: row.endTime, timeMode: row.timeMode,
      note: row.note, seat: row.seat,
    };
    const key = JSON.stringify(course);
    if (!unique.has(key)) {
      unique.add(key);
      output.push(course);
    }
  }
  return output;
}

export function validPalette(value: Palette): boolean {
  return !!value && value.version === 1 && typeof value.name === 'string' &&
    value.name.trim().length > 0 && Array.isArray(value.colors) && value.colors.length > 0 &&
    value.colors.every(color => typeof color === 'string' && /^#[0-9A-Fa-f]{6}$/.test(color));
}

export function localDate(value: string): Date {
  const parts = value.slice(0, 10).split('-').map(part => Number(part));
  if (parts.length !== 3) return new Date(NaN);
  return new Date(parts[0], parts[1] - 1, parts[2]);
}

const DAY_MS = 24 * 60 * 60 * 1000;
const CAMPUS_OFFSET_MS = 8 * 60 * 60 * 1000;
const MAX_WEEK = 20;

function termWeek(termStart: string, calendarDay: number): number {
  const start = localDate(termStart);
  if (!Number.isFinite(start.getTime())) return 1;
  const startDay = Date.UTC(start.getFullYear(), start.getMonth(), start.getDate());
  return Math.floor((calendarDay - startDay) / (7 * DAY_MS)) + 1;
}

export function currentWeek(termStart: string, day: Date): number {
  const calendarDay = Date.UTC(day.getFullYear(), day.getMonth(), day.getDate());
  return Math.max(1, Math.min(MAX_WEEK, termWeek(termStart, calendarDay)));
}

export function homeGreetingKey(hour: number): string {
  if (hour < 5 || hour >= 23) return 'home.greetLateNight';
  if (hour < 8) return 'home.greetEarlyMorning';
  if (hour < 11) return 'home.greetMorning';
  if (hour < 13) return 'home.greetNoon';
  if (hour < 17) return 'home.greetAfternoon';
  if (hour < 19) return 'home.greetEvening';
  return 'home.greetNight';
}

export interface CampusDay {
  week: number;
  weekday: number;
  month: number;
  day: number;
  vacation: boolean;
}

export function campusDay(termStart: string, now: number, tomorrow: boolean = false): CampusDay {
  const date = new Date(now + CAMPUS_OFFSET_MS + (tomorrow ? DAY_MS : 0));
  const month = date.getUTCMonth();
  const day = date.getUTCDate();
  const week = termWeek(termStart, Date.UTC(date.getUTCFullYear(), month, day));
  return {
    week: Math.max(1, Math.min(MAX_WEEK, week)), weekday: date.getUTCDay() || 7, month: month + 1, day,
    vacation: week < 1 || week > MAX_WEEK
  };
}

export function coursesForCampusDay(courses: Course[], date: CampusDay): Course[] {
  if (date.vacation) return [];
  return courses.filter(course => course.day === date.weekday && course.weekStart <= date.week && course.weekEnd >= date.week)
    .sort((left, right) => left.sectionStart - right.sectionStart);
}

interface HomeCourseTiming {
  finished: boolean;
  countdown?: 'start' | 'end';
  minutes: number;
}

export function timeMinutes(value?: string): number | undefined {
  if (typeof value !== 'string') return undefined;
  const match = /^(\d{1,2}):(\d{2})$/.exec(value.trim());
  if (!match) return undefined;
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  return hours < 24 && minutes < 60 ? hours * 60 + minutes : undefined;
}

export function homeCourseTiming(course: Course, periods: Period[], now: number): HomeCourseTiming {
  const start = timeMinutes(course.startTime) ?? timeMinutes(periods.find(period => period.number === course.sectionStart)?.start);
  const end = timeMinutes(course.endTime) ?? timeMinutes(periods.find(period => period.number === course.sectionEnd)?.end);
  const date = new Date(now + CAMPUS_OFFSET_MS);
  const minute = date.getUTCHours() * 60 + date.getUTCMinutes();
  if (end === undefined) return { finished: false, minutes: 0 };
  if (minute > end) return { finished: true, minutes: 0 };
  if (start === undefined) return { finished: false, minutes: 0 };
  if (minute >= start) return { finished: false, countdown: 'end', minutes: end - minute };
  if (start - minute <= 60) return { finished: false, countdown: 'start', minutes: start - minute };
  return { finished: false, minutes: 0 };
}

export function courseTime(course: Course, periods: Period[]): string {
  return (course.startTime || periods[course.sectionStart - 1]?.start || '') + ' – ' +
    (course.endTime || periods[course.sectionEnd - 1]?.end || '');
}

export interface TimetableBlock {
  course?: Course;
  firstRow: number;
  rowCount: number;
  belongsToWeek: boolean;
  overlapCount: number;
}

interface TimetableCandidate {
  course: Course;
  belongsToWeek: boolean;
}

export const TIMETABLE_SLOT_ENDS: number[] = [2, 5, 7, 10, 12, 13, 16];

export function timetableBlocks(courses: Course[], periods: Period[], day: number, week: number,
  showOtherWeek: boolean): TimetableBlock[] {
  const candidates = courses.filter(course => course.day === day)
    .map((course): TimetableCandidate => ({
      course, belongsToWeek: week >= course.weekStart && week <= course.weekEnd
    }))
    .filter(candidate => candidate.belongsToWeek || showOtherWeek)
    .sort((left, right) => Number(right.belongsToWeek) - Number(left.belongsToWeek));
  const blocks: TimetableBlock[] = [];
  periods.forEach((period, row) => {
    const matches = candidates.filter(candidate =>
      candidate.course.sectionStart <= period.number && period.number <= candidate.course.sectionEnd);
    const first = matches[0];
    const previous = blocks[blocks.length - 1];
    const overlapCount = Math.max(0, matches.length - 1);
    if (first && previous?.course === first.course) {
      previous.rowCount++;
      previous.overlapCount = Math.max(previous.overlapCount, overlapCount);
    } else if (!first && previous && !previous.course && !TIMETABLE_SLOT_ENDS.includes(periods[row - 1].number)) {
      previous.rowCount++;
    } else {
      blocks.push({
        course: first?.course, firstRow: row, rowCount: 1, belongsToWeek: first?.belongsToWeek ?? false, overlapCount
      });
    }
  });
  return blocks;
}

export function courseColor(course: Course, palette: Palette): string {
  const override = palette.overrides?.[course.name];
  if (override && /^#[0-9A-Fa-f]{6}$/.test(override)) return override;
  let hash = 0;
  for (let index = 0; index < course.name.length; index++) {
    hash = ((hash << 5) - hash + course.name.charCodeAt(index)) | 0;
  }
  return palette.colors[Math.abs(hash) % palette.colors.length];
}
