import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders={
  'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type, x-keyai-internal-secret',
  'Access-Control-Allow-Methods':'POST, OPTIONS'
};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...corsHeaders,'Content-Type':'application/json'}});

Deno.serve(async(req)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:corsHeaders});
  if(req.method!=='POST')return json({ok:false,error:'POST required.'},405);
  try{
    const supabaseUrl=Deno.env.get('SUPABASE_URL')||'';
    const anonKey=Deno.env.get('SUPABASE_ANON_KEY')||'';
    const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||'';
    const openAiKey=Deno.env.get('OPENAI_API_KEY')||'';
    if(!supabaseUrl||!anonKey||!serviceKey)throw new Error('Supabase Edge Function environment is incomplete.');
    const service=createClient(supabaseUrl,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
    const body=await req.json().catch(()=>({}));
    const mode=String(body?.mode||'process').toLowerCase();

    let requestedBy='';let authorised=false;let owner=false;
    const internalSecret=Deno.env.get('KEYAI_INTERNAL_SECRET')||'';
    const suppliedInternal=req.headers.get('x-keyai-internal-secret')||'';
    if(internalSecret&&suppliedInternal&&suppliedInternal===internalSecret){authorised=true;requestedBy='keyai-internal';}
    if(!authorised){
      const authHeader=req.headers.get('Authorization')||'';
      if(!authHeader.toLowerCase().startsWith('bearer '))return json({ok:false,error:'Authorisation required.'},401);
      const userClient=createClient(supabaseUrl,anonKey,{global:{headers:{Authorization:authHeader}},auth:{persistSession:false,autoRefreshToken:false}});
      const userResult=await userClient.auth.getUser();
      const email=String(userResult.data?.user?.email||'').toLowerCase();
      if(!email)return json({ok:false,error:'Invalid KeySuite session.'},401);
      const accessResult=await service.from('ks_user_access').select('role,active').eq('email',email).eq('active',true).limit(1).maybeSingle();
      if(accessResult.error||!accessResult.data?.active)return json({ok:false,error:'KeySuite access is not active.'},403);
      requestedBy=email;owner=String(accessResult.data.role||'').toLowerCase()==='owner';authorised=true;
    }
    if(mode==='test'&&!owner&&requestedBy!=='keyai-internal')return json({ok:false,error:'Only the Owner can test the OpenAI connection.'},403);

    const settingsResult=await service.from('ks_app_settings').select('keyai_openai_enabled,keyai_openai_model,keyai_monthly_request_limit').eq('id','default').maybeSingle();
    if(settingsResult.error)throw settingsResult.error;
    const settings=settingsResult.data||{};
    const enabled=!!settings.keyai_openai_enabled;
    const model=String(settings.keyai_openai_model||'gpt-5-mini');
    const monthlyLimit=Math.max(0,Number(settings.keyai_monthly_request_limit||0));
    if(!enabled)return json({ok:false,enabled:false,error:'KeyAI OpenAI is switched OFF by the Owner.'},409);
    if(!openAiKey)return json({ok:false,enabled:true,error:'OPENAI_API_KEY is not configured in Supabase Edge Function secrets.'},500);

    if(monthlyLimit>0){
      const start=new Date();start.setUTCDate(1);start.setUTCHours(0,0,0,0);
      const countResult=await service.from('ks_keyai_usage').select('id',{count:'exact',head:true}).gte('created_at',start.toISOString());
      if(countResult.error)throw countResult.error;
      if(Number(countResult.count||0)>=monthlyLimit)return json({ok:false,enabled:true,error:`KeyAI monthly request limit (${monthlyLimit}) has been reached.`},429);
    }

    const input=mode==='test'?'Reply exactly with: KeyAI OpenAI connection OK':String(body?.input||'').trim();
    if(!input)return json({ok:false,error:'No KeyAI input was supplied.'},400);
    const instructions=String(body?.instructions||'You are KeyAI for KeySuite. Understand customer pump and quotation enquiries. Do not invent engineering selections, prices, discounts or commercial terms. Return clear information for KeySuite/KeyES to process.');
    const response=await fetch('https://api.openai.com/v1/responses',{
      method:'POST',headers:{'Authorization':`Bearer ${openAiKey}`,'Content-Type':'application/json'},
      body:JSON.stringify({model,instructions,input,max_output_tokens:mode==='test'?40:1200})
    });
    const data=await response.json().catch(()=>({}));
    if(!response.ok)return json({ok:false,error:String(data?.error?.message||`OpenAI HTTP ${response.status}`),model},502);
    const outputText=String(data?.output_text||data?.output?.flatMap((item:any)=>item?.content||[]).find((part:any)=>part?.type==='output_text')?.text||'').trim();
    const usage=data?.usage||{};
    await service.from('ks_keyai_usage').insert({provider:'openai',model,purpose:mode,requested_by:requestedBy,input_tokens:Number(usage.input_tokens||0),output_tokens:Number(usage.output_tokens||0)});
    return json({ok:true,enabled:true,model,output:outputText,usage:{input_tokens:Number(usage.input_tokens||0),output_tokens:Number(usage.output_tokens||0)}});
  }catch(error){console.error(error);return json({ok:false,error:error instanceof Error?error.message:String(error)},500)}
});
