import { Course, Period, TIMETABLE_SLOT_ENDS, timeMinutes } from './Iwut';

export interface CourseSlotRange {
  day: number;
  sectionStart: number;
  sectionEnd: number;
}

export interface QuickCourseDraft {
  slot: CourseSlotRange;
  name: string;
  teacher: string;
  room: string;
  weeks: number[];
}

const SLOT_STARTS: number[] = [1, 3, 6, 8, 11, 13, 14];
export const COURSE_WEEKS: number[] = [
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
  11, 12, 13, 14, 15, 16, 17, 18, 19, 20
];

export function alignQuickSlot(slot: CourseSlotRange): CourseSlotRange {
  const first = TIMETABLE_SLOT_ENDS.findIndex(end => slot.sectionStart <= end);
  const last = TIMETABLE_SLOT_ENDS.findIndex(end => slot.sectionEnd <= end);
  return {
    day: slot.day, sectionStart: SLOT_STARTS[first] ?? slot.sectionStart,
    sectionEnd: TIMETABLE_SLOT_ENDS[last] ?? slot.sectionEnd
  };
}

export function sectionLabel(template: string, weekday: string, start: number, end: number): string {
  return template.replace('{weekday}', weekday).replace('{start}', start.toString()).replace('{end}', end.toString());
}

interface WeekRange {
  start: number;
  end: number;
}

export function weekRanges(weeks: number[]): WeekRange[] {
  const ordered = COURSE_WEEKS.filter(week => weeks.includes(week));
  const ranges: WeekRange[] = [];
  for (const week of ordered) {
    const previous = ranges[ranges.length - 1];
    if (previous && week === previous.end + 1) previous.end = week;
    else ranges.push({ start: week, end: week });
  }
  return ranges;
}

export function weekList(weeks: number[]): string {
  return weekRanges(weeks).map(range => range.start === range.end ?
    range.start.toString() : range.start + '-' + range.end).join(', ');
}

export function overlappingWeeks(courses: Course[], slot: CourseSlotRange, weeks: number[]): number[] {
  return weeks.filter(week => courses.some(course =>
    course.day === slot.day && course.sectionStart <= slot.sectionEnd && course.sectionEnd >= slot.sectionStart &&
    week >= course.weekStart && week <= course.weekEnd));
}

export function quickCourseRecords(draft: QuickCourseDraft): Course[] {
  return weekRanges(draft.weeks).map((range): Course => ({
    name: draft.name.trim(), teacher: draft.teacher.trim(), room: draft.room.trim(),
    day: draft.slot.day, sectionStart: draft.slot.sectionStart, sectionEnd: draft.slot.sectionEnd,
    weekStart: range.start, weekEnd: range.end, source: 'manual'
  }));
}

export function timeToSections(periods: Period[], day: number, start: string, end: string): CourseSlotRange | null {
  const startMinute = timeMinutes(start);
  const endMinute = timeMinutes(end);
  if (startMinute === undefined || endMinute === undefined || startMinute >= endMinute || periods.length === 0) return null;
  const first = periods.find(period => (timeMinutes(period.end) ?? -1) > startMinute) ?? periods[periods.length - 1];
  const last = periods.slice().reverse().find(period => (timeMinutes(period.start) ?? 1440) < endMinute) ?? periods[0];
  return { day, sectionStart: first.number, sectionEnd: Math.max(first.number, last.number) };
}
