(() => {
  'use strict';
  const el=id=>document.getElementById(id);
  let access=null,bound=false;
  const owner=()=>String(access?.role||window.KEYSUITE_ACCESS?.role||'').toLowerCase()==='owner';
  const client=()=>window.KeySuiteAuth?.getClient?.()||null;
  const esc=value=>String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  function notice(text,type='info'){const box=el('keyAiNotice');if(!box)return;box.textContent=text||'';box.className='notice'+(type==='ok'?' active-customer':'')}
  function status(text,state=''){const label=el('keyAiOpenAiStatus'),dot=el('keyAiStatusDot');if(label)label.textContent=text||'';if(dot)dot.className=`keyai-status-dot ${state}`.trim()}
  function number(value){return Number(value||0).toLocaleString('en-MY')}
  function moneyUsd(value){const n=Number(value||0);return n<0.01?`US$ ${n.toFixed(6)}`:`US$ ${n.toFixed(2)}`}
  function row(data){return Array.isArray(data)?(data[0]||{}):(data||{})}
  function statusLabel(value){
    const map={ai_disabled_manual_review:'AI Disabled – Manual Review',ai_draft_ready:'AI Draft Ready',awaiting_customer:'Awaiting Customer',ai_error_manual_review:'AI Error – Manual Review',received:'Received',processing:'Processing',followup_processed:'Follow-up Processed'};
    return map[String(value||'')]||String(value||'Received').replaceAll('_',' ');
  }
  function statusClass(value){value=String(value||'');return value==='ai_draft_ready'?'ready':value==='awaiting_customer'?'waiting':value.includes('error')?'error':''}
  function formatTime(value){if(!value)return '-';try{return new Date(value).toLocaleString('en-MY',{dateStyle:'medium',timeStyle:'short'})}catch(_){return String(value)}}
  function text(value,fallback='—'){const s=String(value??'').trim();return s||fallback}
  function jsonish(value){const s=String(value??'').trim().replace(/^```(?:json)?\s*/i,'').replace(/\s*```$/,'').trim();return s.startsWith('{')||s.startsWith('[')||s.startsWith('"{')||s.startsWith("'{")}
  function parseJsonish(value){
    if(value&&typeof value==='object'&&!Array.isArray(value))return value;
    let s=String(value??'').trim().replace(/^```(?:json)?\s*/i,'').replace(/\s*```$/,'').trim();
    if(!s)return null;
    for(let i=0;i<3;i++){
      try{const parsed=JSON.parse(s);if(parsed&&typeof parsed==='object'&&!Array.isArray(parsed))return parsed;if(typeof parsed==='string'){s=parsed.trim();continue}}catch(_){/* try object slice below */}
      const first=s.indexOf('{'),last=s.lastIndexOf('}');
      if(first>=0&&last>first){try{const parsed=JSON.parse(s.slice(first,last+1));if(parsed&&typeof parsed==='object'&&!Array.isArray(parsed))return parsed}catch(_){}}
      break;
    }
    return null;
  }
  function list(value){
    if(Array.isArray(value))return value.map(v=>String(v||'').trim()).filter(Boolean);
    if(typeof value==='string'&&value.trim().startsWith('[')){try{const parsed=JSON.parse(value);if(Array.isArray(parsed))return parsed.map(v=>String(v||'').trim()).filter(Boolean)}catch(_){}}
    return [];
  }
  function firstNumber(match){const n=Number(match?.[1]);return Number.isFinite(n)?n:null}
  function extractFacts(source){
    const s=String(source||'');
    const lower=s.toLowerCase();
    const duty=firstNumber(s.match(/(\d+)\s*duty\b/i));
    const standby=firstNumber(s.match(/(\d+)\s*standby\b/i));
    const flowMatch=s.match(/(\d+(?:\.\d+)?)\s*(?:m3|m³)\s*\/\s*(?:h|hr|hour)\b/i);
    const headMatch=s.match(/(?:head\s*[:=]?\s*)?(\d+(?:\.\d+)?)\s*m\s*(?:head)?\b/i);
    const voltageMatch=s.match(/(\d+(?:\.\d+)?)\s*v\b/i);
    const hzMatch=s.match(/(\d+(?:\.\d+)?)\s*hz\b/i);
    const phaseMatch=s.match(/\b([13])\s*(?:ph|phase)\b/i);
    let application=null;
    if(/\bbooster\b/i.test(s))application='Booster';
    else if(/\btransfer\b/i.test(s))application='Transfer';
    let material=null;
    if(/\b(?:ss\s*304|stainless\s*steel\s*304)\b/i.test(s))material='SS304';
    else if(/\b(?:ss\s*316|stainless\s*steel\s*316)\b/i.test(s))material='SS316';
    else if(/\bcast\s*iron\b/i.test(s)||/\bci\b/i.test(s))material='Cast Iron';
    let flowBasis=null;
    if(/\b(total|system)\s*(?:system\s*)?flow\b/i.test(s)||/\b(?:m3|m³)\s*\/\s*(?:h|hr|hour)\s*(?:is\s*)?total\b/i.test(lower))flowBasis='total_system';
    if(/\bper\s+(?:duty\s+)?pump\b/i.test(s)||/\beach\s+(?:duty\s+)?pump\b/i.test(s)||/\bper\s+duty\b/i.test(s))flowBasis='per_duty_pump';
    return {
      application,system_type:application?`${application} System`:null,
      pump_quantity:(duty!==null||standby!==null)?Number(duty||0)+Number(standby||0):null,
      duty_configuration:(duty!==null||standby!==null)?[duty!==null?`${duty} Duty`:null,standby!==null?`${standby} Standby`:null].filter(Boolean).join(' + '):null,
      flow_value:firstNumber(flowMatch),flow_unit:flowMatch?'m³/hr':null,flow_basis:flowBasis,
      head_value:firstNumber(headMatch),head_unit:headMatch?'m':null,material,
      voltage:firstNumber(voltageMatch),phase:phaseMatch?`${phaseMatch[1]} Phase`:null,frequency_hz:firstNumber(hzMatch)
    };
  }
  function normalApplication(value){const s=String(value||'').trim();if(/booster/i.test(s))return 'Booster';if(/transfer/i.test(s))return 'Transfer';return s||null}
  function generatedSummary(d){
    const parts=[];
    if(d.system_type)parts.push(d.system_type);
    if(d.duty_configuration)parts.push(d.duty_configuration);
    if(d.flow_value!==null&&d.flow_value!==undefined)parts.push(`${d.flow_value} ${d.flow_unit||'m³/hr'}`);
    if(d.head_value!==null&&d.head_value!==undefined)parts.push(`${d.head_value} ${d.head_unit||'m'} head`);
    if(d.voltage!==null&&d.voltage!==undefined)parts.push(`${d.voltage} V`);
    return parts.join(' · ')||'KeyAI prepared quotation requirements.';
  }
  function normaliseDraft(item){
    let d=parseJsonish(item?.ai_result)||{};
    const nested=parseJsonish(d.raw_output)||parseJsonish(jsonish(d.summary)?d.summary:'');
    if(nested)d={...d,...nested};
    const followups=Array.isArray(item?.followups)?item.followups:[];
    const source=[item?.raw_message||'',...followups.map(f=>f?.message||''),typeof item?.ai_result==='string'?item.ai_result:'',typeof d.raw_output==='string'?d.raw_output:''].filter(Boolean).join('\n');
    const facts=extractFacts(source);
    const merged={...d};
    ['application','system_type','pump_quantity','duty_configuration','flow_value','flow_unit','flow_basis','head_value','head_unit','material','voltage','phase','frequency_hz'].forEach(k=>{
      if((merged[k]===null||merged[k]===undefined||merged[k]==='')&&facts[k]!==null&&facts[k]!==undefined&&facts[k]!=='')merged[k]=facts[k];
    });
    merged.application=normalApplication(merged.application||facts.application);
    if(merged.application&&(!merged.system_type||/duty|standby/i.test(String(merged.system_type))))merged.system_type=`${merged.application} System`;
    if(merged.flow_value!==null&&merged.flow_value!==undefined)merged.flow_unit='m³/hr';
    if(merged.head_value!==null&&merged.head_value!==undefined)merged.head_unit='m';
    if(!['total_system','per_duty_pump'].includes(String(merged.flow_basis||'')))merged.flow_basis=facts.flow_basis||null;
    const parsedSummary=String(merged.summary||'').trim();
    merged.summary=parsedSummary&&!jsonish(parsedSummary)?parsedSummary:generatedSummary(merged);
    let critical=list(merged.critical_missing_information);
    let missing=list(merged.missing_information);
    if(merged.flow_basis){critical=critical.filter(v=>!/total system flow|per duty pump|flow basis|whether .*flow/i.test(v));missing=missing.filter(v=>!/total system flow|per duty pump|flow basis|whether .*flow/i.test(v));}
    if(merged.flow_value!==null&&merged.flow_value!==undefined)critical=critical.filter(v=>!/required flow|flow is not confirmed/i.test(v));
    if(merged.head_value!==null&&merged.head_value!==undefined)critical=critical.filter(v=>!/required head|head is not confirmed/i.test(v));
    if(merged.material){critical=critical.filter(v=>!/material/i.test(v));missing=missing.filter(v=>!/material/i.test(v));}
    const automaticCritical=[];
    const multiDuty=Number(merged.pump_quantity||0)>1||/\b[2-9]\d*\s*duty\b/i.test(String(merged.duty_configuration||source));
    if(multiDuty&&merged.flow_value!==null&&merged.flow_value!==undefined&&!merged.flow_basis)automaticCritical.push(`Confirm whether ${merged.flow_value} ${merged.flow_unit||'m³/hr'} is total system flow or flow per duty pump.`);
    if(merged.flow_value===null||merged.flow_value===undefined)automaticCritical.push('Required flow is not confirmed.');
    if(merged.head_value===null||merged.head_value===undefined)automaticCritical.push('Required head is not confirmed.');
    critical=[...automaticCritical,...critical].filter((v,i,a)=>v&&a.indexOf(v)===i).filter(v=>!/fluid temperature|viscosity|solids content|fluid properties|material/i.test(v));
    if(!merged.material&&!missing.some(v=>/material/i.test(v)))missing.unshift('Pump material not specified.');
    missing=missing.filter((v,i,a)=>v&&a.indexOf(v)===i).filter(v=>!critical.includes(v));
    merged.critical_missing_information=critical;
    merged.missing_information=missing;
    merged.clarification_questions=list(item?.clarification_questions).length?list(item.clarification_questions):list(merged.clarification_questions);
    return merged;
  }
  function flowBasis(value){return ({total_system:'Total system flow',per_duty_pump:'Flow per duty pump'})[String(value||'')]||'Not confirmed'}
  function field(label,value){return `<div class="keyai-detail"><span>${esc(label)}</span><b>${esc(text(value))}</b></div>`}
  function friendlyDraft(item){
    const d=normaliseDraft(item);
    const details=[];
    if(d.system_type)details.push(field('System',d.system_type));
    if(d.application&&String(d.application)!==String(d.system_type))details.push(field('Application',d.application));
    if(d.duty_configuration)details.push(field('Configuration',d.duty_configuration));
    if(d.pump_quantity!==null&&d.pump_quantity!==undefined)details.push(field('Total Pumps',d.pump_quantity));
    if(d.flow_value!==null&&d.flow_value!==undefined)details.push(field('Flow',`${d.flow_value} ${d.flow_unit||''}`.trim()));
    if(d.flow_value!==null&&d.flow_value!==undefined)details.push(field('Flow Basis',flowBasis(d.flow_basis)));
    if(d.head_value!==null&&d.head_value!==undefined)details.push(field('Head',`${d.head_value} ${d.head_unit||''}`.trim()));
    if(d.voltage!==null&&d.voltage!==undefined)details.push(field('Voltage',`${d.voltage} V`));
    if(d.phase)details.push(field('Phase',d.phase));
    if(d.frequency_hz!==null&&d.frequency_hz!==undefined)details.push(field('Frequency',`${d.frequency_hz} Hz`));
    if(d.material)details.push(field('Material',d.material));
    const critical=list(d.critical_missing_information);
    const missing=list(d.missing_information).filter(x=>!critical.includes(x));
    const questions=String(item?.status||'')==='awaiting_customer'?list(d.clarification_questions):[];
    const followups=Array.isArray(item.followups)?item.followups:[];
    let html=`<div class="keyai-draft-summary"><b>Summary</b><div>${esc(d.summary||generatedSummary(d))}</div></div>`;
    if(details.length)html+=`<div class="keyai-detail-grid">${details.join('')}</div>`;
    if(questions.length)html+=`<div class="keyai-clarification"><b>Waiting for customer</b><ul>${questions.map(q=>`<li>${esc(q)}</li>`).join('')}</ul></div>`;
    if(critical.length)html+=`<div class="keyai-missing critical"><b>Critical / Need confirmation</b><ul>${critical.map(v=>`<li>${esc(v)}</li>`).join('')}</ul></div>`;
    if(missing.length)html+=`<div class="keyai-missing"><b>Other information not supplied</b><ul>${missing.map(v=>`<li>${esc(v)}</li>`).join('')}</ul></div>`;
    if(followups.length)html+=`<div class="keyai-conversation"><b>Customer follow-up</b>${followups.map(f=>`<div class="keyai-followup"><span>${esc(formatTime(f.created_at))}</span><div>${esc(f.message||'')}</div></div>`).join('')}</div>`;
    if(d.notes&&!jsonish(d.notes))html+=`<div class="keyai-notes"><b>Notes</b><div>${esc(d.notes)}</div></div>`;
    return html;
  }
  async function loadInbox(){
    if(!owner())return;const c=client(),box=el('keyAiInbox');if(!c||!box)return;
    box.innerHTML='<div class="muted">Loading Telegram enquiries…</div>';
    try{
      const result=await c.rpc('keysuite_list_keyai_enquiries_v340',{p_limit:50});if(result.error)throw result.error;
      const items=Array.isArray(result.data)?result.data:[];
      box.innerHTML=items.map(item=>{
        const sender=[item.sender_name,item.sender_username?`@${item.sender_username}`:''].filter(Boolean).join(' · ')||'Telegram user';
        return `<div class="keyai-enquiry"><div class="keyai-enquiry-head"><div><b>${esc(sender)}</b><div class="keyai-enquiry-meta">${esc(formatTime(item.created_at))} · Telegram</div></div><span class="keyai-enquiry-status ${statusClass(item.status)}">${esc(statusLabel(item.status))}</span></div><div class="keyai-enquiry-message">${esc(item.raw_message||'')}</div>${item.ai_enabled?`<div class="keyai-friendly-draft">${friendlyDraft(item)}</div>`:''}${item.ai_error?`<div class="keyai-enquiry-ai"><b>AI error:</b> ${esc(item.ai_error)}</div>`:''}</div>`;
      }).join('')||'<div class="muted">No Telegram enquiries yet.</div>';
    }catch(error){console.error(error);box.innerHTML=`<div class="notice">KeyAI Inbox is unavailable. V3.6 uses the existing V340 database functions. ${esc(error.message||error)}</div>`}
  }
  function persistentStatus(r){
    if(!r.openai_enabled)return {text:'OpenAI is OFF',state:'off'};
    if(r.last_test_ok===true&&r.last_test_at)return {text:`Connected · ${r.last_test_model||r.openai_model} · tested ${formatTime(r.last_test_at)}`,state:'ok'};
    if(r.last_usage_at)return {text:`Active · ${r.openai_model} · last API use ${formatTime(r.last_usage_at)}`,state:'ok'};
    if(r.last_test_ok===false&&r.last_test_at)return {text:`Last test failed · ${formatTime(r.last_test_at)}`,state:'error'};
    return {text:'Enabled · connection not tested',state:''};
  }
  async function load(){
    if(!owner())return;const c=client();if(!c){notice('Secure connection is not available.');return}
    notice('Loading KeyAI settings…');
    try{
      const result=await c.rpc('keysuite_get_keyai_settings_v340');if(result.error)throw result.error;const r=row(result.data);
      el('keyAiOpenAiEnabled').checked=!!r.openai_enabled;el('keyAiOpenAiModel').value=r.openai_model||'gpt-5-mini';el('keyAiMonthlyLimit').value=Number(r.monthly_request_limit??500);
      el('keyAiUsageRequests').textContent=number(r.requests);el('keyAiUsageInputTokens').textContent=number(r.input_tokens);el('keyAiUsageOutputTokens').textContent=number(r.output_tokens);if(el('keyAiUsageCost'))el('keyAiUsageCost').textContent=moneyUsd(r.estimated_cost_usd);
      const s=persistentStatus(r);status(s.text,s.state);
      notice(r.openai_enabled?'OpenAI is enabled. Telegram enquiries can use KeyAI and automatically ask for critical clarification when needed.':'OpenAI is OFF. Telegram enquiries will be saved for manual review without any OpenAI call.','ok');
      await loadInbox();
    }catch(error){console.error(error);notice(`KeyAI settings are unavailable. V3.6 uses the V340 KeyAI database functions. ${error.message||error}`);status('Settings unavailable','error')}
  }
  async function save(){
    if(!owner())return;const c=client();if(!c)return;const button=el('saveKeyAiSettings');if(button){button.disabled=true;button.textContent='Saving…'}
    try{
      const model=String(el('keyAiOpenAiModel').value||'').trim();if(!model)throw new Error('OpenAI Model is required.');const limit=Math.max(0,Math.floor(Number(el('keyAiMonthlyLimit').value||0)));
      const result=await c.rpc('keysuite_save_keyai_settings_v340',{p_enabled:!!el('keyAiOpenAiEnabled').checked,p_model:model,p_monthly_request_limit:limit});if(result.error)throw result.error;
      notice('KeyAI OpenAI settings saved.','ok');await load();
    }catch(error){notice(error.message||String(error));status('Save failed','error')}finally{if(button){button.disabled=false;button.textContent='Save Settings'}}
  }
  async function test(){
    if(!owner())return;if(!el('keyAiOpenAiEnabled').checked){notice('Turn OpenAI ON and save the setting before testing.');status('OpenAI is OFF','off');return}
    const c=client();if(!c)return;const button=el('testKeyAiConnection');if(button){button.disabled=true;button.textContent='Testing…'}status('Testing connection…');
    try{
      const result=await c.functions.invoke('keyai-openai',{body:{mode:'test'}});if(result.error)throw result.error;const data=result.data||{};if(!data.ok)throw new Error(data.error||'OpenAI connection test failed.');
      notice('OpenAI connection successful. The successful test is now saved server-side.','ok');await load();
    }catch(error){console.error(error);status('Connection failed','error');notice(`OpenAI connection failed. Check the Edge Function and OPENAI_API_KEY secret. ${error.message||error}`)}finally{if(button){button.disabled=false;button.textContent='Test Connection'}}
  }
  function bind(){if(bound)return;bound=true;el('saveKeyAiSettings')?.addEventListener('click',save);el('testKeyAiConnection')?.addEventListener('click',test);el('refreshKeyAiInbox')?.addEventListener('click',loadInbox)}
  function init(nextAccess){access=nextAccess||window.KEYSUITE_ACCESS||{};bind();if(owner()&&el('keyAiSettings')?.classList.contains('active'))load()}
  function pageShown(id){if(id==='keyAiSettings'&&owner())load()}
  window.KeySuiteKeyAI={init,pageShown,load,loadInbox};
})();
