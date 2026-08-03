(() => {
  'use strict';
  const state={prefix:''};
  const client=()=>window.KeySuiteAuth?.getClient?.()||null;
  const row=value=>Array.isArray(value)?(value[0]||{}):(value||{});
  function normalizePrefix(value){return String(value||'').trim().toUpperCase()}
  function validatePrefix(value){const prefix=normalizePrefix(value);if(!/^[A-Z0-9]{1,8}$/.test(prefix))throw new Error('Quotation prefix must contain 1 to 8 letters or numbers only.');return prefix}
  function parseReference(value){
    const match=String(value||'').trim().toUpperCase().match(/^([A-Z0-9]{1,8})-(\d{4})-(\d{1,4})(-V\d+)?$/);
    return match?{prefix:match[1],yymm:match[2],running:Number(match[3])||0,suffix:match[4]||''}:null;
  }
  function scanRunningFloor(prefix,date=new Date()){
    if(!prefix||typeof localStorage==='undefined')return 0;
    const yy=String(date.getFullYear()).slice(-2),safe=String(prefix).replace(/[.*+?^${}()|[\]\\]/g,'\\$&'),rx=new RegExp(`^${safe}-${yy}\\d{2}-(\\d+)(?:-V\\d+)?$`,'i');let maximum=0;
    const visit=value=>{if(typeof value==='string'){const match=value.match(rx);if(match)maximum=Math.max(maximum,Number(match[1])||0);return}if(Array.isArray(value)){value.forEach(visit);return}if(value&&typeof value==='object')Object.values(value).forEach(visit)};
    for(let index=0;index<localStorage.length;index++){const key=localStorage.key(index),value=localStorage.getItem(key);try{visit(JSON.parse(value))}catch(_){visit(value)}}
    return maximum;
  }
  async function getPrefix(){
    const supabase=client();if(!supabase)return state.prefix;
    const {data,error}=await supabase.rpc('keysuite_get_quotation_prefix_v223');if(error)throw error;
    state.prefix=normalizePrefix(row(data).quotation_prefix||row(data).quotationPrefix);return state.prefix;
  }
  async function savePrefix(){throw new Error('Quotation prefixes are assigned by the Owner under Key → Role.')}
  async function allocateNext(){
    const supabase=client();if(!supabase)throw new Error('Supabase is not connected.');
    const prefix=state.prefix||await getPrefix();if(!prefix)throw new Error('No quotation prefix has been assigned. Please contact the Owner.');
    const floor=scanRunningFloor(prefix),{data,error}=await supabase.rpc('keysuite_next_quotation_reference_v223',{p_minimum_last_number:floor});if(error)throw error;
    const reference=String(row(data).quotation_reference||row(data).quotationReference||'');if(!reference)throw new Error('Quotation reference could not be allocated.');return reference;
  }
  async function registerUsed(reference){
    const parsed=parseReference(reference);if(!parsed)return null;
    const supabase=client();if(!supabase)return parsed;
    const {data,error}=await supabase.rpc('keysuite_register_quotation_reference_v226',{p_reference:String(reference||'').trim().toUpperCase()});if(error)throw error;
    return row(data);
  }
  async function init(profile={}){state.prefix=normalizePrefix(profile.quotation_prefix);if(!state.prefix){try{await getPrefix()}catch(error){console.warn('Quotation prefix is not available yet.',error)}}return state.prefix}
  window.KeySuiteQuotationReferences={init,getPrefix,savePrefix,allocateNext,registerUsed,scanRunningFloor,parseReference,validatePrefix,getState:()=>({...state})};
})();
