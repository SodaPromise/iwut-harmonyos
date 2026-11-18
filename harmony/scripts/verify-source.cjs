const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '..');
const raw = path.join(root, 'entry/src/main/resources/rawfile');
const files = fs.readdirSync(raw);
const read = (name) => fs.readFileSync(path.join(root, name), 'utf8');
const resource = (name) => JSON.parse(fs.readFileSync(path.join(raw, name), 'utf8'));

function evaluate(file, replacements) {
  const output = ts.transpileModule(read(file), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
  }).outputText;
  const exports = {};
  vm.runInNewContext(output, {
    exports,
    require: (name) => {
      if (name in replacements) return replacements[name];
      throw new Error('Unexpected import ' + name);
    }
  }, { filename: file, timeout: 1000 });
  return exports;
}

async function main() {
  const index = read('entry/src/main/ets/pages/Index.ets');
  const tabs = /\bprivate tabs: string\[\] = \[(.*?)\]/.exec(index)[1].match(/nav\.\w+/g);
  assert.deepEqual(tabs, ['nav.home', 'nav.course', 'nav.function', 'nav.user']);
  assert.deepEqual(resource('functions.json').map(group => group.titleKey),
    ['fn.section.study', 'fn.section.life', 'fn.section.info']);
  const model = evaluate('entry/src/main/ets/model/Iwut.ets', {
    '@kit.AbilityKit': {}, '@kit.ArkData': {}, '@kit.ArkTS': {}, '@kit.LocalizationKit': {}
  });
  const course = {
    name: '高等数学', day: 1, sectionStart: 1, sectionEnd: 2, weekStart: 1, weekEnd: 12,
    room: '教学楼', teacher: '教师'
  };
  assert.equal(model.validCourses([course, course, { ...course, day: 8 }, { ...course, weekStart: 20 }]).length, 1);
  assert.equal(model.currentWeek('2026-09-07', new Date(2026, 8, 14)), 2);
  const periods = [5, 8, 9, 10].map(number => ({ number, start: '', end: '' }));
  const spanning = { ...course, sectionStart: 5, sectionEnd: 9 };
  const following = { ...course, sectionStart: 10, sectionEnd: 10 };
  const otherWeek = { ...course, sectionStart: 8, sectionEnd: 8, weekStart: 2 };
  const blocks = model.timetableBlocks([otherWeek, spanning, following], periods, 1, 1, true);
  assert.equal(blocks.length, 2);
  assert.equal(blocks[0].course, spanning);
  assert.equal(blocks[0].rowCount, 3);
  assert.equal(blocks[0].overlapCount, 1);
  assert.equal(blocks[1].course, following);
  assert.equal(blocks[1].firstRow, 3);
  assert.equal(model.timetableBlocks([spanning, otherWeek], periods, 1, 1, false)[0].overlapCount, 0);
  const compactPeriods = resource('periods.json').filter(period => ![6, 7, 13].includes(period.number));
  const emptySlots = model.timetableBlocks([], compactPeriods, 1, 1, true);
  assert.deepEqual(Array.from(emptySlots, slot => slot.rowCount), [2, 3, 3, 2, 3]);
  const data = new model.Data();
  data.settings.courseReminder = true;
  const zh = resource('zh.json');
  const greetings = [
    [4, 'LateNight'], [5, 'EarlyMorning'], [8, 'Morning'], [11, 'Noon'],
    [13, 'Afternoon'], [17, 'Evening'], [19, 'Night'], [23, 'LateNight']
  ];
  for (const [hour, greeting] of greetings) {
    assert.equal(model.homeGreetingKey(hour), 'home.greet' + greeting);
    assert.ok(zh[model.homeGreetingKey(hour) + 'Sub']);
  }
  assert.equal(zh[model.homeGreetingKey(15) + 'Sub'], '继续加油');
  const date = model.campusDay('2026-09-07', Date.parse('2026-11-17T17:00:00Z'));
  assert.equal(zh['home.weekContext']
    .replace('{week}', date.week).replace('{weekday}', ['周一', '周二', '周三'][date.weekday - 1])
    .replace('{m}', date.month).replace('{d}', date.day), '第 11 周 · 周三 · 11月18日');
  const now = Date.parse('2026-09-13T06:00:00Z');
  const imported = model.validCourses([
    { ...course, day: 7, weekStart: 1, weekEnd: 1 },
    { ...course, day: 1, weekStart: 2, weekEnd: 2 },
    { ...course, day: 1, weekStart: 2, weekEnd: 2, sectionStart: 3, sectionEnd: 3 }
  ]);
  assert.equal(model.coursesForCampusDay(imported, model.campusDay('2026-09-07', now)).length, 1);
  const tomorrow = model.campusDay('2026-09-07', now, true);
  assert.equal(tomorrow.week, 2);
  assert.equal(model.coursesForCampusDay(imported, tomorrow).length, 2);
  assert.equal(model.coursesForCampusDay(imported, model.campusDay('2026-11-01', now)).length, 0);
  const lesson = { ...course, sectionStart: 3, sectionEnd: 5 };
  const timing = (time, scheduled = lesson) =>
    model.homeCourseTiming(scheduled, resource('periods.json'), Date.parse('2026-11-18T' + time + ':00+08:00'));
  assert.equal(timing('09:40').countdown, 'start');
  assert.equal(timing('10:00').countdown, 'end');
  assert.equal(timing('12:20').finished, false);
  assert.equal(timing('12:21').finished, true);
  assert.equal(timing('12:21', { ...lesson, startTime: '10:00', endTime: '12:30' }).finished, false);
  assert.equal(timing('12:21', { ...lesson, endTime: 'invalid' }).finished, true);
  const menu = evaluate('entry/src/main/ets/model/SettingsMenus.ets', {
    './Iwut': model,
    '../components/Menu': {
      MenuGroup: class { constructor(title, rows) { this.title = title; this.rows = rows; } },
      MenuRow: class { constructor(id) { this.id = id; } }
    }
  });
  const order = (page) => JSON.parse(JSON.stringify(menu.settingsMenu(page, data, key => key)
    .map(group => group.rows.map(row => row.id))));
  assert.deepEqual(order('general'), [
    ['haptic', 'openCourseOnLaunch'], ['courseReminder', 'reminderMinutes', 'examReminder', 'courseDnd'],
    ['telemetry'], ['clearCache', 'exportLogs']
  ]);
  assert.deepEqual(order('calendar'), [
    ['manage'], ['academicSync', 'export', 'import'], ['scrollWeekend', 'showMidday', 'showOtherWeek'],
    ['syncCalendar'], ['palette', 'visual']
  ]);
  for (const file of files.filter(file => file.endsWith('.js'))) {
    new vm.Script(fs.readFileSync(path.join(raw, file), 'utf8'), { filename: file });
  }
  const binding = fs.readFileSync(path.join(raw, 'bind.js'), 'utf8');
  assert.doesNotMatch(binding, /send\(['"]credentials|querySelector\(['"]#pd/);
  const bindRoute = resource('academic.json').find(route => route.kind === 'bind');
  const bindModel = evaluate('entry/src/main/ets/model/AcademicBinding.ets', {});
  assert.equal(new URL(bindRoute.url).searchParams.get('service'), bindModel.BIND_PROFILE_ROOT);
  assert.equal(bindModel.bindingHttpsRedirect('http://zhlgd.whut.edu.cn/tpass/login?service=example'),
    'https://zhlgd.whut.edu.cn/tpass/login?service=example');
  assert.equal(bindModel.bindingHttpsRedirect('http://talent.whut.edu.cn/?ticket=sample'),
    'https://talent.whut.edu.cn/?ticket=sample');
  assert.equal(bindModel.bindingHttpsRedirect('http://talent.whut.edu.cn.example.org/'), '');
  assert.equal(bindModel.bindingHttpsRedirect('http://zhlgd.whut.edu.cn@example.org/tpass/login'), '');
  const rpc = fs.readFileSync(path.join(raw, 'rpc.js'), 'utf8').trim();
  const target = 'https://classroom-iwut.tokenteam.net';
  const packets = [];
  const frame = { rpcClient: { onReceive: response => packets.push(response) } };
  frame.top = frame;
  const command = rpc + '(' + JSON.stringify(target) + ',{"hasProfile":true,"name":"测试"},{"osType":"HarmonyOS"});';
  vm.runInNewContext(command, { window: frame, location: { origin: 'https://unrelated.example' } });
  assert.equal(frame.bridge, undefined);
  vm.runInNewContext(command, { window: frame, location: { origin: target } });
  frame.bridge.postMessage(JSON.stringify({ service: 'student', method: 'profile' }));
  frame.bridge.postMessage(JSON.stringify({ service: 'spider', method: 'run' }));
  await Promise.resolve();
  assert.equal(packets[0].data.name, '测试');
  assert.equal(packets[1].code, 1003);
  console.log('PASS: tabs, menus, timetable spans, home schedule and course timing, course validation, login script and origin-scoped mini-app protocol');
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
