(function() {
if (!location.href.startsWith("https://talent.whut.edu.cn/")) return;
function receive(raw) {
const msg = JSON.parse(raw);
if (!["info","profileUnavailable","bindingFailed"].includes(msg.type)) return;
try { window.__iwutAcademicResult = JSON.stringify(msg); }
catch (_) { window.__iwutAcademicResult = JSON.stringify({type:'error',message:'无法解析教务系统返回的数据'}); }
}
(function(){
  if(window.__talentBindInitialized)return;
  var isLogin=location.hostname==='zhlgd.whut.edu.cn' && location.pathname==='/tpass/login';
  if(!isLogin && location.hostname!=='talent.whut.edu.cn')return;
  window.__talentBindInitialized=true;
  var fetching=false;
  function send(type,data){
    receive(JSON.stringify(Object.assign({type:type},data)));
  }
  function valueType(value){
    if(value===null)return 'null';
    if(Array.isArray(value))return 'array';
    return typeof value;
  }
  function diagnostic(endpoint,kind,statusCode,reason,response){
    var message={
      endpoint:endpoint,kind:kind,
      statusCode:statusCode,attempt:window.__talentTries
    };
    if(reason){
      message.reason=reason;
      message.responseType=valueType(response);
      if(isRecord(response)){
        if(typeof response.code==='number')message.code=response.code;
        if(typeof response.status==='boolean')message.status=response.status;
        message.dataType=valueType(response.data);
        if(isRecord(response.data)){
          message.expandFieldType=valueType(response.data.expandField);
        }
      }
    }
    send('diagnostic',message);
  }
  function isRecord(value){
    return value!==null && typeof value==='object' && !Array.isArray(value);
  }
  function isDictionary(value){
    return Array.isArray(value) && value.every(isRecord);
  }
  function getJson(endpoint,url){
    return fetch(url,{credentials:'include',headers:{accept:'application/json'}})
      .then(function(response){
        if(!response.ok){
          diagnostic(endpoint,'http',response.status);
          throw new Error('http');
        }
        return response.json().catch(function(){
          diagnostic(endpoint,'invalid-json',response.status);
          throw new Error('invalid-json');
        });
      },function(){
        diagnostic(endpoint,'network');
        throw new Error('network');
      });
  }
  function getDictionary(endpoint,url){
    return getJson(endpoint,url).then(function(value){
      var data=isRecord(value)?value.data:value;
      if((isRecord(value) && value.code!==undefined && value.code!==0) ||
        !isDictionary(data)){
        diagnostic(endpoint,'invalid-response');
        return null;
      }
      return data;
    }).catch(function(){return null;});
  }
  function ensureAppEntry(){
    if(location.hostname!=='talent.whut.edu.cn')return false;
    if(location.pathname.indexOf('/information-center/center/')===0)return false;
    if(window.__talentRedirected)return false;
    window.__talentRedirected=true;
    try{location.replace('/information-center/center/index.html?appId=2');}catch(_){location.href='/information-center/center/index.html?appId=2';}
    return true;
  }
  function fetchTalentInfo(){
    if(location.hostname!=='talent.whut.edu.cn')return;
    if(window.__talentInfoSent || fetching)return;
    fetching=true;
    function finish(type,data){
      if(window.__talentInfoSent)return;
      window.__talentInfoSent=true;
      send(type,data);
    }
    window.__talentTries=(window.__talentTries||0)+1;
    var giveUp=window.__talentTries>=8;
    function retry(){
      if(giveUp){
        finish('profileUnavailable',{identityUnavailable:true});
        return;
      }
      setTimeout(fetchTalentInfo,1000);
    }
    function pick(arr,code){
      var field=(arr||[]).find(function(item){return item.fieldCode===code;});
      return field?String(field.fieldValue==null?'':field.fieldValue):'';
    }
    function lookupName(rows,key,code){
      if(!code)return '';
      var row=(rows||[]).find(function(item){return item[key]===code;});
      return row?row.name||'':'';
    }
    getJson('loginUser','/information-center/xd/user/getLoginUserNew/2').then(function(u){
      if(u&&u.code===50005){finish('profileUnavailable');return;}
      if(!isRecord(u)||u.code!==0||!isRecord(u.data)||!u.data.sn){
        diagnostic('loginUser','invalid-response');retry();return;
      }
      var sn=String(u.data.sn);
      var name=u.data.name||'';
      function retryStudent(reason,stu,onlyFinal){
        if(stu!==undefined && (!onlyFinal || giveUp)){
          diagnostic('studentInfo','invalid-response',undefined,reason,stu);
        }
        if(giveUp){
          // 资料异常时只保留已验证的身份
          finish('info',{name:name,studentId:sn,cardId:'',college:'',eduLevel:''});
          return;
        }
        retry();
      }
      return Promise.all([
        getJson('studentInfo','/information-center/xd/user/findStudentInfoWechat/'+encodeURIComponent(sn)).catch(function(){return undefined;}),
        getDictionary('colleges','/information-center/xd/commons/getColleges'),
        getDictionary('education','/information-center/xd/commons/getDictionByName/'+encodeURIComponent('\u5b66\u751f\u7c7b\u578b'))
      ]).then(function(rs){
        var stu=rs[0];
        if(stu&&stu.code===50005){finish('profileUnavailable');return;}
        if(isRecord(stu) && stu.code===50000 && stu.status===false &&
          stu.data===null && stu.message==='\u767b\u5f55\u8d85\u65f6'){
          retryStudent('session-timeout',stu,true);return;
        }
        if(!isRecord(stu)||stu.status!==true||!isRecord(stu.data)||stu.code!==0){
          retryStudent('student-response',stu);return;
        }
        var expandField=stu.data.expandField;
        if(expandField!==null && expandField!==undefined &&
          !isRecord(expandField)){
          retryStudent('expand-field',stu);return;
        }
        var cardId='',college='',eduLevel='';
        try{
          // 接口成功但没有扩展资料时，仍可用已验证的身份信息完成绑定
          var ef=expandField||{};
          if(['\u5b66\u7c4d\u4fe1\u606f','\u57fa\u672c\u4fe1\u606f'].some(function(key){
            return ef[key]!==undefined && !isDictionary(ef[key]);
          })){
            retryStudent('student-fields',stu);return;
          }
          var xj=ef['\u5b66\u7c4d\u4fe1\u606f']||[];
          cardId=pick(ef['\u57fa\u672c\u4fe1\u606f'],'card_no');
          eduLevel=lookupName(rs[2],'code',pick(xj,'education_code'));
          college=lookupName(rs[1],'sn',pick(xj,'college_code'));
        }catch(e){retryStudent('student-parsing',stu);return;}
        finish('info',{
          name:name,
          studentId:sn,
          cardId:cardId,
          college:college,
          eduLevel:eduLevel
        });
      });
    }).catch(function(){retry();}).finally(function(){fetching=false;});
  }

  if(isLogin)return;else if(!ensureAppEntry()){
    fetchTalentInfo();
  }
})();true;
})();