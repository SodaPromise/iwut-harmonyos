(function() {
if (!location.href.startsWith("https://jwxt.whut.edu.cn/jwapp/sys/homeapp/")) return;
function receive(raw) {
const msg = JSON.parse(raw);
if (!["courses","error"].includes(msg.type)) return;
try { window.__iwutAcademicResult = JSON.stringify(msg); }
catch (_) { window.__iwutAcademicResult = JSON.stringify({type:'error',message:'无法解析教务系统返回的数据'}); }
}
(async function() {
  var log = function(s){ receive(JSON.stringify({type:'debug', message:s})); };
  try {
    log('script started, url=' + location.href);
    await fetch(
      '/jwapp/sys/homeapp/api/home/changeAppRole.do?appRole=ef212c48c8f84be79acbd9d81b090f51',
      {method:'POST', credentials:'include', headers:{'Content-Type':'application/x-www-form-urlencoded'}}
    );
    log('changeAppRole ok');
    var ud = ((await (await fetch('/jwapp/sys/homeapp/api/home/currentUser.do', {
      method:'GET', credentials:'include', headers:{'Fetch-Api':'true'}
    })).json()).datas) || {};
    var xh = ud.userId || '';
    var term = (ud.welcomeInfo && ud.welcomeInfo.xnxqdm) || '';
    log('user=' + xh + ' term=' + term);
    if (!xh || !term) {
      receive(JSON.stringify({type:'error', code:'PAGE_DATA_MISSING', message:"当前教务会话未返回学号或学期，请重新登录后重试。"}));
      return;
    }
    var resp = await fetch('/jwapp/sys/kcbcxby/modules/xskcb/cxxskcb.do', {
      method:'POST', credentials:'include',
      headers:{
        'Content-Type':'application/x-www-form-urlencoded; charset=UTF-8',
        'X-Requested-With':'XMLHttpRequest',
        'Accept':'application/json, text/javascript, */*; q=0.01'
      },
      body:'XH=' + encodeURIComponent(xh) + '&XNXQDM=' + encodeURIComponent(term)
    });
    var text = await resp.text();
    log(text.substring(0, 2000));
    var data = JSON.parse(text);
    var rows = data.datas && data.datas.cxxskcb && data.datas.cxxskcb.rows;
    if (!rows || !rows.length) {
      receive(JSON.stringify({type:'error', code:'NO_TERM_DATA', message:"{term} 学期没有课表数据。".replace('{term}', term)}));
      return;
    }
    var courses = [];
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i], re = /1+/g, m;
      while ((m = re.exec(r.SKZC || '')) !== null) {
        courses.push({
          name: r.KCM || '', room: r.JASMC || '', teacher: r.SKJS || '',
          day: r.SKXQ, sectionStart: r.KSJC, sectionEnd: r.JSJC,
          weekStart: m.index + 1, weekEnd: m.index + m[0].length
        });
      }
    }
    var tp = term.split('-');
    var ljcResp = await fetch('/jwapp/sys/kcbcxby/modules/xskcb/cxxljc.do', {
      method:'POST', credentials:'include',
      headers:{
        'Content-Type':'application/x-www-form-urlencoded; charset=UTF-8',
        'X-Requested-With':'XMLHttpRequest'
      },
      body:'XN=' + encodeURIComponent(tp[0] + '-' + tp[1]) + '&XQ=' + encodeURIComponent(tp[2])
    });
    var ljcData = await ljcResp.json();
    log(JSON.stringify(ljcData));
    var ljcRows = ljcData.datas && ljcData.datas.cxxljc && ljcData.datas.cxxljc.rows;
    var termStart = (ljcRows && ljcRows[0] && ljcRows[0].XQKSRQ) ? ljcRows[0].XQKSRQ.split(' ')[0] : '';
    log('parsed ' + courses.length + ' courses');
    receive(JSON.stringify({type:'courses', data: courses, termStart: termStart}));
  } catch(e) {
    var networkFailure = e && e.name === 'TypeError' && e.message === 'Failed to fetch';
    receive(JSON.stringify({
      type:'error',
      code: networkFailure ? 'NETWORK_FAILURE' : 'SCRIPT_FAILURE',
      message: (e && e.message) ? String(e.message) : '',
      name: (e && e.name) ? String(e.name) : '',
      stack: (e && e.stack) ? String(e.stack).substring(0, 1000) : '',
      url: (typeof location !== 'undefined' && location.href) ? location.href : ''
    }));
  }
})(); true;
})();