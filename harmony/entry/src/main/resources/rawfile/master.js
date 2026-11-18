(function() {
if (!location.href.startsWith("https://yjsgl.whut.edu.cn/MainFrame.htm")) return;
function receive(raw) {
const msg = JSON.parse(raw);
if (!["masterRows","error"].includes(msg.type)) return;
try { window.__iwutAcademicResult = JSON.stringify(msg.type === 'masterRows' ? Object.assign({type:'masterRows'}, normalizeMasterRowsMessage(msg)) : msg); }
catch (_) { window.__iwutAcademicResult = JSON.stringify({type:'error',message:'无法解析教务系统返回的数据'}); }
}
const MAX_WEEK = 20;
const MAX_SECTION = 16;
function weeksToRanges(weeks) {
    const sorted = [...weeks].sort((a, b) => a - b);
    if (sorted.length === 0)
        return [];
    const ranges = [];
    let start = sorted[0];
    let end = sorted[0];
    for (let i = 1; i < sorted.length; i++) {
        if (sorted[i] === end + 1) {
            end = sorted[i];
        }
        else {
            ranges.push([start, end]);
            start = sorted[i];
            end = sorted[i];
        }
    }
    ranges.push([start, end]);
    return ranges;
}
/**
 * 返回 `weeks` 中与同 day 同节次段已有课程冲突的具体周次。
 * 节次相交判定与课程详情中的 conflict 逻辑一致。
 */
function findConflictWeeks(courses, day, sectionStart, sectionEnd, weeks) {
    const conflict = [];
    for (const w of weeks) {
        const hit = courses.some((c) => c.day === day &&
            c.weekStart <= w &&
            c.weekEnd >= w &&
            c.sectionStart <= sectionEnd &&
            c.sectionEnd >= sectionStart);
        if (hit)
            conflict.push(w);
    }
    return conflict;
}

function toInt(value) {
    const n = typeof value === "string" ? Number(value) : value;
    if (typeof n !== "number" || !Number.isInteger(n))
        return null;
    return n;
}
function toText(value) {
    return typeof value === "string" ? value.trim() : "";
}
/**
 * 校验并规范化一条来自 WebView 的导入课程数据，字段缺失或越界时返回 null。
 */
function parseImportedCourse(raw) {
    if (typeof raw !== "object" || raw === null)
        return null;
    const r = raw;
    const name = toText(r.name);
    if (!name)
        return null;
    const day = toInt(r.day);
    const sectionStart = toInt(r.sectionStart);
    const sectionEnd = toInt(r.sectionEnd);
    const weekStart = toInt(r.weekStart);
    const weekEnd = toInt(r.weekEnd);
    if (day == null || day < 1 || day > 7)
        return null;
    if (sectionStart == null ||
        sectionEnd == null ||
        sectionStart < 1 ||
        sectionEnd > MAX_SECTION ||
        sectionStart > sectionEnd) {
        return null;
    }
    if (weekStart == null ||
        weekEnd == null ||
        weekStart < 1 ||
        weekEnd > MAX_WEEK ||
        weekStart > weekEnd) {
        return null;
    }
    return {
        name,
        room: toText(r.room),
        teacher: toText(r.teacher),
        day,
        sectionStart,
        sectionEnd,
        weekStart,
        weekEnd,
        source: "imported",
    };
}

const MASTER_WEEKDAY_FIELDS = [
    { field: "Monday", day: 1 },
    { field: "Tuesday", day: 2 },
    { field: "Wednesday", day: 3 },
    { field: "Thursday", day: 4 },
    { field: "Friday", day: 5 },
    { field: "Saturday", day: 6 },
    { field: "Sunday", day: 7 },
];
const MASTER_SECTION_MAP = {
    1: 1,
    2: 2,
    3: 3,
    4: 4,
    5: 5,
    6: 8,
    7: 9,
    8: 10,
    9: 11,
    10: 12,
    11: 14,
    12: 15,
    13: 16,
};
function parseMasterSections(sectionText, fallback) {
    const source = `${sectionText} ${fallback}`;
    const nums = source.match(/\d+/g)?.map(Number) ?? [];
    const sections = nums
        .map((n) => MASTER_SECTION_MAP[n])
        .filter((n) => Number.isFinite(n));
    if (sections.length === 0)
        return null;
    return {
        sectionStart: sections[0],
        sectionEnd: sections[sections.length - 1],
    };
}
function parseMasterWeekSpans(weekText) {
    const text = weekText.replace(/^周次[:：]\s*/, "");
    const spans = [];
    const re = /(\d+)(?:\s*-\s*(\d+))?(?:\s*[（(](单周|双周)[）)])?/g;
    let match;
    while ((match = re.exec(text)) !== null) {
        const weekStart = Number(match[1]);
        const weekEnd = match[2] ? Number(match[2]) : weekStart;
        const parity = match[3];
        if (!Number.isFinite(weekStart) || !Number.isFinite(weekEnd))
            continue;
        if (parity === "单周" || parity === "双周") {
            const expected = parity === "单周" ? 1 : 0;
            for (let week = weekStart; week <= weekEnd; week++) {
                if (week % 2 === expected) {
                    spans.push({ weekStart: week, weekEnd: week });
                }
            }
        }
        else {
            spans.push({ weekStart, weekEnd });
        }
    }
    return spans;
}
function getMasterLineValue(lines, label) {
    const line = lines.find((item) => item.startsWith(label));
    return line?.slice(label.length).trim() ?? "";
}
function parseMasterCourseBlock(block, day, fallbackSections) {
    const lines = block
        .replace(/\r/g, "")
        .split("\n")
        .map((line) => line.trim())
        .filter(Boolean);
    const name = lines[0] ?? "";
    if (!name)
        return [];
    const isExam = name.startsWith("[考试]");
    const teacher = isExam ? "" : (lines[1] ?? "").split(/\s+/)[0];
    const sectionInfo = parseMasterSections(getMasterLineValue(lines, "节次:"), fallbackSections);
    const weeks = parseMasterWeekSpans(getMasterLineValue(lines, "周次:"));
    const room = getMasterLineValue(lines, "地点:");
    if (!sectionInfo || weeks.length === 0)
        return [];
    return weeks.map((week) => ({
        name,
        room,
        teacher,
        day,
        sectionStart: sectionInfo.sectionStart,
        sectionEnd: sectionInfo.sectionEnd,
        weekStart: week.weekStart,
        weekEnd: week.weekEnd,
    }));
}
function parseMasterCourseRows(rows) {
    const courses = rows.flatMap((row) => MASTER_WEEKDAY_FIELDS.flatMap(({ field, day }) => {
        const text = row[field]?.trim();
        if (!text)
            return [];
        return text
            .replace(/\r\n/g, "\n")
            .split(/\n\s*\n/)
            .flatMap((block) => parseMasterCourseBlock(block, day, row.JieCi ?? ""));
    }));
    return courses.sort((a, b) => {
        if (a.day !== b.day)
            return a.day - b.day;
        if (a.weekStart !== b.weekStart)
            return a.weekStart - b.weekStart;
        if (a.sectionStart !== b.sectionStart) {
            return a.sectionStart - b.sectionStart;
        }
        return a.name.localeCompare(b.name);
    });
}

const MASTER_LOGIN_URL = "https://zhlgd.whut.edu.cn/tpass/login?service=https%3a%2f%2fyjsgl.whut.edu.cn%2fcas%2fCasLogin.ashx%3fredirectUrl%3d";
const MASTER_MAIN_PREFIX = "https://yjsgl.whut.edu.cn/MainFrame.htm";
const MASTER_TIME_TABLE_API = "TimeTableNewService/GetTimeTableByStudent/{Year}/{Term}/{XH}?IsConti={IsConti}";
function jsString(s) {
    return JSON.stringify(s);
}
function buildMasterFetchScript(messages) {
    return `(async function() {
  var log = function(s){ receive(JSON.stringify({type:'debug', message:s})); };
  function post(payload) {
    receive(JSON.stringify(payload));
  }
  function waitForReady(timeout) {
    var started = Date.now();
    return new Promise(function(resolve, reject) {
      (function tick() {
        if (window.Global && Global.UserInfo && Global.UniversityInfo && window.jQueryHelper && jQueryHelper.Ajax) {
          resolve();
          return;
        }
        if (Date.now() - started > timeout) {
          var error = new Error(${jsString(messages.fetchUserFailed)});
          error.code = 'PAGE_READY_TIMEOUT';
          reject(error);
          return;
        }
        setTimeout(tick, 200);
      })();
    });
  }
  function formatDate(value) {
    var match = String(value || '').match(/\\/Date\\((\\d+)/);
    if (!match) return '';
    var date = new Date(parseInt(match[1], 10));
    var month = String(date.getMonth() + 1).padStart(2, '0');
    var day = String(date.getDate()).padStart(2, '0');
    return date.getFullYear() + '-' + month + '-' + day;
  }
  function fetchRows(xh, year, term) {
    return new Promise(function(resolve, reject) {
      var done = false;
      jQueryHelper.Ajax.Get(${jsString(MASTER_TIME_TABLE_API)}, {
        XH: xh,
        Year: year,
        Term: term,
        IsConti: 0
      }, function(data) {
        done = true;
        resolve(data);
      });
      setTimeout(function() {
        if (!done) {
          var error = new Error('Request timed out');
          error.code = 'NETWORK_TIMEOUT';
          reject(error);
        }
      }, 15000);
    });
  }
  try {
    await waitForReady(10000);
    var xh = Global.UserInfo && Global.UserInfo.UserID;
    var year = Global.UniversityInfo && Global.UniversityInfo.CurrentYear;
    var term = Global.UniversityInfo && Global.UniversityInfo.CurrentTerm;
    log('master user=' + xh + ' term=' + year + '-' + term);
    if (!xh || !year || !term) {
      post({type:'error', code:'PAGE_DATA_MISSING', message:${jsString(messages.fetchUserFailed)}});
      return;
    }
    var rows = await fetchRows(xh, year, term);
    post({
      type:'masterRows',
      data: Array.isArray(rows) ? rows : [],
      term: year + '-' + term,
      termStart: formatDate(Global.UniversityInfo.CurrentTermFrom)
    });
  } catch(e) {
    post({
      type:'error',
      code: (e && e.code) ? String(e.code) : 'SCRIPT_FAILURE',
      message: (e && e.message) ? String(e.message) : '',
      name: (e && e.name) ? String(e.name) : '',
      stack: (e && e.stack) ? String(e.stack).substring(0, 1000) : '',
      url: (typeof location !== 'undefined' && location.href) ? location.href : ''
    });
  }
})(); true;`;
}
function isMasterRowsMessage(msg) {
    return (typeof msg === "object" &&
        msg !== null &&
        "type" in msg &&
        msg.type === "masterRows");
}
function normalizeMasterRowsMessage(msg) {
    const rawRows = Array.isArray(msg.data) ? msg.data : [];
    const courses = parseMasterCourseRows(rawRows).map((course) => ({
        ...course,
        source: "imported",
    }));
    return {
        courses,
        term: msg.term ? String(msg.term) : "",
        termStart: msg.termStart ? String(msg.termStart) : "",
    };
}
(async function() {
  var log = function(s){ receive(JSON.stringify({type:'debug', message:s})); };
  function post(payload) {
    receive(JSON.stringify(payload));
  }
  function waitForReady(timeout) {
    var started = Date.now();
    return new Promise(function(resolve, reject) {
      (function tick() {
        if (window.Global && Global.UserInfo && Global.UniversityInfo && window.jQueryHelper && jQueryHelper.Ajax) {
          resolve();
          return;
        }
        if (Date.now() - started > timeout) {
          var error = new Error("当前教务会话未返回学号或学期，请重新登录后重试。");
          error.code = 'PAGE_READY_TIMEOUT';
          reject(error);
          return;
        }
        setTimeout(tick, 200);
      })();
    });
  }
  function formatDate(value) {
    var match = String(value || '').match(/\/Date\((\d+)/);
    if (!match) return '';
    var date = new Date(parseInt(match[1], 10));
    var month = String(date.getMonth() + 1).padStart(2, '0');
    var day = String(date.getDate()).padStart(2, '0');
    return date.getFullYear() + '-' + month + '-' + day;
  }
  function fetchRows(xh, year, term) {
    return new Promise(function(resolve, reject) {
      var done = false;
      jQueryHelper.Ajax.Get("TimeTableNewService/GetTimeTableByStudent/{Year}/{Term}/{XH}?IsConti={IsConti}", {
        XH: xh,
        Year: year,
        Term: term,
        IsConti: 0
      }, function(data) {
        done = true;
        resolve(data);
      });
      setTimeout(function() {
        if (!done) {
          var error = new Error('Request timed out');
          error.code = 'NETWORK_TIMEOUT';
          reject(error);
        }
      }, 15000);
    });
  }
  try {
    await waitForReady(10000);
    var xh = Global.UserInfo && Global.UserInfo.UserID;
    var year = Global.UniversityInfo && Global.UniversityInfo.CurrentYear;
    var term = Global.UniversityInfo && Global.UniversityInfo.CurrentTerm;
    log('master user=' + xh + ' term=' + year + '-' + term);
    if (!xh || !year || !term) {
      post({type:'error', code:'PAGE_DATA_MISSING', message:"当前教务会话未返回学号或学期，请重新登录后重试。"});
      return;
    }
    var rows = await fetchRows(xh, year, term);
    post({
      type:'masterRows',
      data: Array.isArray(rows) ? rows : [],
      term: year + '-' + term,
      termStart: formatDate(Global.UniversityInfo.CurrentTermFrom)
    });
  } catch(e) {
    post({
      type:'error',
      code: (e && e.code) ? String(e.code) : 'SCRIPT_FAILURE',
      message: (e && e.message) ? String(e.message) : '',
      name: (e && e.name) ? String(e.name) : '',
      stack: (e && e.stack) ? String(e.stack).substring(0, 1000) : '',
      url: (typeof location !== 'undefined' && location.href) ? location.href : ''
    });
  }
})(); true;
})();