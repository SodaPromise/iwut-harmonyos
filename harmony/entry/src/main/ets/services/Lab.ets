import { http } from '@kit.NetworkKit';
import { Course, Period, validCourses } from '../model/Iwut';

interface LabResponse<T> {
  status: string;
  code: number;
  data?: T;
}

interface CaptchaResponse {
  captcha_key: string;
  captcha_image: string;
}

interface LoginResponse {
  access_token: string;
}

interface Term {
  id: number;
  is_on: number;
}

interface LabProject {
  project_name: string;
  name: string;
  experimental_field_name?: string;
  experimental_field_location?: string;
  teacher_name?: string[];
  class_time: string;
  status: string;
  seat_number?: number;
}

export interface LabCredentials {
  studentNumber: string;
  password: string;
  captcha: string;
  captchaKey: string;
}

export interface LabCaptcha {
  key: string;
  image: string;
}

async function labRequest<T>(path: string, body?: string, token: string = ''): Promise<T> {
  const client = http.createHttp();
  try {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json', 'X-Requested-With': 'XMLHttpRequest'
    };
    if (token) headers['Authorization'] = token;
    const response = await client.request('https://syjx.whut.edu.cn/api/minipro' + path, {
      method: body === undefined ? http.RequestMethod.GET : http.RequestMethod.POST,
      header: headers, extraData: body, readTimeout: 15000, connectTimeout: 10000,
      expectDataType: http.HttpDataType.STRING
    });
    if (response.responseCode !== 200 || typeof response.result !== 'string') throw new Error('实验教学系统请求失败');
    const result = JSON.parse(response.result) as LabResponse<T>;
    if (!result || result.status !== 'success' || result.code !== 200 || result.data === undefined) {
      throw new Error(path === '/login' ? '登录失败，请检查账号、密码与验证码。' : '实验教学系统返回的数据无效。');
    }
    return result.data;
  } finally {
    client.destroy();
  }
}

export async function labCaptcha(): Promise<LabCaptcha> {
  const result = await labRequest<CaptchaResponse>('/captcha');
  if (!result.captcha_key || !/^data:image\/(png|jpeg|jpg|gif);base64,/.test(result.captcha_image)) {
    throw new Error('验证码暂不可用。');
  }
  return { key: result.captcha_key, image: result.captcha_image };
}

function section(label: string): number {
  const standard = /^第(\d{1,2})节$/.exec(label);
  if (standard) {
    const number = Number(standard[1]);
    if (number >= 1 && number <= 5) return number;
    if (number >= 6 && number <= 10) return number + 2;
    if (number >= 11 && number <= 13) return number + 3;
  }
  if (label === '中课2') return 7;
  if (label === '中课' || label === '中课1') return 6;
  if (/^晚课\d?$/.test(label)) return 13;
  return 0;
}

function minute(text: string): number {
  const pieces = text.split(':');
  return Number(pieces[0]) * 60 + Number(pieces[1]);
}

function parse(projects: LabProject[], termStart: string, periods: Period[]): Course[] {
  const result: Course[] = [];
  const anchor = Date.parse(termStart + 'T00:00:00+08:00');
  if (!Number.isFinite(anchor)) return result;
  for (const project of projects) {
    if (!project.class_time || /取消|撤销/.test(project.status)) continue;
    const matches = project.class_time.matchAll(/(\d{4}-\d{1,2}-\d{1,2})\s*([^\s()-]+)-([^\s()-]+)\s*\((\d{1,2}:\d{2})-(\d{1,2}:\d{2})\)/g);
    for (const match of matches) {
      const parts = match[1].split('-').map(value => Number(value));
      const ordinal = Date.UTC(parts[0], parts[1] - 1, parts[2]);
      const week = Math.floor((ordinal - 28800000 - anchor) / 604800000) + 1;
      const day = new Date(ordinal).getUTCDay() || 7;
      const overlapping = periods.filter(period => minute(period.end) > minute(match[4]) &&
        minute(period.start) < minute(match[5]));
      const item: Course = {
        name: project.project_name || project.name, room: project.experimental_field_location ??
          project.experimental_field_name ?? '', teacher: project.teacher_name?.join('、') ?? '',
        day, weekStart: week, weekEnd: week, sectionStart: section(match[2]) || overlapping[0]?.number || 0,
        sectionEnd: section(match[3]) || overlapping[overlapping.length - 1]?.number || 0,
        startTime: match[4], endTime: match[5], timeMode: 'time', source: 'lab',
        note: project.name, seat: project.seat_number
      };
      result.push(item);
    }
  }
  return validCourses(result);
}

export async function importLab(credentials: LabCredentials, termStart: string, periods: Period[]): Promise<Course[]> {
  const payload: Record<string, string> = {
    'type': 'student', 'student_number': credentials.studentNumber, 'password': credentials.password,
    'captcha': credentials.captcha, 'captcha_key': credentials.captchaKey
  };
  const login = await labRequest<LoginResponse>('/login', JSON.stringify(payload));
  const token = login.access_token.startsWith('Bearer ') ? login.access_token : 'Bearer ' + login.access_token;
  const terms = await labRequest<Term[]>('/term_list', '{}', token);
  const active = terms.find(item => item.is_on === 1);
  if (!active) throw new Error('未获取到实验系统当前学期。');
  const projectQuery: Record<string, number> = { 'term_id': active.id, 'check_status': 0 };
  const projects = await labRequest<LabProject[]>('/student/experimental_projects_list', JSON.stringify(projectQuery), token);
  if (!Array.isArray(projects) || projects.length === 0) throw new Error('当前学期没有实验课安排。');
  const courses = parse(projects, termStart, periods);
  if (!courses.length) throw new Error('未找到可导入的实验课，请核对学期开始日期。');
  return courses;
}
