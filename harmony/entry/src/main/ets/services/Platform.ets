import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { vibrator } from '@kit.SensorServiceKit';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { util } from '@kit.ArkTS';
import { Course, Data, Palette, validCourses, validPalette } from '../model/Iwut';

export interface CourseBackup {
  courses: Course[];
  termStart: string;
}

interface SharedCourseSlot {
  room: string;
  day: number;
  sectionStart: number;
  sectionEnd: number;
  weekStart: number;
  weekEnd: number;
  startTime?: string;
  endTime?: string;
  timeMode?: string;
  note?: string;
  seat?: number;
}

interface CourseSharePayload {
  courses?: Course[];
  termStart?: string;
  name?: string;
  teacher?: string;
  records?: Course[];
  slots?: SharedCourseSlot[];
}

export interface ShareEnvelope {
  app: string;
  version: number;
  action: string;
  type: string;
  payload: CourseSharePayload | Palette;
}

export function clickFeedback(): void {
  vibrator.startVibration({ type: 'time', duration: 16 }, { id: 0, usage: 'touch' }).catch(() => {});
}

export async function copyText(value: string): Promise<void> {
  const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, value);
  await pasteboard.getSystemPasteboard().setData(data);
}

export async function pasteText(): Promise<string> {
  const data = await pasteboard.getSystemPasteboard().getData();
  return data.getPrimaryText() || '';
}

export async function pickBackground(context: common.UIAbilityContext): Promise<string> {
  const picker = new photoAccessHelper.PhotoViewPicker();
  const opt = new photoAccessHelper.PhotoSelectOptions();
  opt.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
  opt.maxSelectNumber = 1;
  const result = await picker.select(opt);
  if (result.photoUris.length === 0) return '';
  const image = fileIo.openSync(result.photoUris[0], fileIo.OpenMode.READ_ONLY);
  const destination = context.filesDir + '/timetable-background-' + Date.now();
  try {
    fileIo.copyFileSync(image.fd, destination);
    return destination;
  } finally {
    fileIo.closeSync(image);
  }
}

export async function saveFile(context: common.UIAbilityContext, name: string, contents: string): Promise<boolean> {
  const dialog = new picker.DocumentViewPicker(context);
  const options = new picker.DocumentSaveOptions();
  options.newFileNames = [name];
  const destinations = await dialog.save(options);
  if (!destinations.length) return false;
  const file = fileIo.openSync(destinations[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
  try {
    fileIo.writeSync(file.fd, contents);
    return true;
  } finally {
    fileIo.closeSync(file);
  }
}

export async function readCourseBackup(context: common.UIAbilityContext): Promise<CourseBackup | null> {
  const dialog = new picker.DocumentViewPicker(context);
  const options = new picker.DocumentSelectOptions();
  options.maxSelectNumber = 1;
  options.fileSuffixFilters = ['JSON|.json'];
  const sources = await dialog.select(options);
  if (!sources.length) return null;
  const file = fileIo.openSync(sources[0], fileIo.OpenMode.READ_ONLY);
  try {
    const size = fileIo.statSync(file.fd).size;
    if (size > 2000000) throw new Error('课表文件过大');
    const buffer = new ArrayBuffer(size);
    const count = fileIo.readSync(file.fd, buffer);
    const text = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buffer, 0, count));
    const data = JSON.parse(text) as CourseBackup;
    if (!data || !Array.isArray(data.courses) || typeof data.termStart !== 'string') throw new Error('课表格式无效');
    const courses = validCourses(data.courses);
    if (courses.length !== data.courses.length) throw new Error('课表中存在重复或无效的课程');
    return { courses, termStart: data.termStart };
  } finally {
    fileIo.closeSync(file);
  }
}

export function courseBackup(data: Data): string {
  const exported: CourseBackup = { courses: data.courses, termStart: data.termStart };
  return JSON.stringify(exported, null, 2);
}

export async function scan(context: common.UIAbilityContext): Promise<string> {
  const result = await scanBarcode.startScanForResult(context, {
    scanTypes: [scanCore.ScanType.QR_CODE], enableAlbum: true, enableMultiMode: false
  });
  return result.originalValue;
}

export function courseShareText(records: Course[]): string {
  const first = records[0];
  if (!first) return '';
  const slots = records.map((course): SharedCourseSlot => ({
    room: course.room, day: course.day, sectionStart: course.sectionStart, sectionEnd: course.sectionEnd,
    weekStart: course.weekStart, weekEnd: course.weekEnd, startTime: course.startTime,
    endTime: course.endTime, timeMode: course.timeMode, note: course.note, seat: course.seat
  }));
  const envelope: ShareEnvelope = {
    app: 'iwut', version: 1, action: 'import', type: 'course.single', payload: { name: first.name, teacher: first.teacher, slots }
  };
  return JSON.stringify(envelope);
}

export function courseShareLink(value: string): string {
  return 'https://iwut.tokenteam.net/share?iwut=' + encodeURIComponent('share?data=' + encodeURIComponent(value));
}

export function scanResult(text: string): ShareEnvelope | null {
  let raw = text.trim();
  if (!raw || raw.length > 12000) return null;
  try {
    if (raw.startsWith('iwut://share?data=')) {
      raw = decodeURIComponent(raw.slice('iwut://share?data='.length));
    } else if (raw.startsWith('https://iwut.tokenteam.net/share?iwut=')) {
      return scanResult('iwut://' + decodeURIComponent(raw.slice('https://iwut.tokenteam.net/share?iwut='.length)));
    }
    const envelope = JSON.parse(raw) as ShareEnvelope;
    if (!envelope || envelope.app !== 'iwut' || envelope.version !== 1 || !envelope.payload) return null;
    return envelope;
  } catch (_) {
    return null;
  }
}

export function envelopePalette(value: ShareEnvelope | null): Palette | null {
  if (value === null || value.action !== 'import' || value.type !== 'schedule.palette') return null;
  const palette = value.payload as Palette;
  return validPalette(palette) ? palette : null;
}

export function envelopeCourses(value: ShareEnvelope | null): Course[] {
  if (value === null || value.action !== 'import' || value.type !== 'course.single') return [];
  const data = value.payload as CourseSharePayload;
  if (Array.isArray(data.courses)) return validCourses(data.courses);
  if (Array.isArray(data.slots) && typeof data.name === 'string') {
    return validCourses(data.slots.filter(course => course && typeof course === 'object').map((course): Course => ({
      name: data.name ?? '', teacher: data.teacher ?? '', room: course.room, day: course.day,
      sectionStart: course.sectionStart, sectionEnd: course.sectionEnd, weekStart: course.weekStart, weekEnd: course.weekEnd,
      startTime: course.startTime, endTime: course.endTime, timeMode: course.timeMode, note: course.note,
      seat: course.seat, source: 'manual'
    })));
  }
  return [];
}
