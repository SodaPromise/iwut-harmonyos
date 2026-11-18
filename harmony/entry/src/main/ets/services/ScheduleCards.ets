import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { formBindingData, formProvider } from '@kit.FormKit';
import { Data, LocalData, UpstreamResources, courseTime, currentWeek } from '../model/Iwut';

class CardPayload {
  caption: string = '今日课程';
  courseOne: string = '今日没有课程';
  detailOne: string = '';
  courseTwo: string = '';
  detailTwo: string = '';
}

function idStorage(context: common.Context): preferences.Preferences {
  return preferences.getPreferencesSync(context, { name: 'iwut-card-ids' });
}

export function cardIds(context: common.Context): string[] {
  const stored = idStorage(context).getSync('ids', '[]') as string;
  const ids = JSON.parse(stored) as string[];
  return Array.isArray(ids) ? ids : [];
}

export function registerCard(context: common.Context, id: string, add: boolean): void {
  const storage = idStorage(context);
  const remaining = cardIds(context).filter(value => value !== id);
  storage.putSync('ids', JSON.stringify(add ? remaining.concat(id) : remaining));
  storage.flush().catch(() => {});
}

export function cardData(context: common.Context, supplied?: Data): formBindingData.FormBindingData {
  const payload = new CardPayload();
  try {
    const data = supplied ?? new LocalData(context).read();
    const resources = new UpstreamResources(context);
    const today = new Date();
    const week = currentWeek(data.termStart, today);
    const day = today.getDay() || 7;
    const active = data.courses.filter(course => course.day === day
      && course.weekStart <= week && course.weekEnd >= week)
      .sort((a, b) => a.sectionStart - b.sectionStart);
    payload.caption = resources.t('home.tabToday', data.settings.language) + ' · ' +
      resources.t('common.weekN', data.settings.language).replace('{n}', week.toString());
    payload.courseOne = resources.t(data.courses.length ? 'home.emptyTodayNone' : 'home.emptyNoCourses',
      data.settings.language);
    if (active.length > 0) {
      payload.courseOne = active[0].name;
      payload.detailOne = courseTime(active[0], resources.periods) + '  ' + active[0].room;
    }
    if (active.length > 1) {
      payload.courseTwo = active[1].name;
      payload.detailTwo = courseTime(active[1], resources.periods) + '  ' + active[1].room;
    }
  } catch (_) {
    payload.courseOne = '打开掌上吾理加载课表';
  }
  return formBindingData.createFormBindingData(JSON.stringify(payload));
}

export function updateScheduleCards(context: common.Context, data: Data): void {
  try {
    const ids = cardIds(context);
    if (!ids.length) return;
    const binding = cardData(context, data);
    ids.forEach(id => { formProvider.updateForm(id, binding).catch(() => {}); });
  } catch (_) {}
}
