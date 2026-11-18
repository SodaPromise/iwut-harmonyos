// Regenerates HarmonyOS resources from the checked-out upstream source.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../..');
const raw = path.join(root, 'harmony/entry/src/main/resources/rawfile');
const cache = new Map();
fs.mkdirSync(raw, { recursive: true });
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const compile = (source) => ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText;

function load(file) {
  if (cache.has(file)) return cache.get(file);
  const exports = {};
  cache.set(file, exports);
  const resolve = (name) => {
    const local = name.startsWith('@/') ? name.slice(2)
      : name.startsWith('.') ? path.posix.join(path.posix.dirname(file), name) : null;
    if (local === null) throw new Error('Unexpected import ' + name);
    return load(local + '.ts');
  };
  vm.runInNewContext(compile(read(file)), { exports, require: resolve }, { filename: file, timeout: 1000 });
  return exports;
}

function write(file, data) {
  fs.writeFileSync(path.join(raw, file), typeof data === 'string' ? data : JSON.stringify(data));
}

function flatten(object, prefix = '') {
  return Object.fromEntries(Object.entries(object).flatMap(([key, value]) =>
    typeof value === 'string' ? [[prefix + key, value]]
      : Object.entries(flatten(value, prefix + key + '.'))));
}
for (const lang of ['zh', 'en']) write(lang + '.json', flatten(JSON.parse(read('lib/i18n/locales/' + lang + '.json'))));
write('functions.json', load('lib/functions/sections.ts').SECTIONS);
write('palettes.json', load('constants/course-palettes.ts').BUILTIN_PALETTES);
write('periods.json', Object.values(load('services/course-time.ts').SECTION_TIMES).map((time, index) =>
  ({ number: index + 1, start: time[0], end: time[1] })));

const messages = {
  fetchUserFailed: '当前教务会话未返回学号或学期，请重新登录后重试。',
  noTermData: '{term} 学期没有课表数据。',
  importTimeout: '请求超时，请重新尝试。',
  fetchFailed: '成绩查询失败。',
  queryTimeout: '成绩查询超时。',
};
const bachelor = load('services/course-import/bachelor-import.ts');
const master = load('services/course-import/master-import.ts');
const grade = load('services/grade-import.ts');
const exam = load('services/exam-import.ts');
const talent = 'https://talent.whut.edu.cn/';

// Reuse the authenticated profile query. The official login and MFA page stays unmodified.
const bindSrc = read('app/browser/bind.tsx');
const delimiter = String.fromCharCode(96);
const bindStart = bindSrc.indexOf('const INJECTED_JS = ' + delimiter);
const start = bindSrc.indexOf(delimiter, bindStart) + 1;
const end = bindSrc.indexOf(delimiter + ';', start);
if (bindStart < 0 || end < start) throw new Error('Upstream binding script changed');
const bind = bindSrc.slice(start, end).replace(/\r\n/g, '\n')
  .replace(/\n  function simplifyLogin\(\)\{[\s\S]*?(?=\n  function ensureAppEntry)/, '')
  .replace(/\n  if\(isLogin\)\{[\s\S]*?\n  \}(?=\s*(?:if|else|\}))/,
    '\n  if(isLogin)return;')
  .replaceAll('$' + '{TALENT_APP_PATH}', '/information-center/center/index.html?appId=2');
if (/\btrack\(|simplifyLogin|send\('credentials'/.test(bind)) throw new Error('Login instrumentation must be excluded');

function wrap(body, prefix, kinds, normalized = 'msg') {
  const script = [
    '(function() {',
    'if (!location.href.startsWith(' + JSON.stringify(prefix) + ')) return;',
    'function receive(raw) {',
    'const msg = JSON.parse(raw);',
    'if (!' + JSON.stringify(kinds) + '.includes(msg.type)) return;',
    'try { window.__iwutAcademicResult = JSON.stringify(' + normalized + '); }',
    "catch (_) { window.__iwutAcademicResult = JSON.stringify({type:'error',message:'无法解析教务系统返回的数据'}); }",
    '}',
    body.replaceAll('window.ReactNativeWebView.postMessage', 'receive'),
    '})();',
  ].join('\n');
  new vm.Script(script);
  return script;
}

function helpers(...files) {
  return files.map((file) => compile(read(file).replace(/^import[\s\S]*?from "[^"]+";\r?\n/gm, '')
    .replace(/^export /gm, ''))).join('\n');
}

const sources = [
  { kind: 'bind', url: 'https://zhlgd.whut.edu.cn/tpass/login?service=' + encodeURIComponent(talent), prefix: talent,
    body: bind, types: ['info', 'profileUnavailable', 'bindingFailed'] },
  { kind: 'bachelor', url: bachelor.BACHELOR_LOGIN_URL, prefix: bachelor.BACHELOR_HOME_PREFIX,
    body: bachelor.buildBachelorFetchScript(messages), types: ['courses', 'error'] },
  { kind: 'master', url: master.MASTER_LOGIN_URL, prefix: master.MASTER_MAIN_PREFIX,
    body: helpers('lib/course-weeks.ts', 'services/course-import/normalize.ts',
      'services/course-import/master-parser.ts', 'services/course-import/master-import.ts') + master.buildMasterFetchScript(messages),
    types: ['masterRows', 'error'],
    normalized: "msg.type === 'masterRows' ? Object.assign({type:'masterRows'}, normalizeMasterRowsMessage(msg)) : msg" },
  { kind: 'grade', url: grade.GRADE_LOGIN_URL, prefix: grade.GRADE_APP_PREFIX,
    body: helpers('services/grade-import.ts') + grade.buildGradeFetchScript(messages), types: ['gradeRows', 'error'],
    normalized: "msg.type === 'gradeRows' ? {type:'gradeRows', grades:normalizeGradeRowsMessage(msg)} : msg" },
  { kind: 'exam', url: exam.EXAM_LOGIN_URL, prefix: exam.EXAM_APP_PREFIX,
    body: helpers('services/exam-import.ts') + exam.buildExamFetchScript(messages), types: ['examRows', 'error'],
    normalized: "msg.type === 'examRows' ? Object.assign({type:'examRows'}, normalizeExamRowsMessage(msg)) : msg" },
];
for (const source of sources) write(source.kind + '.js',
  wrap(source.body, source.prefix, source.types, source.normalized));
write('academic.json', sources.map(({ kind, url, prefix }) => ({ kind, url, prefix })));
for (const file of ['PRIVACY_POLICY', 'USER_AGREEMENT']) {
  write(file + '.md', read('docs/legal/' + file + '.zh-CN.md'));
}
