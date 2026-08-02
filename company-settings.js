(() => {
  'use strict';

  let access=null,bound=false,selectedCompanyId='',filterMode='all';
  const $=id=>document.getElementById(id);
  const esc=value=>String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  const isOwner=()=>String(access?.role||window.KEYSUITE_ACCESS?.role||'').toLowerCase()==='owner';
  const pct=value=>(Number(value||0)*100).toFixed(2);
  const companies=()=>{
    const data=window.KEYSUITE_SECURE_DATA||{},map=new Map((data.companies||[]).map(row=>[String(row.id),row]));
    for(const raw of data.companyPricingRows||[]){const row=normalizeRow(raw),id=String(row.companyId||'');if(id&&!map.has(id))map.set(id,{id,name:row.companyName||id})}
    return [...map.values()].sort((a,b)=>String(a.name||'').localeCompare(String(b.name||'')));
  };
  const activeCompanyId=()=>String(access?.company_id||window.KEYSUITE_PROFILE?.company_id||'');

  function message(text,type='info'){
    const box=$('companySettingsMessage');if(!box)return;
    box.textContent=text||'';box.className=text?`auth-message show ${type}`:'auth-message';
  }
  function normalizedRows(){
    const source=window.KEYSUITE_SECURE_DATA?.companyPricingRows||[];
    const map=new Map(source.map(row=>[String(row.companyId||row.company_id||''),normalizeRow(row)]));
    return companies().map(company=>map.get(String(company.id))||normalizeRow({company_id:company.id,company_name:company.name,commission:0,set_discount:0,final_discount:0}));
  }
  function selectedSettings(){return normalizedRows().find(row=>String(row.companyId)===String(selectedCompanyId))||null}
  function isNotSet(row){return !(Number(row?.commission)>0)&&!(Number(row?.setDiscount)>0)&&!(Number(row?.finalDiscount)>0)}
  function selectedCompany(){return companies().find(row=>String(row.id)===String(selectedCompanyId))||null}

  function renderCount(){
    const rows=normalizedRows(),missing=rows.filter(isNotSet).length,total=rows.length,box=$('companySetupCount');
    if(box)box.textContent=`Not Set: ${missing} / ${total}`;
  }
  function renderSelect(){
    const select=$('companySettingsCompanySelect');if(!select)return;
    const rows=normalizedRows(),allowedIds=new Set(rows.filter(row=>filterMode!=='not-set'||isNotSet(row)).map(row=>String(row.companyId)));
    const visible=companies().filter(company=>allowedIds.has(String(company.id)));
    if(!visible.some(company=>String(company.id)===String(selectedCompanyId)))selectedCompanyId=String(visible[0]?.id||'');
    select.innerHTML=visible.length?visible.map(company=>`<option value="${esc(company.id)}">${esc(company.name||'Unnamed Company')}</option>`).join(''):'<option value="">No companies match this filter</option>';
    select.value=selectedCompanyId;select.disabled=!isOwner()||!visible.length;
  }
  function renderCompany(){
    const company=selectedCompany(),host=$('companyIdentitySummary');if(!host)return;
    host.innerHTML=company?[
      ['Company Name',company.name||'-'],['Phone',company.phone||'-'],['Address',company.address||'-'],['TIN',company.tin||'-'],['Business Registration No.',company.business_registration_no||'-'],['SST No.',company.sst_no||'-']
    ].map(([label,value])=>`<div class="pricing-kv"><b>${esc(label)}</b><span>${esc(value)}</span></div>`).join(''):'<p class="muted">No company is selected.</p>';
  }
  function renderFields(){
    const data=selectedSettings()||normalizeRow({company_id:selectedCompanyId});
    if($('companyCommissionInput'))$('companyCommissionInput').value=pct(data.commission);
    if($('companySetDiscountInput'))$('companySetDiscountInput').value=pct(data.setDiscount);
    if($('companyFinalDiscountInput'))$('companyFinalDiscountInput').value=pct(data.finalDiscount);
    const disabled=!isOwner()||!selectedCompanyId;
    ['companyCommissionInput','companySetDiscountInput','companyFinalDiscountInput','saveCompanyPricing'].forEach(id=>{if($(id))$(id).disabled=disabled});
  }
  function renderAll(){renderCount();renderSelect();renderCompany();renderFields()}
  function percentInput(id,label){
    const value=Number($(id)?.value);if(!Number.isFinite(value)||value<0||value>=100)throw new Error(`${label} must be from 0% to below 100%.`);return value/100;
  }
  function upsertLocal(row){
    const normalized=normalizeRow(row),data=window.KEYSUITE_SECURE_DATA||(window.KEYSUITE_SECURE_DATA={}),rows=Array.isArray(data.companyPricingRows)?data.companyPricingRows:[];
    const index=rows.findIndex(item=>String(item.companyId||item.company_id)===String(normalized.companyId));
    if(index>=0)rows.splice(index,1,normalized);else rows.push(normalized);data.companyPricingRows=rows;
    if(String(normalized.companyId)===activeCompanyId())data.companyPricing=normalized;
    return normalized;
  }
  async function save(){
    if(!isOwner()){message('Only the Owner can edit Company pricing percentages.','error');return}
    if(!selectedCompanyId){message('Select a company first.','error');return}
    let commission,setDiscount,finalDiscount;
    try{commission=percentInput('companyCommissionInput','Commission');setDiscount=percentInput('companySetDiscountInput','Set Discount');finalDiscount=percentInput('companyFinalDiscountInput','Final Discount')}catch(error){message(error.message,'error');return}
    const button=$('saveCompanyPricing'),original=button?.textContent;if(button){button.disabled=true;button.textContent='Saving…'}message('');
    try{
      const client=window.KeySuiteAuth?.getClient?.();if(!client)throw new Error('Supabase is not connected.');
      const {data,error}=await client.rpc('keysuite_save_company_pricing_v221',{p_company_id:selectedCompanyId,p_commission:commission,p_set_discount:setDiscount,p_final_discount:finalDiscount});if(error)throw error;
      const row=Array.isArray(data)?data[0]:data;const normalized=upsertLocal(row||{company_id:selectedCompanyId,commission,set_discount:setDiscount,final_discount:finalDiscount});
      window.dispatchEvent(new CustomEvent('keysuite-company-pricing-changed',{detail:{companyId:normalized.companyId,settings:normalized}}));
      renderAll();window.KeySuitePricing?.render?.();window.KeySuiteCategories?.render?.();window.KeySuiteAssembly?.refreshPricing?.();message(`Company rates saved for ${selectedCompany()?.name||'the selected company'}.`,'info');
    }catch(error){console.error(error);message(`${error.message||error}. Run V221_SUPABASE_MIGRATION.sql first.`,'error')}
    finally{if(button){button.disabled=false;button.textContent=original}}
  }
  function bind(){
    if(bound)return;bound=true;
    $('companySettingsCompanySelect')?.addEventListener('change',event=>{selectedCompanyId=String(event.target.value||'');renderCompany();renderFields();message('')});
    $('companySetupFilter')?.addEventListener('change',event=>{filterMode=event.target.value==='not-set'?'not-set':'all';renderAll();message('')});
    $('saveCompanyPricing')?.addEventListener('click',save);
  }
  function render(){
    if(!$('companySettings'))return;
    const allowed=isOwner();$('companySettingsOwnerNotice').innerHTML=allowed?`Signed in as <b>${esc(access?.display_name||access?.email||'Owner')}</b>. Choose a company and enter its Commission, Set Discount and Final Discount.`:'Only the Owner can view or edit Company pricing percentages.';
    $('companyPricingEditor').style.display=allowed?'block':'none';
    const toolbar=document.querySelector('.company-settings-toolbar');if(toolbar)toolbar.style.display=allowed?'grid':'none';
    if(!selectedCompanyId)selectedCompanyId=activeCompanyId()||String(companies()[0]?.id||'');renderAll();
  }
  function normalizeRow(row={},fallback={}){
    const q=row.quotation||fallback.quotation||{},a=row.assembly||fallback.assembly||{};
    const commission=Number(row.commission??row.quotation_commission??q.commission??row.assembly_commission??a.commission??0);
    const setDiscount=Number(row.setDiscount??row.set_discount??row.quotation_set_discount??q.setDiscount??0);
    const finalDiscount=Number(row.finalDiscount??row.final_discount??row.quotation_final_discount??q.finalDiscount??row.assembly_final_discount??a.finalDiscount??0);
    const companyId=String(row.companyId??row.company_id??fallback.companyId??'');
    return {companyId,companyName:row.companyName??row.company_name??fallback.companyName??'',commission,setDiscount,finalDiscount,updatedAt:row.updatedAt??row.updated_at??null,
      quotation:{commission,setDiscount,finalDiscount,includeCommission:true,includeSetDiscount:true,includeFinalDiscount:true,includeFuelCharge:true},
      assembly:{commission,setDiscount:0,finalDiscount,includeCommission:true,includeSetDiscount:false,includeFinalDiscount:true,includeFuelCharge:true}};
  }
  function normalizeRows(rows=[],fallback=[]){return (Array.isArray(rows)?rows:rows?[rows]:[]).map((row,index)=>normalizeRow(row,Array.isArray(fallback)?fallback[index]||{}:fallback))}
  function init(data,userAccess){access=userAccess||access;bind();if(!selectedCompanyId)selectedCompanyId=activeCompanyId()||String(companies()[0]?.id||'');render()}
  function pageShown(id){if(id==='companySettings')render()}
  window.KeySuiteCompanySettings={init,pageShown,render,normalizeRow,normalizeRows};
})();
