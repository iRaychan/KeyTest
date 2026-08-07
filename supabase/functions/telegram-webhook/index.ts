import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json'}});
const env=(...names:string[])=>{for(const name of names){const value=Deno.env.get(name);if(value)return value}return ''};

async function telegramSend(token:string,chatId:string,text:string){
  if(!token||!chatId)return;
  const response=await fetch(`https://api.telegram.org/bot${token}/sendMessage`,{
    method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({chat_id:chatId,text})
  });
  if(!response.ok){const detail=await response.text().catch(()=>response.statusText);console.error('Telegram sendMessage failed',response.status,detail)}
}
function parseAiJson(text:string){
  let cleaned=String(text||'').trim().replace(/^```(?:json)?\s*/i,'').replace(/\s*```$/,'').trim();
  if(!cleaned)return null;
  for(let i=0;i<3;i++){
    try{const parsed=JSON.parse(cleaned);if(parsed&&typeof parsed==='object'&&!Array.isArray(parsed))return parsed;if(typeof parsed==='string'){cleaned=parsed.trim();continue}}catch(_){/* try extracting the object below */}
    const first=cleaned.indexOf('{'),last=cleaned.lastIndexOf('}');
    if(first>=0&&last>first){try{const parsed=JSON.parse(cleaned.slice(first,last+1));if(parsed&&typeof parsed==='object'&&!Array.isArray(parsed))return parsed}catch(_){}}
    break;
  }
  return {raw_output:cleaned};
}
function strings(value:any,max=20){
  if(typeof value==='string'&&value.trim().startsWith('[')){try{value=JSON.parse(value)}catch(_){}}
  return (Array.isArray(value)?value:[]).map(v=>String(v||'').trim()).filter(Boolean).filter((v,i,a)=>a.indexOf(v)===i).slice(0,max);
}
function firstNumber(match:RegExpMatchArray|null){const n=Number(match?.[1]);return Number.isFinite(n)?n:null}
function extractFacts(source:string){
  const s=String(source||''),lower=s.toLowerCase();
  const duty=firstNumber(s.match(/(\d+)\s*duty\b/i));
  const standby=firstNumber(s.match(/(\d+)\s*standby\b/i));
  const flowMatch=s.match(/(\d+(?:\.\d+)?)\s*(?:m3|m³)\s*\/\s*(?:h|hr|hour)\b/i);
  const headMatch=s.match(/(?:head\s*[:=]?\s*)?(\d+(?:\.\d+)?)\s*m\s*(?:head)?\b/i);
  const voltageMatch=s.match(/(\d+(?:\.\d+)?)\s*v\b/i);
  const hzMatch=s.match(/(\d+(?:\.\d+)?)\s*hz\b/i);
  const phaseMatch=s.match(/\b([13])\s*(?:ph|phase)\b/i);
  let application:string|null=null;
  if(/\bbooster\b/i.test(s))application='Booster';else if(/\btransfer\b/i.test(s))application='Transfer';
  let material:string|null=null;
  if(/\b(?:ss\s*304|stainless\s*steel\s*304)\b/i.test(s))material='SS304';
  else if(/\b(?:ss\s*316|stainless\s*steel\s*316)\b/i.test(s))material='SS316';
  else if(/\bcast\s*iron\b/i.test(s)||/\bci\b/i.test(s))material='Cast Iron';
  let flowBasis:string|null=null;
  if(/\btotal\s+(?:system\s+)?flow\b/i.test(s)||/\bsystem\s+flow\b/i.test(s)||/\b(?:m3|m³)\s*\/\s*(?:h|hr|hour)\s*(?:is\s*)?total\b/i.test(s))flowBasis='total_system';
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
function normalApplication(value:any){const s=String(value||'').trim();if(/booster/i.test(s))return 'Booster';if(/transfer/i.test(s))return 'Transfer';return s||null}
function generatedSummary(d:any){
  const parts:string[]=[];
  if(d.system_type)parts.push(String(d.system_type));
  if(d.duty_configuration)parts.push(String(d.duty_configuration));
  if(d.flow_value!==null&&d.flow_value!==undefined)parts.push(`${d.flow_value} ${d.flow_unit||'m³/hr'}`);
  if(d.head_value!==null&&d.head_value!==undefined)parts.push(`${d.head_value} ${d.head_unit||'m'} head`);
  if(d.voltage!==null&&d.voltage!==undefined)parts.push(`${d.voltage} V`);
  return parts.join(' · ')||'KeyAI prepared quotation requirements.';
}
function cleanQuestion(question:string,ordinaryWaterSystem:boolean){
  const q=String(question||'').trim();if(!q)return '';
  if(ordinaryWaterSystem&&/fluid temperature|viscosity|solids content|fluid properties|material/i.test(q))return '';
  return q.replace(/^[-*\d.)\s]+/,'').trim();
}
function normaliseResult(parsed:any,source:string,existing:any=null){
  const base=existing&&typeof existing==='object'&&!Array.isArray(existing)?{...existing}:{};
  const incoming=parsed&&typeof parsed==='object'&&!Array.isArray(parsed)?parsed:{};
  let d:any={...base};
  Object.entries(incoming).forEach(([key,value])=>{
    if(Array.isArray(value)){d[key]=value;return;}
    if(value!==null&&value!==undefined&&value!==''){d[key]=value;return;}
    if(!(key in d))d[key]=value;
  });
  if(typeof d.raw_output==='string'){
    const nested=parseAiJson(d.raw_output);if(nested&&!nested.raw_output)d={...base,...nested,...incoming};
  }
  const facts=extractFacts(source);
  ['application','system_type','pump_quantity','duty_configuration','flow_value','flow_unit','flow_basis','head_value','head_unit','material','voltage','phase','frequency_hz'].forEach(k=>{
    if((d[k]===null||d[k]===undefined||d[k]==='')&&facts[k]!==null&&facts[k]!==undefined&&facts[k]!=='')d[k]=facts[k];
  });
  // Follow-up phrases such as "30 m3/hr total" must override a previous unknown basis/material.
  if(facts.flow_basis)d.flow_basis=facts.flow_basis;
  if(facts.material)d.material=facts.material;
  d.application=normalApplication(d.application||facts.application);
  if(d.application&&(!d.system_type||/duty|standby/i.test(String(d.system_type))))d.system_type=`${d.application} System`;
  if(d.flow_value!==null&&d.flow_value!==undefined)d.flow_unit='m³/hr';
  if(d.head_value!==null&&d.head_value!==undefined)d.head_unit='m';
  if(!['total_system','per_duty_pump'].includes(String(d.flow_basis||'')))d.flow_basis=facts.flow_basis||null;
  if(!d.pump_quantity&&facts.pump_quantity)d.pump_quantity=facts.pump_quantity;
  if(!d.duty_configuration&&facts.duty_configuration)d.duty_configuration=facts.duty_configuration;
  const ordinaryWaterSystem=['Booster','Transfer'].includes(String(d.application||''));
  let questions=strings(d.clarification_questions,3).map(q=>cleanQuestion(q,ordinaryWaterSystem)).filter(Boolean);
  if(d.flow_basis)questions=questions.filter(q=>!/total system flow|per duty pump|flow basis|whether .*flow/i.test(q));
  if(d.flow_value!==null&&d.flow_value!==undefined)questions=questions.filter(q=>!/confirm the required flow|what is the required flow/i.test(q));
  if(d.head_value!==null&&d.head_value!==undefined)questions=questions.filter(q=>!/confirm the required head|what is the required head/i.test(q));
  if(d.material)questions=questions.filter(q=>!/material/i.test(q));
  const automaticQuestions:string[]=[];
  const multiDuty=Number(d.pump_quantity||0)>1||/\b[2-9]\d*\s*duty\b/i.test(String(d.duty_configuration||source));
  if(multiDuty&&d.flow_value!==null&&d.flow_value!==undefined&&!d.flow_basis){
    automaticQuestions.push(`Please confirm whether ${d.flow_value} ${d.flow_unit||'m³/hr'} is the total system flow for the duty pumps, or ${d.flow_value} ${d.flow_unit||'m³/hr'} per duty pump.`);
  }
  if(d.flow_value===null||d.flow_value===undefined)automaticQuestions.push('Please confirm the required flow rate.');
  if(d.head_value===null||d.head_value===undefined)automaticQuestions.push('Please confirm the required head.');
  questions=[...automaticQuestions,...questions].filter((v,i,a)=>v&&a.indexOf(v)===i).slice(0,3);
  let critical=strings(d.critical_missing_information).filter(v=>!ordinaryWaterSystem||!/fluid temperature|viscosity|solids content|fluid properties|material/i.test(v));
  if(d.flow_basis)critical=critical.filter(v=>!/total system flow|per duty pump|flow basis|whether .*flow/i.test(v));
  if(d.flow_value!==null&&d.flow_value!==undefined)critical=critical.filter(v=>!/required flow|flow is not confirmed/i.test(v));
  if(d.head_value!==null&&d.head_value!==undefined)critical=critical.filter(v=>!/required head|head is not confirmed/i.test(v));
  if(d.material)critical=critical.filter(v=>!/material/i.test(v));
  if(multiDuty&&d.flow_value!==null&&d.flow_value!==undefined&&!d.flow_basis)critical.unshift(`Confirm whether ${d.flow_value} ${d.flow_unit||'m³/hr'} is total system flow or flow per duty pump.`);
  if(d.flow_value===null||d.flow_value===undefined)critical.unshift('Required flow is not confirmed.');
  if(d.head_value===null||d.head_value===undefined)critical.unshift('Required head is not confirmed.');
  critical=critical.filter((v,i,a)=>v&&a.indexOf(v)===i);
  let missing=strings(d.missing_information).filter(v=>!critical.includes(v));
  if(d.material)missing=missing.filter(v=>!/material/i.test(v));
  if(d.flow_basis)missing=missing.filter(v=>!/total system flow|per duty pump|flow basis|whether .*flow/i.test(v));
  if(!d.material&&!missing.some(v=>/material/i.test(v)))missing.unshift('Pump material not specified.');
  if(ordinaryWaterSystem)missing=missing.filter(v=>!/fluid temperature|viscosity|solids content|fluid properties/i.test(v));
  d.critical_missing_information=critical;
  d.missing_information=missing.filter((v,i,a)=>v&&a.indexOf(v)===i);
  d.clarification_questions=questions;
  const summary=String(d.summary||'').trim();
  d.summary=summary&&!summary.startsWith('{')?summary:generatedSummary(d);
  if('raw_output' in d)delete d.raw_output;
  return d;
}
function summaryFrom(result:any){return String(result?.summary||generatedSummary(result||{})).trim()}
function clarificationText(questions:string[]){
  if(!questions.length)return '';
  if(questions.length===1)return `Thank you. I need one confirmation before preparing the requirements:\n${questions[0]}`;
  return `Thank you. I need a little more information before preparing the requirements:\n${questions.map((q,i)=>`${i+1}. ${q}`).join('\n')}`;
}

Deno.serve(async(req)=>{
  if(req.method!=='POST')return json({ok:false,error:'POST required.'},405);
  try{
    const supabaseUrl=env('SUPABASE_URL');
    const serviceKey=env('SUPABASE_SERVICE_ROLE_KEY');
    const telegramToken=env('TELEGRAM_BOT_TOKEN','KeySuiteBot_Token');
    const webhookSecret=env('TELEGRAM_WEBHOOK_SECRET','KeySuiteBot_TELEGRAM_WEBHOOK_SECRET');
    const internalSecret=env('KEYAI_INTERNAL_SECRET');
    if(!supabaseUrl||!serviceKey)throw new Error('Supabase function environment is incomplete.');
    if(!telegramToken)throw new Error('Telegram bot token secret is missing.');
    if(!webhookSecret)throw new Error('Telegram webhook secret is missing.');
    const supplied=req.headers.get('X-Telegram-Bot-Api-Secret-Token')||'';
    if(supplied!==webhookSecret)return json({ok:false,error:'Invalid Telegram webhook secret.'},401);

    const update=await req.json().catch(()=>null) as any;
    const message=update?.message||update?.edited_message||null;
    if(!message)return json({ok:true,ignored:true});
    const text=String(message?.text||message?.caption||'').trim();
    const chatId=String(message?.chat?.id||'');
    if(!text){await telegramSend(telegramToken,chatId,'Thank you. Please send your pump or quotation enquiry as a text message.');return json({ok:true,ignored:true,reason:'non-text'})}

    const service=createClient(supabaseUrl,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
    const updateId=Number.isFinite(Number(update?.update_id))?Number(update.update_id):null;
    if(updateId!==null){
      const existing=await service.from('ks_keyai_enquiries').select('id,status').eq('source','telegram').eq('external_update_id',updateId).maybeSingle();
      if(existing.data?.id)return json({ok:true,duplicate:true,id:existing.data.id,status:existing.data.status});
    }

    const senderName=[message?.from?.first_name,message?.from?.last_name].filter(Boolean).join(' ').trim();
    const senderUsername=String(message?.from?.username||'');
    const settingsResult=await service.from('ks_app_settings').select('keyai_openai_enabled,keyai_openai_model').eq('id','default').maybeSingle();
    if(settingsResult.error)throw settingsResult.error;
    const openAiEnabled=!!settingsResult.data?.keyai_openai_enabled;
    const model=String(settingsResult.data?.keyai_openai_model||'gpt-5-mini');

    const activeSince=new Date(Date.now()-7*24*60*60*1000).toISOString();
    const activeResult=await service.from('ks_keyai_enquiries')
      .select('id,conversation_id,raw_message,ai_result,clarification_question,clarification_questions,updated_at')
      .eq('source','telegram').eq('external_chat_id',chatId).is('parent_enquiry_id',null).eq('status','awaiting_customer')
      .gte('updated_at',activeSince).order('updated_at',{ascending:false}).limit(1).maybeSingle();
    if(activeResult.error)throw activeResult.error;
    const active=activeResult.data||null;

    const insertResult=await service.from('ks_keyai_enquiries').insert({
      source:'telegram',external_update_id:updateId,external_message_id:Number(message?.message_id||0)||null,
      external_chat_id:chatId,sender_username:senderUsername||null,sender_name:senderName||null,
      raw_message:text,status:openAiEnabled?'processing':'ai_disabled_manual_review',ai_enabled:openAiEnabled,ai_model:openAiEnabled?model:null,
      parent_enquiry_id:active?.id||null,conversation_id:active?(active.conversation_id||active.id):null
    }).select('id').single();
    if(insertResult.error)throw insertResult.error;
    const enquiryId=insertResult.data.id;
    const rootId=active?.id||enquiryId;
    if(!active)await service.from('ks_keyai_enquiries').update({conversation_id:enquiryId}).eq('id',enquiryId);

    if(!openAiEnabled){
      if(active)await service.from('ks_keyai_enquiries').update({status:'ai_disabled_manual_review',updated_at:new Date().toISOString()}).eq('id',active.id);
      await telegramSend(telegramToken,chatId,'Thank you. Your enquiry has been received. AI processing is currently disabled. Your enquiry has been saved for manual review.');
      return json({ok:true,id:rootId,openai:false,status:'ai_disabled_manual_review'});
    }

    if(!internalSecret){
      const error='KEYAI_INTERNAL_SECRET is not configured.';
      await service.from('ks_keyai_enquiries').update({status:'ai_error_manual_review',ai_error:error,updated_at:new Date().toISOString()}).eq('id',rootId);
      if(active)await service.from('ks_keyai_enquiries').update({status:'ai_error_manual_review',ai_error:error}).eq('id',enquiryId);
      await telegramSend(telegramToken,chatId,'Thank you. Your enquiry has been received and saved for manual review.');
      return json({ok:true,id:rootId,openai:true,status:'ai_error_manual_review',error});
    }

    const baseInstructions=`You are KeyAI for KeySuite. Extract and update customer pump/system quotation requirements only. Do not select a pump model, calculate engineering performance, calculate prices, discounts, margins, commercial terms, or send a quotation. The API enforces the JSON schema. Use null for unknown scalar values and [] for empty arrays. flow_basis must be total_system, per_duty_pump, or null. clarification_questions must contain at most 3 concise customer-facing questions and ONLY questions needed to resolve a real ambiguity or information that blocks duty interpretation. For multiple-duty-pump systems, if the flow basis is unclear, ask whether the stated flow is total system flow or flow per duty pump. Do not ask for fluid temperature, viscosity, solids content, or detailed fluid properties for an ordinary booster/transfer water enquiry unless the customer indicates a non-water or special-fluid application. Missing material may be recorded but does not by itself block preparation because KeySuite can use its standard material defaults. Normalize system_type to the actual system such as Booster System or Transfer System; keep duty_configuration separate. Preserve facts already confirmed by the customer. Keep the summary concise.`;
    const existingNormal=active?normaliseResult(active.ai_result,active.raw_message):null;
    const aiInput=active
      ?`Existing extracted requirements:\n${JSON.stringify(existingNormal||{},null,2)}\n\nPrevious KeyAI clarification:\n${String(active.clarification_question||'')}\n\nCustomer follow-up reply:\n${text}\n\nMerge the reply into the existing requirements. Remove resolved items from critical_missing_information and clarification_questions.`
      :text;
    const aiResponse=await fetch(`${supabaseUrl}/functions/v1/keyai-openai`,{
      method:'POST',headers:{'Content-Type':'application/json','Authorization':`Bearer ${serviceKey}`,'x-keyai-internal-secret':internalSecret},
      body:JSON.stringify({mode:active?'telegram-followup':'telegram',input:aiInput,instructions:baseInstructions})
    });
    const aiData=await aiResponse.json().catch(()=>({}));
    if(!aiResponse.ok||!aiData?.ok){
      const error=String(aiData?.error||`KeyAI OpenAI HTTP ${aiResponse.status}`);
      await service.from('ks_keyai_enquiries').update({status:'ai_error_manual_review',ai_error:error,updated_at:new Date().toISOString()}).eq('id',rootId);
      if(active)await service.from('ks_keyai_enquiries').update({status:'ai_error_manual_review',ai_error:error}).eq('id',enquiryId);
      await telegramSend(telegramToken,chatId,'Thank you. Your enquiry has been received and saved for manual review.');
      return json({ok:true,id:rootId,openai:true,status:'ai_error_manual_review',error});
    }

    const parsed=parseAiJson(String(aiData.output||''));
    const source=active?`${active.raw_message}\n${text}`:text;
    const result=normaliseResult(parsed,source,existingNormal);
    const summary=summaryFrom(result);
    const questions=strings(result.clarification_questions,3);
    const questionText=questions.join('\n');
    const nextStatus=questions.length?'awaiting_customer':'ai_draft_ready';
    await service.from('ks_keyai_enquiries').update({
      status:nextStatus,ai_model:String(aiData.model||model),ai_summary:summary||null,ai_result:result,ai_error:null,
      clarification_questions:questions,clarification_question:questionText||null,updated_at:new Date().toISOString()
    }).eq('id',rootId);
    if(active)await service.from('ks_keyai_enquiries').update({status:'followup_processed',ai_model:String(aiData.model||model),ai_error:null,updated_at:new Date().toISOString()}).eq('id',enquiryId);

    if(questions.length)await telegramSend(telegramToken,chatId,clarificationText(questions));
    else await telegramSend(telegramToken,chatId,active?'Thank you. KeyAI has updated the quotation requirements and they are ready for review.':'Thank you. Your enquiry has been received. KeyAI has prepared the quotation requirements for review.');
    return json({ok:true,id:rootId,openai:true,status:nextStatus,clarification_questions:questions});
  }catch(error){console.error(error);return json({ok:false,error:error instanceof Error?error.message:String(error)},500)}
});
