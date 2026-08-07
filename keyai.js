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
  function list(value){return Array.isArray(value)?value.map(v=>String(v||'').trim()).filter(Boolean):[]}
  function flowBasis(value){return ({total_system:'Total system flow',per_duty_pump:'Flow per duty pump'})[String(value||'')]||'Not confirmed'}
  function field(label,value){return `<div class="keyai-detail"><span>${esc(label)}</span><b>${esc(text(value))}</b></div>`}
  function friendlyDraft(item){
    const d=item.ai_result&&typeof item.ai_result==='object'?item.ai_result:{};
    const details=[];
    if(d.system_type||d.application)details.push(field('System / Application',d.system_type||d.application));
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
    const questions=list(item.clarification_questions).length?list(item.clarification_questions):list(d.clarification_questions);
    const followups=Array.isArray(item.followups)?item.followups:[];
    let html='';
    if(item.ai_summary||d.summary)html+=`<div class="keyai-draft-summary"><b>Summary</b><div>${esc(item.ai_summary||d.summary)}</div></div>`;
    if(details.length)html+=`<div class="keyai-detail-grid">${details.join('')}</div>`;
    if(questions.length)html+=`<div class="keyai-clarification"><b>Waiting for customer</b><ul>${questions.map(q=>`<li>${esc(q)}</li>`).join('')}</ul></div>`;
    if(critical.length)html+=`<div class="keyai-missing critical"><b>Critical / Need confirmation</b><ul>${critical.map(v=>`<li>${esc(v)}</li>`).join('')}</ul></div>`;
    if(missing.length)html+=`<div class="keyai-missing"><b>Other information not supplied</b><ul>${missing.map(v=>`<li>${esc(v)}</li>`).join('')}</ul></div>`;
    if(followups.length)html+=`<div class="keyai-conversation"><b>Customer follow-up</b>${followups.map(f=>`<div class="keyai-followup"><span>${esc(formatTime(f.created_at))}</span><div>${esc(f.message||'')}</div></div>`).join('')}</div>`;
    if(d.notes)html+=`<div class="keyai-notes"><b>Notes</b><div>${esc(d.notes)}</div></div>`;
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
    }catch(error){console.error(error);box.innerHTML=`<div class="notice">KeyAI Inbox is unavailable. Run V340_SUPABASE_MIGRATION.sql first. ${esc(error.message||error)}</div>`}
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
    }catch(error){console.error(error);notice(`KeyAI settings are unavailable. Run V340_SUPABASE_MIGRATION.sql first. ${error.message||error}`);status('Settings unavailable','error')}
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
