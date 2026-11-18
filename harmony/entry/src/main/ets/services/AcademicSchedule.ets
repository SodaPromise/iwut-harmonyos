import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { calendarManager } from '@kit.CalendarKit';
import { Data, Exam, Period, localDate, timeMinutes } from '../model/Iwut';

const MINUTE_MS = 60000;
const CAMPUS_TIME_ZONE = 'Asia/Shanghai';
const CAMPUS_OFFSET_MS = 8 * 60 * MINUTE_MS;
const EVENT_PREFIX = 'iwut-academic:';

export class AcademicCalendarResult {
  courseEvents: number = 0;
  courseReminders: number = 0;
  examReminders: number = 0;
  cleanupPending: boolean = false;
}

function campusTime(date: Date, time?: string): number {
  const minutes = timeMinutes(time);
  if (minutes === undefined || !Number.isFinite(date.getTime())) return NaN;
  return Date.UTC(date.getFullYear(), date.getMonth(), date.getDate(), 0, minutes) - CAMPUS_OFFSET_MS;
}

export function examStart(exam: Exam): number {
  const start = Date.parse(exam.startAt ?? '');
  return Number.isFinite(start) ? start : campusTime(localDate(exam.date ?? ''), exam.startTime);
}

export function examEnd(exam: Exam): number {
  const end = Date.parse(exam.endAt ?? '');
  return Number.isFinite(end) ? end : campusTime(localDate(exam.date ?? ''), exam.endTime);
}

function academicEvent(kind: string, title: string, room: string, start: number, end: number,
  reminder?: number): calendarManager.Event {
  const event: calendarManager.Event = {
    type: calendarManager.EventType.NORMAL,
    title,
    location: { location: room },
    startTime: start,
    endTime: end,
    timeZone: CAMPUS_TIME_ZONE,
    identifier: EVENT_PREFIX + JSON.stringify([kind, title, room, start, end, reminder ?? -1])
  };
  if (reminder !== undefined) event.reminderTime = [reminder];
  return event;
}

function calendarEvents(data: Data, periods: Period[], now: number,
  result: AcademicCalendarResult): Map<string, calendarManager.Event> {
  const events = new Map<string, calendarManager.Event>();
  if (data.settings.syncCalendar || data.settings.courseReminder) {
    const term = localDate(data.termStart);
    for (const course of data.courses) {
      const startTime = course.startTime || periods.find(period => period.number === course.sectionStart)?.start;
      const endTime = course.endTime || periods.find(period => period.number === course.sectionEnd)?.end;
      for (let week = course.weekStart; week <= course.weekEnd; week++) {
        const date = new Date(term.getTime());
        date.setDate(date.getDate() + (week - 1) * 7 + course.day - 1);
        const start = campusTime(date, startTime);
        const end = campusTime(date, endTime);
        if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) continue;
        const minutes = data.settings.reminderMinutes;
        const reminder = data.settings.courseReminder && start - minutes * MINUTE_MS > now ? minutes : undefined;
        if (!data.settings.syncCalendar && reminder === undefined) continue;
        const event = academicEvent('course', course.name, course.room, start, end, reminder);
        events.set(event.identifier ?? '', event);
        result.courseEvents++;
        if (reminder !== undefined) result.courseReminders++;
      }
    }
  }
  if (data.settings.examReminder) {
    const reminder = 60;
    for (const exam of data.exams) {
      const start = examStart(exam);
      if (!Number.isFinite(start) || start - reminder * MINUTE_MS <= now) continue;
      const end = examEnd(exam);
      const event = academicEvent('exam', '考试 · ' + exam.courseName, exam.place ?? '', start,
        Number.isFinite(end) && end > start ? end : start + MINUTE_MS, reminder);
      events.set(event.identifier ?? '', event);
      result.examReminders++;
    }
  }
  return events;
}

async function authorizedCalendar(context: common.UIAbilityContext,
  requestPermission: boolean): Promise<calendarManager.Calendar> {
  const access = abilityAccessCtrl.createAtManager();
  const permissions: Permissions[] = ['ohos.permission.READ_CALENDAR', 'ohos.permission.WRITE_CALENDAR'];
  const token = context.applicationInfo.accessTokenId;
  const missing = permissions.filter(permission =>
    access.checkAccessTokenSync(token, permission) !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED);
  if (missing.length > 0) {
    if (requestPermission) {
      await access.requestPermissionsFromUser(context, missing).catch(() => {});
    }
    const denied = missing.some(permission =>
      access.checkAccessTokenSync(token, permission) !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED);
    if (denied) throw new Error('请在系统设置中允许掌上吾理访问和修改日历日程。');
  }
  return calendarManager.getCalendarManager(context).getCalendar();
}

async function cancelLegacyReminders(data: Data): Promise<void> {
  const remaining: number[] = [];
  for (const id of data.reminderIds) {
    try {
      await reminderAgentManager.cancelReminder(id);
    } catch (error) {
      const code = (error as BusinessError).code;
      if (code !== 1700003 && code !== 1700004) remaining.push(id);
    }
  }
  data.reminderIds = remaining;
}

export async function syncAcademicCalendar(context: common.UIAbilityContext, data: Data, periods: Period[],
  requestPermission: boolean = false): Promise<AcademicCalendarResult> {
  const result = new AcademicCalendarResult();
  const events = calendarEvents(data, periods, Date.now(), result);
  const enabled = data.settings.syncCalendar || data.settings.courseReminder || data.settings.examReminder;
  if (events.size > 0 || data.calendarEventIds.length > 0 || (requestPermission && enabled)) {
    const calendar = await authorizedCalendar(context, requestPermission);
    const previous = new Set<number>(data.calendarEventIds);
    // READ_CALENDAR limits this query to events created by the current app.
    const owned = (await calendar.getEvents()).filter(event => event.id !== undefined &&
      (previous.has(event.id) || (event.identifier ?? '').startsWith(EVENT_PREFIX)));
    const obsolete: number[] = [];
    const kept: number[] = [];
    for (const event of owned) {
      const id = event.id as number;
      const key = event.identifier ?? '';
      const expected = events.get(key);
      if (expected && event.startTime === expected.startTime && event.endTime === expected.endTime &&
        event.title === expected.title && (event.location?.location ?? '') === (expected.location?.location ?? '') &&
        (event.reminderTime ?? []).join(',') === (expected.reminderTime ?? []).join(',')) {
        kept.push(id);
        events.delete(key);
      } else {
        obsolete.push(id);
      }
    }
    data.calendarEventIds = kept.concat(obsolete);
    const created: number[] = [];
    try {
      for (const event of events.values()) {
        created.push(await calendar.addEvent(event));
      }
    } catch (error) {
      for (const id of created) {
        await calendar.deleteEvent(id).catch(() => { data.calendarEventIds = data.calendarEventIds.concat(id); });
      }
      const code = (error as BusinessError).code;
      throw new Error(code ? '写入系统日历失败（' + code + '）。' : '写入系统日历失败。');
    }
    const retained: number[] = [];
    for (const id of obsolete) {
      await calendar.deleteEvent(id).catch(() => { retained.push(id); });
    }
    data.calendarEventIds = kept.concat(created, retained);
    result.cleanupPending = retained.length > 0;
  }
  await cancelLegacyReminders(data);
  result.cleanupPending = result.cleanupPending || data.reminderIds.length > 0;
  return result;
}
