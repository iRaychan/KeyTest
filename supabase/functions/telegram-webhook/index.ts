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
  const cleaned=String(text||'').trim().replace(/^```(?:json)?\s*/i,'').replace(/\s*```$/,'').trim();
  if(!cleaned)return null;
  try{return JSON.parse(cleaned)}catch(_){return {summary:cleaned,raw_output:cleaned,clarification_questions:[]}}
}
function strings(value:any,max=20){return (Array.isArray(value)?value:[]).map(v=>String(v||'').trim()).filter(Boolean).filter((v,i,a)=>a.indexOf(v)===i).slice(0,max)}
function clarificationQuestions(result:any){return strings(result?.clarification_questions,3)}
function summaryFrom(result:any){
  if(!result)return '';
  if(typeof result.summary==='string'&&result.summary.trim())return result.summary.trim();
  const parts:string[]=[];
  if(result.application)parts.push(String(result.application));
  if(result.system_type)parts.push(String(result.system_type));
  if(result.flow_value)parts.push(`${result.flow_value} ${result.flow_unit||''}`.trim());
  if(result.head_value)parts.push(`${result.head_value} ${result.head_unit||''}`.trim());
  return parts.join(' · ');
}
function clarificationText(questions:string[]){
  if(!questions.length)return '';
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

    // A reply within 7 days is attached to the most recent enquiry that is waiting for customer clarification.
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

    const baseInstructions=`You are KeyAI for KeySuite. Extract and update customer pump/system quotation requirements only. Do not select a pump model, calculate engineering performance, calculate prices, discounts, margins, commercial terms, or send a quotation. Return ONLY one valid JSON object with these keys: summary, application, system_type, pump_quantity, duty_configuration, flow_value, flow_unit, flow_basis, head_value, head_unit, material, voltage, phase, frequency_hz, critical_missing_information, missing_information, clarification_questions, notes. Use null for unknown scalar values and [] for empty arrays. flow_basis must be one of total_system, per_duty_pump, or null. clarification_questions must contain at most 3 concise customer-facing questions and ONLY questions needed to resolve a real ambiguity or information that blocks duty interpretation. For multiple-duty-pump systems, if the flow basis is unclear, ask whether the stated flow is total system flow or flow per duty pump. Do not ask for fluid temperature, viscosity, solids content, or detailed fluid properties for an ordinary booster/transfer water enquiry unless the customer indicates a non-water or special-fluid application. Missing material may be recorded but does not by itself block preparation because KeySuite can use its standard material defaults. Preserve facts already confirmed by the customer. Keep the summary concise.`;
    const aiInput=active
      ?`Existing extracted requirements:\n${JSON.stringify(active.ai_result||{},null,2)}\n\nPrevious KeyAI clarification:\n${String(active.clarification_question||'')}\n\nCustomer follow-up reply:\n${text}\n\nMerge the reply into the existing requirements. Remove resolved items from critical_missing_information and clarification_questions.`
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

    const result=parseAiJson(String(aiData.output||''));
    const summary=summaryFrom(result);
    const questions=clarificationQuestions(result);
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
