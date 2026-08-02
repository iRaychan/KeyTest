(() => {
  'use strict';

  let access=null,bound=false,mode='quotation';
  const $=id=>document.getElementById(id);
  const esc=value=>String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  const isOwner=()=>String(access?.role||window.KEYSUITE_ACCESS?.role||'').toLowerCase()==='owner';
  const pct=value=>(Number(value||0)*100).toFixed(2);
  const currentCompany=()=>{
    const id=String(access?.company_id||window.KEYSUITE_PROFILE?.company_id||'');
    return (window.KEYSUITE_SECURE_DATA?.companies||[]).find(row=>String(row.id)===id)||null;
  };
  const settings=()=>window.KEYSUITE_SECURE_DATA?.companyPricing||{
    companyId:String(access?.company_id||''),
    quotation:{commission:.03,setDiscount:.068,finalDiscount:.08,includeCommission:true,includeSetDiscount:true,includeFinalDiscount:true,includeFuelCharge:true},
    assembly:{commission:.03,setDiscount:0,finalDiscount:.08,includeCommission:true,includeSetDiscount:false,includeFinalDiscount:true,includeFuelCharge:true}
  };

  function message(text,type='info'){
    const box=$('companySettingsMessage');if(!box)return;
    box.textContent=text||'';box.className=text?`auth-message show ${type}`:'auth-message';
  }
  function setTabs(){
    document.querySelectorAll('[data-company-factor-mode]').forEach(button=>{
      const active=button.dataset.companyFactorMode===mode;
      button.classList.toggle('active',active);button.setAttribute('aria-selected',String(active));
    });
  }
  function renderCompany(){
    const company=currentCompany(),host=$('companyIdentitySummary');if(!host)return;
    host.innerHTML=company?[
      ['Company Name',company.name||'-'],['Phone',company.phone||'-'],['Address',company.address||'-'],['TIN',company.tin||'-'],['Business Registration No.',company.business_registration_no||'-'],['SST No.',company.sst_no||'-']
    ].map(([label,value])=>`<div class="pricing-kv"><b>${esc(label)}</b><span>${esc(value)}</span></div>`).join(''):'<p class="muted">No company record is linked to this account.</p>';
  }
  function renderFields(){
    const data=settings()[mode]||{};
    $('companyCommissionInput').value=pct(data.commission);
    $('companyFinalDiscountInput').value=pct(data.finalDiscount);
    $('companyCommissionEnabled').checked=data.includeCommission!==false;
    $('companyFinalDiscountEnabled').checked=data.includeFinalDiscount!==false;
    $('companyFuelChargeEnabled').checked=data.includeFuelCharge!==false;
    const setRow=$('companySetDiscountRow');if(setRow)setRow.style.display=mode==='quotation'?'grid':'none';
    if(mode==='quotation'){
      $('companySetDiscountInput').value=pct(data.setDiscount);
      $('companySetDiscountEnabled').checked=data.includeSetDiscount!==false;
    }
    const heading=$('companyFactorHeading');if(heading)heading.textContent=`${mode==='assembly'?'Assembly':'Quotation'} Factors`;
    const note=$('companyFactorNote');if(note)note.textContent=mode==='assembly'?'Assembly pricing excludes Set Discount.':'Quotation pricing uses the existing company factors, including Set Discount.';
    const formula=$('companyFactorFormula');if(formula){
      const parts=['Category Margin','Category Normal / Rare','Category Transport'];
      if(data.includeCommission!==false)parts.push('Company Commission');
      if(mode==='quotation'&&data.includeSetDiscount!==false)parts.push('Company Set Discount');
      if(data.includeFinalDiscount!==false)parts.push('Company Final Discount');
      if(data.includeFuelCharge!==false)parts.push('Company Fuel Charge');
      parts.push('Round up to RM10');formula.textContent=parts.join(' → ');
    }
    setTabs();
  }
  function percentInput(id,label){
    const value=Number($(id)?.value);if(!Number.isFinite(value)||value<0||value>=100)throw new Error(`${label} must be from 0% to below 100%.`);return value/100;
  }
  function applyVisibleTo(next){
    const target=next[mode];target.commission=percentInput('companyCommissionInput','Commission');target.finalDiscount=percentInput('companyFinalDiscountInput','Final Discount');
    target.includeCommission=!!$('companyCommissionEnabled')?.checked;target.includeFinalDiscount=!!$('companyFinalDiscountEnabled')?.checked;target.includeFuelCharge=!!$('companyFuelChargeEnabled')?.checked;
    if(mode==='quotation'){target.setDiscount=percentInput('companySetDiscountInput','Set Discount');target.includeSetDiscount=!!$('companySetDiscountEnabled')?.checked}
    else{target.setDiscount=0;target.includeSetDiscount=false}
  }
  function cloneSettings(){
    const raw=settings();return {companyId:raw.companyId||String(access?.company_id||''),quotation:{...raw.quotation},assembly:{...raw.assembly}};
  }
  async function save(){
    if(!isOwner()){message('Only the Owner can edit Company pricing factors.','error');return}
    const next=cloneSettings();try{applyVisibleTo(next)}catch(error){message(error.message,'error');return}
    const button=$('saveCompanyPricing'),original=button?.textContent;if(button){button.disabled=true;button.textContent='Saving…'}message('');
    try{
      const client=window.KeySuiteAuth?.getClient?.();if(!client)throw new Error('Supabase is not connected.');
      const payload={
        quotation_commission:next.quotation.commission,quotation_set_discount:next.quotation.setDiscount,quotation_final_discount:next.quotation.finalDiscount,
        quotation_include_commission:next.quotation.includeCommission,quotation_include_set_discount:next.quotation.includeSetDiscount,quotation_include_final_discount:next.quotation.includeFinalDiscount,quotation_include_fuel_charge:next.quotation.includeFuelCharge,
        assembly_commission:next.assembly.commission,assembly_final_discount:next.assembly.finalDiscount,
        assembly_include_commission:next.assembly.includeCommission,assembly_include_final_discount:next.assembly.includeFinalDiscount,assembly_include_fuel_charge:next.assembly.includeFuelCharge
      };
      const {data,error}=await client.rpc('keysuite_save_company_pricing_v220',{p_settings:payload});if(error)throw error;
      const row=Array.isArray(data)?data[0]:data;window.KEYSUITE_SECURE_DATA.companyPricing=window.KeySuiteCompanySettings.normalizeRow(row,next);
      window.dispatchEvent(new CustomEvent('keysuite-company-pricing-changed',{detail:{settings:window.KEYSUITE_SECURE_DATA.companyPricing}}));
      renderFields();window.KeySuitePricing?.render?.();window.KeySuiteAssembly?.refreshPricing?.();message(`${mode==='assembly'?'Assembly':'Quotation'} factors saved.`,'info');
    }catch(error){console.error(error);message(`${error.message||error}. Run V220_SUPABASE_MIGRATION.sql first.`,'error')}
    finally{if(button){button.disabled=false;button.textContent=original}}
  }
  function bind(){
    if(bound)return;bound=true;
    document.querySelectorAll('[data-company-factor-mode]').forEach(button=>button.addEventListener('click',()=>{
      const next=cloneSettings();try{applyVisibleTo(next);window.KEYSUITE_SECURE_DATA.companyPricing=next}catch(_){ }
      mode=button.dataset.companyFactorMode==='assembly'?'assembly':'quotation';renderFields();message('');
    }));
    $('saveCompanyPricing')?.addEventListener('click',save);
  }
  function render(){
    if(!$('companySettings'))return;
    const allowed=isOwner();$('companySettingsOwnerNotice').innerHTML=allowed?`Signed in as <b>${esc(access?.display_name||access?.email||'Owner')}</b>. Company pricing factors are visible only to the Owner.`:'Only the Owner can open and maintain Company pricing factors.';
    $('companyPricingEditor').style.display=allowed?'block':'none';renderCompany();if(allowed)renderFields();
  }
  function normalizeRow(row={},fallback={}){
    const q=fallback.quotation||{},a=fallback.assembly||{};
    return {companyId:row.company_id||fallback.companyId||'',quotation:{commission:Number(row.quotation_commission??q.commission??.03),setDiscount:Number(row.quotation_set_discount??q.setDiscount??.068),finalDiscount:Number(row.quotation_final_discount??q.finalDiscount??.08),includeCommission:row.quotation_include_commission??q.includeCommission??true,includeSetDiscount:row.quotation_include_set_discount??q.includeSetDiscount??true,includeFinalDiscount:row.quotation_include_final_discount??q.includeFinalDiscount??true,includeFuelCharge:row.quotation_include_fuel_charge??q.includeFuelCharge??true},assembly:{commission:Number(row.assembly_commission??a.commission??q.commission??.03),setDiscount:0,finalDiscount:Number(row.assembly_final_discount??a.finalDiscount??q.finalDiscount??.08),includeCommission:row.assembly_include_commission??a.includeCommission??q.includeCommission??true,includeSetDiscount:false,includeFinalDiscount:row.assembly_include_final_discount??a.includeFinalDiscount??q.includeFinalDiscount??true,includeFuelCharge:row.assembly_include_fuel_charge??a.includeFuelCharge??q.includeFuelCharge??true}};
  }
  function init(data,userAccess){access=userAccess||access;bind();render()}
  function pageShown(id){if(id==='companySettings')render()}
  window.KeySuiteCompanySettings={init,pageShown,render,normalizeRow};
})();
