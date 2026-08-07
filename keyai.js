(() => {
  'use strict';
  const el=id=>document.getElementById(id);
  let access=null,bound=false,loaded=false;
  const owner=()=>String(access?.role||window.KEYSUITE_ACCESS?.role||'').toLowerCase()==='owner';
  const client=()=>window.KeySuiteAuth?.getClient?.()||null;
  function notice(text,type='info'){
    const box=el('keyAiNotice');if(!box)return;box.textContent=text||'';box.className='notice'+(type==='ok'?' active-customer':'');
  }
  function status(text,state=''){
    const label=el('keyAiOpenAiStatus'),dot=el('keyAiStatusDot');if(label)label.textContent=text||'';if(dot)dot.className=`keyai-status-dot ${state}`.trim();
  }
  function number(value){return Number(value||0).toLocaleString('en-MY')}
  function row(data){return Array.isArray(data)?(data[0]||{}):(data||{})}
  async function load(){
    if(!owner())return;const c=client();if(!c){notice('Secure connection is not available.');return}
    notice('Loading KeyAI settings…');
    try{
      const result=await c.rpc('keysuite_get_keyai_settings_v310');if(result.error)throw result.error;const r=row(result.data);
      el('keyAiOpenAiEnabled').checked=!!r.openai_enabled;el('keyAiOpenAiModel').value=r.openai_model||'gpt-5-mini';el('keyAiMonthlyLimit').value=Number(r.monthly_request_limit||0);
      el('keyAiUsageRequests').textContent=number(r.requests);el('keyAiUsageInputTokens').textContent=number(r.input_tokens);el('keyAiUsageOutputTokens').textContent=number(r.output_tokens);
      status(r.openai_enabled?'Enabled · connection not tested':'OpenAI is OFF',r.openai_enabled?'':'off');notice(r.openai_enabled?'OpenAI is enabled. Use Test Connection to verify the server-side API key.':'OpenAI is OFF. KeyAI will not call OpenAI.','ok');loaded=true;
    }catch(error){console.error(error);notice(`KeyAI settings are unavailable. Run V310_SUPABASE_MIGRATION.sql first. ${error.message||error}`);status('Settings unavailable','error')}
  }
  async function save(){
    if(!owner())return;const c=client();if(!c)return;const button=el('saveKeyAiSettings');if(button){button.disabled=true;button.textContent='Saving…'}
    try{
      const model=String(el('keyAiOpenAiModel').value||'').trim();if(!model)throw new Error('OpenAI Model is required.');const limit=Math.max(0,Math.floor(Number(el('keyAiMonthlyLimit').value||0)));
      const result=await c.rpc('keysuite_save_keyai_settings_v310',{p_enabled:!!el('keyAiOpenAiEnabled').checked,p_model:model,p_monthly_request_limit:limit});if(result.error)throw result.error;
      notice('KeyAI OpenAI settings saved.','ok');status(el('keyAiOpenAiEnabled').checked?'Enabled · connection not tested':'OpenAI is OFF',el('keyAiOpenAiEnabled').checked?'':'off');await load();
    }catch(error){notice(error.message||String(error));status('Save failed','error')}finally{if(button){button.disabled=false;button.textContent='Save Settings'}}
  }
  async function test(){
    if(!owner())return;if(!el('keyAiOpenAiEnabled').checked){notice('Turn OpenAI ON and save the setting before testing.');status('OpenAI is OFF','off');return}
    const c=client();if(!c)return;const button=el('testKeyAiConnection');if(button){button.disabled=true;button.textContent='Testing…'}status('Testing connection…');
    try{
      const result=await c.functions.invoke('keyai-openai',{body:{mode:'test'}});if(result.error)throw result.error;const data=result.data||{};if(!data.ok)throw new Error(data.error||'OpenAI connection test failed.');
      status(`Connected · ${data.model||el('keyAiOpenAiModel').value}`,'ok');notice('OpenAI connection successful. The API key remains server-side.','ok');await load();status(`Connected · ${data.model||el('keyAiOpenAiModel').value}`,'ok');
    }catch(error){console.error(error);status('Connection failed','error');notice(`OpenAI connection failed. Check the Edge Function and OPENAI_API_KEY secret. ${error.message||error}`)}finally{if(button){button.disabled=false;button.textContent='Test Connection'}}
  }
  function bind(){if(bound)return;bound=true;el('saveKeyAiSettings')?.addEventListener('click',save);el('testKeyAiConnection')?.addEventListener('click',test)}
  function init(nextAccess){access=nextAccess||window.KEYSUITE_ACCESS||{};bind();if(owner()&&el('keyAiSettings')?.classList.contains('active'))load()}
  function pageShown(id){if(id==='keyAiSettings'&&owner())load()}
  window.KeySuiteKeyAI={init,pageShown,load};
})();
