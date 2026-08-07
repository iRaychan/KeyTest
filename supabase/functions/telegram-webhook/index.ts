import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json'}});
const env=(...names:string[])=>{for(const name of names){const value=Deno.env.get(name);if(value)return value}return ''};

async function telegramSend(token:string,chatId:string,text:string){
  if(!token||!chatId)return;
  const response=await fetch(`https://api.telegram.org/bot${token}/sendMessage`,{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({chat_id:chatId,text})
  });
  if(!response.ok){const detail=await response.text().catch(()=>response.statusText);console.error('Telegram sendMessage failed',response.status,detail)}
}

function parseAiJson(text:string){
  const cleaned=String(text||'').trim().replace(/^```(?:json)?\s*/i,'').replace(/\s*```$/,'').trim();
  if(!cleaned)return null;
  try{return JSON.parse(cleaned)}catch(_){return {summary:cleaned,raw_output:cleaned}}
}

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
    if(!text){
      await telegramSend(telegramToken,chatId,'Thank you. Please send your pump or quotation enquiry as a text message.');
      return json({ok:true,ignored:true,reason:'non-text'});
    }

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

    const insertResult=await service.from('ks_keyai_enquiries').insert({
      source:'telegram',external_update_id:updateId,external_message_id:Number(message?.message_id||0)||null,
      external_chat_id:chatId,sender_username:senderUsername||null,sender_name:senderName||null,
      raw_message:text,status:openAiEnabled?'processing':'ai_disabled_manual_review',ai_enabled:openAiEnabled,ai_model:openAiEnabled?model:null
    }).select('id').single();
    if(insertResult.error)throw insertResult.error;
    const enquiryId=insertResult.data.id;

    if(!openAiEnabled){
      await telegramSend(telegramToken,chatId,'Thank you. Your enquiry has been received. AI processing is currently disabled. Your enquiry has been saved for manual review.');
      return json({ok:true,id:enquiryId,openai:false,status:'ai_disabled_manual_review'});
    }

    if(!internalSecret){
      const error='KEYAI_INTERNAL_SECRET is not configured.';
      await service.from('ks_keyai_enquiries').update({status:'ai_error_manual_review',ai_error:error,updated_at:new Date().toISOString()}).eq('id',enquiryId);
      await telegramSend(telegramToken,chatId,'Thank you. Your enquiry has been received and saved for manual review.');
      return json({ok:true,id:enquiryId,openai:true,status:'ai_error_manual_review',error});
    }

    const instructions=`You are KeyAI for KeySuite. Read a customer pump/system enquiry and extract requirements only. Do not select a pump model, calculate engineering performance, calculate prices, discounts, margins, commercial terms, or send a quotation. Return ONLY a valid JSON object with these keys: summary, application, system_type, pump_quantity, duty_configuration, flow_value, flow_unit, head_value, head_unit, material, voltage, phase, frequency_hz, missing_information, notes. Use null for unknown scalar values and [] for no missing information. Keep summary concise.`;
    const aiResponse=await fetch(`${supabaseUrl}/functions/v1/keyai-openai`,{
      method:'POST',
      headers:{'Content-Type':'application/json','Authorization':`Bearer ${serviceKey}`,'x-keyai-internal-secret':internalSecret},
      body:JSON.stringify({mode:'telegram',input:text,instructions})
    });
    const aiData=await aiResponse.json().catch(()=>({}));
    if(!aiResponse.ok||!aiData?.ok){
      const error=String(aiData?.error||`KeyAI OpenAI HTTP ${aiResponse.status}`);
      await service.from('ks_keyai_enquiries').update({status:'ai_error_manual_review',ai_error:error,updated_at:new Date().toISOString()}).eq('id',enquiryId);
      await telegramSend(telegramToken,chatId,'Thank you. Your enquiry has been received and saved for manual review.');
      return json({ok:true,id:enquiryId,openai:true,status:'ai_error_manual_review',error});
    }

    const result=parseAiJson(String(aiData.output||''));
    const summary=summaryFrom(result);
    await service.from('ks_keyai_enquiries').update({
      status:'ai_draft_ready',ai_model:String(aiData.model||model),ai_summary:summary||null,ai_result:result,ai_error:null,updated_at:new Date().toISOString()
    }).eq('id',enquiryId);
    await telegramSend(telegramToken,chatId,'Thank you. Your enquiry has been received. KeyAI has prepared the quotation requirements for review.');
    return json({ok:true,id:enquiryId,openai:true,status:'ai_draft_ready'});
  }catch(error){
    console.error(error);return json({ok:false,error:error instanceof Error?error.message:String(error)},500);
  }
});
