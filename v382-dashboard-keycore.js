/* KeySuite V3.8.2 R2 — forward-compatible Dashboard Duty Finder + KeyCore full-screen hubs */
(function(){
'use strict';
if(window.top!==window.self)return;
if(window.__KEYSUITE_V382_EXTENSION__)return;
window.__KEYSUITE_V382_EXTENSION__=true;

var STYLE_ID='ks-v382-extension-style';
function addStyles(){
 if(document.getElementById(STYLE_ID))return;
 var st=document.createElement('style');st.id=STYLE_ID;st.textContent=`
 body.ks-keycore-active #appView.app,body.ks-keycore-active .app{grid-template-columns:1fr!important}
 body.ks-keycore-active #appView>aside,body.ks-keycore-active .app>aside{display:none!important}
 body.ks-keycore-active #appView>main,body.ks-keycore-active .app>main{padding:0!important;max-width:none!important;width:100%!important}
 body.ks-keycore-active .page.active{min-height:100vh!important;border-radius:0!important;margin:0!important;max-width:none!important}
 #ksDashboardDutyFinder{margin-top:16px;position:relative;overflow:hidden}
 .ks-duty-head{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap}
 .ks-duty-head h2{margin:0}.ks-duty-inputs{display:grid;grid-template-columns:minmax(150px,220px) minmax(150px,220px) auto;gap:10px;align-items:end;margin-top:12px}
 .ks-duty-inputs label{margin:0}.ks-duty-inputs .ks-unit{font-size:11px;color:#64748b;font-weight:600;margin-top:4px}
 .ks-duty-products{display:flex;gap:9px;flex-wrap:wrap;margin-top:14px}.ks-duty-family{border:1px solid #b9cadd;background:#f7fbff;color:#17365d;border-radius:9px;padding:9px 14px;font-weight:800;cursor:pointer}
 .ks-duty-family.active{background:#17365d;color:#fff;border-color:#17365d}.ks-duty-family-body{display:none;margin-top:10px;border:1px solid #dbe4ed;border-radius:10px;padding:10px;background:#fbfdff}.ks-duty-family-body.active{display:block}
 .ks-duty-model{border:1px solid #2f75b5;background:#fff;color:#17365d;border-radius:8px;padding:9px 14px;font-weight:800;cursor:pointer}.ks-duty-model.active{background:#eef6ff}
 .ks-duty-info{display:none;margin-top:10px}.ks-duty-info.active{display:grid;grid-template-columns:repeat(4,minmax(120px,1fr));gap:8px}.ks-duty-kpi{border:1px solid #dbe4ed;border-radius:8px;background:#fff;padding:9px}.ks-duty-kpi span{display:block;font-size:10px;color:#64748b;text-transform:uppercase;font-weight:700}.ks-duty-kpi b{display:block;margin-top:3px;font-size:15px}
 .ks-duty-status{font-size:12px;color:#64748b;margin-top:10px}.ks-duty-empty{font-size:12px;color:#7a5a18;background:#fff8e7;border:1px solid #ecd495;padding:9px;border-radius:7px;margin-top:10px}
 .ks-hidden-selector{position:fixed!important;width:1px!important;height:1px!important;left:-9999px!important;top:-9999px!important;opacity:0!important;pointer-events:none!important;border:0!important}
 .ks-hub-overlay{position:fixed;inset:0;z-index:100000;background:radial-gradient(circle at 50% 38%,#102e4c 0,#071525 48%,#030811 100%);color:#fff;overflow:auto;padding:26px;display:none}.ks-hub-overlay.open{display:block}
 .ks-hub-top{display:flex;align-items:center;justify-content:space-between;gap:12px;max-width:1200px;margin:0 auto 24px}.ks-hub-top h1{margin:0;color:#fff}.ks-hub-close{border:1px solid #7994ab;background:#0d2235;color:#fff;border-radius:9px;padding:9px 14px;cursor:pointer}
 .ks-hub-grid{max-width:1200px;margin:0 auto;display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:16px}.ks-hub-card{min-height:145px;border:1px solid rgba(126,190,230,.42);border-radius:18px;background:radial-gradient(circle at 50% 38%,rgba(64,157,218,.28),rgba(9,33,53,.72));color:#fff;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;padding:18px;cursor:pointer;box-shadow:0 0 28px rgba(48,144,205,.12)}.ks-hub-card:hover{transform:translateY(-2px);border-color:#7fc7f3;box-shadow:0 0 36px rgba(48,144,205,.28)}.ks-hub-card b{font-size:18px}.ks-hub-card small{color:#aec6d8;text-align:center}
 @media(max-width:800px){.ks-duty-inputs{grid-template-columns:1fr 1fr}.ks-duty-inputs button{grid-column:1/-1}.ks-duty-info.active{grid-template-columns:1fr 1fr}.ks-hub-overlay{padding:16px}}
 `;document.head.appendChild(st);
}

function visible(el){if(!el)return false;var cs=getComputedStyle(el);return cs.display!=='none'&&cs.visibility!=='hidden'&&el.getClientRects().length>0}
function activePage(){return document.querySelector('.page.active')||Array.from(document.querySelectorAll('section[id],main>div[id]')).find(visible)||null}
function isKeyCorePage(el){if(!el)return false;var id=(el.id||'')+' '+(el.className||'');if(/key\s*core|keycore/i.test(id))return true;var h=el.querySelector&&el.querySelector('h1,h2,[data-title]');return !!(h&&/^\s*KeyCore\b/i.test(h.textContent||''))}
function syncKeyCoreMode(){var p=activePage();document.body.classList.toggle('ks-keycore-active',isKeyCorePage(p))}

function clickPage(page,label){var btn=document.querySelector('nav button[data-page="'+page+'"]')||document.querySelector('button[data-page="'+page+'"]');if(btn){btn.click();return true}var candidates=Array.from(document.querySelectorAll('nav button,aside button,[data-page]'));btn=candidates.find(function(x){return new RegExp('^'+label+'$','i').test((x.textContent||'').trim())});if(btn){btn.click();return true}return false}

var productItems=[
 ['CHC','productChc','Vertical Multistage Pump'],['ES','productEs','End Suction Pump'],['Motor','productMotor','Electric Motor'],['Coupling','productCoupling','Pump Coupling'],['Control Panel','productKeyplc','KeyPLC Control Panel'],['GWS Tank','productGws','Pressure Tank'],['Manifold','productManifold','Pump Manifold']
];
var curveItems=[['CHC','selector','CHC Pump Curve / Selection'],['ES','selectorEs','End Suction Pump Curve / Selection']];
function ensureHub(){var hub=document.getElementById('ksV382Hub');if(hub)return hub;hub=document.createElement('div');hub.id='ksV382Hub';hub.className='ks-hub-overlay';hub.innerHTML='<div class="ks-hub-top"><div><h1 id="ksHubTitle">Product</h1><div id="ksHubSub" style="color:#aec6d8;margin-top:5px"></div></div><button class="ks-hub-close" type="button">Back to KeyCore</button></div><div id="ksHubGrid" class="ks-hub-grid"></div>';document.body.appendChild(hub);hub.querySelector('.ks-hub-close').onclick=function(){hub.classList.remove('open')};return hub}
function openHub(kind){var hub=ensureHub(),items=kind==='curve'?curveItems:productItems,title=kind==='curve'?'Pump Curve':'Product';hub.querySelector('#ksHubTitle').textContent=title;hub.querySelector('#ksHubSub').textContent=kind==='curve'?'Choose a pump family to open its curve/selection page.':'Choose a product category. CHC is no longer opened automatically.';var grid=hub.querySelector('#ksHubGrid');grid.innerHTML=items.map(function(x){return '<button class="ks-hub-card" type="button" data-page="'+x[1]+'" data-label="'+x[0]+'"><b>'+x[0]+'</b><small>'+x[2]+'</small></button>'}).join('');grid.querySelectorAll('.ks-hub-card').forEach(function(b){b.onclick=function(){hub.classList.remove('open');clickPage(b.dataset.page,b.dataset.label);setTimeout(syncKeyCoreMode,30)}});hub.classList.add('open')}

document.addEventListener('click',function(e){if(!document.body.classList.contains('ks-keycore-active'))return;var b=e.target.closest('button,a,[role="button"],[data-action]');if(!b||b.closest('#ksV382Hub'))return;var txt=(b.textContent||'').replace(/\s+/g,' ').trim();if(/^Product$/i.test(txt)){e.preventDefault();e.stopImmediatePropagation();openHub('product');return}if(/^Pump\s*Curve$/i.test(txt)||/^Curve$/i.test(txt)){e.preventDefault();e.stopImmediatePropagation();openHub('curve')}},true);

var dutyState={requestId:0,results:{},timer:null,frames:{},loaded:{},pending:null};
function dashboard(){return document.getElementById('dashboard')||document.querySelector('[data-page-name="dashboard"]')}
function ensureFrame(family,src){if(dutyState.frames[family])return dutyState.frames[family];var f=document.createElement('iframe');f.className='ks-hidden-selector';f.setAttribute('aria-hidden','true');f.tabIndex=-1;f.src=src;f.onload=function(){dutyState.loaded[family]=true;if(dutyState.pending)sendDutyTo(family,dutyState.pending)};document.body.appendChild(f);dutyState.frames[family]=f;return f}
function sendDutyTo(family,req){var f=dutyState.frames[family];if(f&&dutyState.loaded[family]&&f.contentWindow)f.contentWindow.postMessage({type:'KEYSUITE_DASHBOARD_SELECT',requestId:req.requestId,flowM3h:req.flowM3h,headM:req.headM},'*')}
function ensureDashboardDutyFinder(){var dash=dashboard();if(!dash||document.getElementById('ksDashboardDutyFinder'))return;var card=document.createElement('div');card.id='ksDashboardDutyFinder';card.className='card';card.innerHTML='<div class="ks-duty-head"><div><h2>Quick Pump Selection</h2><div class="muted">Enter Flow and Head. Only pump families with a suitable model will appear.</div></div></div><div class="ks-duty-inputs"><label>Flow<input id="ksDashFlow" type="number" min="0" step="0.1" placeholder=""><div class="ks-unit">m³/hr</div></label><label>Head<input id="ksDashHead" type="number" min="0" step="0.1" placeholder=""><div class="ks-unit">Mtr</div></label><button id="ksDashSelect" class="btn" type="button">Check Pumps</button></div><div id="ksDutyStatus" class="ks-duty-status">Enter Flow and Head to check CHC and ES.</div><div id="ksDutyProducts" class="ks-duty-products"></div><div id="ksDutyBodies"></div>';
 var start=dash.querySelector('.dashboard-start-card');if(start&&start.parentNode)start.insertAdjacentElement('afterend',card);else{var h=dash.querySelector('h1');if(h)h.insertAdjacentElement('afterend',card);else dash.prepend(card)}
 function schedule(){clearTimeout(dutyState.timer);dutyState.timer=setTimeout(runDashboardDuty,350)}
 card.querySelector('#ksDashFlow').addEventListener('input',schedule);card.querySelector('#ksDashHead').addEventListener('input',schedule);card.querySelector('#ksDashSelect').onclick=runDashboardDuty;
 ensureFrame('CHC','selector/index.html?dashboard=1');ensureFrame('ES','selector-es/index.html?dashboard=1');
}
function fmt(v,d){v=Number(v);return Number.isFinite(v)?v.toFixed(d==null?2:d):'—'}
function resultKpis(data){return [
 ['Duty',fmt(data.flow_m3h||data.required_total_flow_m3h,2)+' m³/hr @ '+fmt(data.head_m||data.required_head_m,2)+' m'],
 ['Efficiency',fmt(data.efficiency,1)+' %'],['Power',fmt(data.shaft_kw,2)+' kW'],['NPSHr',fmt(data.npshr,2)+' m'],
 ['Motor',fmt(data.motor_kw,2)+' kW / '+fmt(data.motor_hp,2)+' HP'],['Speed',fmt(data.speed_rpm,0)+' rpm'],['Frequency',fmt(data.frequency_hz,1)+' Hz'],['Connection',data.connection||'—']
 ]}
function renderDashboardResults(){var products=document.getElementById('ksDutyProducts'),bodies=document.getElementById('ksDutyBodies'),status=document.getElementById('ksDutyStatus');if(!products||!bodies)return;var fams=['CHC','ES'].filter(function(f){return dutyState.results[f]&&dutyState.results[f].suitable&&dutyState.results[f].data});products.innerHTML='';bodies.innerHTML='';if(!fams.length){status.innerHTML='<div class="ks-duty-empty">No suitable CHC or ES model was found for this duty.</div>';return}status.textContent='Suitable product families: '+fams.join(', ')+'. Press a product to expand its recommended model.';
 fams.forEach(function(f){var r=dutyState.results[f],data=r.data;var fb=document.createElement('button');fb.type='button';fb.className='ks-duty-family';fb.textContent=f+' ▸';products.appendChild(fb);var body=document.createElement('div');body.className='ks-duty-family-body';body.dataset.family=f;var model=document.createElement('button');model.type='button';model.className='ks-duty-model';model.textContent=(data.model||f+' model');var info=document.createElement('div');info.className='ks-duty-info';info.innerHTML=resultKpis(data).map(function(x){return '<div class="ks-duty-kpi"><span>'+x[0]+'</span><b>'+x[1]+'</b></div>'}).join('');body.appendChild(model);body.appendChild(info);bodies.appendChild(body);fb.onclick=function(){var open=!body.classList.contains('active');body.classList.toggle('active',open);fb.classList.toggle('active',open);fb.textContent=f+(open?' ▼':' ▸')};model.onclick=function(){var open=!info.classList.contains('active');info.classList.toggle('active',open);model.classList.toggle('active',open)}})
}
function runDashboardDuty(){var flow=document.getElementById('ksDashFlow'),head=document.getElementById('ksDashHead'),status=document.getElementById('ksDutyStatus');if(!flow||!head)return;var q=Number(flow.value),h=Number(head.value);if(!(q>0&&h>0)){dutyState.results={};if(status)status.textContent='Enter Flow and Head to check CHC and ES.';var p=document.getElementById('ksDutyProducts'),b=document.getElementById('ksDutyBodies');if(p)p.innerHTML='';if(b)b.innerHTML='';return}var req={requestId:++dutyState.requestId,flowM3h:q,headM:h};dutyState.results={};dutyState.pending=req;if(status)status.textContent='Checking suitable pump families…';['CHC','ES'].forEach(function(f){sendDutyTo(f,req)});setTimeout(function(){if(req.requestId===dutyState.requestId)renderDashboardResults()},1700)}
window.addEventListener('message',function(e){var m=e.data||{};if(m.type!=='KEYSUITE_DASHBOARD_RESULT'||m.requestId!==dutyState.requestId)return;if(['CHC','ES'].indexOf(m.family)<0)return;dutyState.results[m.family]={suitable:!!m.suitable,data:m.data||null};renderDashboardResults()});

function boot(){addStyles();ensureDashboardDutyFinder();syncKeyCoreMode();var mo=new MutationObserver(function(){ensureDashboardDutyFinder();syncKeyCoreMode()});mo.observe(document.documentElement,{subtree:true,childList:true,attributes:true,attributeFilter:['class','hidden','style']});window.addEventListener('hashchange',function(){setTimeout(syncKeyCoreMode,0)});document.addEventListener('click',function(){setTimeout(syncKeyCoreMode,20)},false)}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot();
})();
