(() => {
  'use strict';

  let access=null;
  let selectedId='';
  let selectedProduct='CHC';
  let editing=false;
  let bound=false;

  const byId=id=>document.getElementById(id);
  const esc=value=>String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  const num=(value,d=2)=>Number(value||0).toLocaleString('en-MY',{minimumFractionDigits:d,maximumFractionDigits:d});
  const permissionLevel=key=>window.KeySuitePermissions?.level?.(key,String(access?.role||window.KEYSUITE_ACCESS?.role||'viewer').toLowerCase())||'none';
  const canView=()=>permissionLevel('manage_categories')!=='none';
  const isOwner=()=>permissionLevel('manage_categories')==='full';
  const categories=()=>window.KEYSUITE_SECURE_DATA?.categories||[];

  const defaultRule=()=>({margin:.38,normal:0,rare:0,transport:30});
  const newCategoryRule=()=>({margin:0,normal:0,rare:0,transport:0});

  function message(text,type='info'){
    const box=byId('categoryMessage');if(!box)return;
    box.textContent=text||'';box.className=text?`auth-message show ${type}`:'auth-message';
  }

  function normalizeRule(rule={},fallback=defaultRule()){
    return {margin:Number(rule.margin??fallback.margin),normal:Number(rule.normal??fallback.normal??0),rare:Number(rule.rare??fallback.rare??0),transport:Number(rule.transport??fallback.transport)};
  }

  function ruleFor(category,product=selectedProduct){
    const fallback=defaultRule();
    if(product==='CHC'){
      fallback.margin=Number(category?.margins?.CHC??category?.factors?.CHC??fallback.margin);fallback.transport=Number(category?.transport??fallback.transport);
    }
    return normalizeRule(category?.productRules?.[product]||{},fallback);
  }

  function currentCategory(){return categories().find(item=>item.id===selectedId)||null}

  function productRates(product=selectedProduct){
    const data=window.KEYSUITE_SECURE_DATA||{},family=String(product||'CHC').toUpperCase(),rates=data.productMultipliers?.[family]||{};
    return {USD:Number(rates.USD??data.usd_multiplier??5.8),RMB:Number(rates.RMB??data.rmb_multiplier??.65),MYR:1};
  }

  function setRuleFieldsEditable(on){
    document.querySelectorAll('#categoryForm .category-lock-field').forEach(group=>{
      group.classList.toggle('unlocked',!!on);group.classList.toggle('locked',!on);
      group.querySelectorAll('input').forEach(input=>{if(input.type==='checkbox')input.disabled=!on;else input.readOnly=input.dataset.alwaysReadonly==='true'?true:!on});
    });
  }

  function setEditable(on){
    editing=!!on;
    const name=byId('categoryNameInput');if(name)name.disabled=!editing;
    const edit=byId('editCategoryRule');if(edit){edit.style.display=isOwner()&&selectedId&&!editing?'inline-block':'none';edit.textContent='Hold 3s to Edit'}
    const save=byId('saveCategoryRule');if(save)save.disabled=!editing;
    const cancel=byId('cancelCategoryEdit');if(cancel)cancel.disabled=!editing;
    byId('categoryForm')?.classList.toggle('category-form-readonly',!editing);setRuleFieldsEditable(editing);
  }

  function showCurrencySummary(){
    const rates=productRates(),box=byId('categoryCurrencySummary');
    if(box)box.innerHTML=`<b>${esc(selectedProduct)} Price List Currency</b><span>USD (MYR ${num(rates.USD,2)})</span><span>RMB (MYR ${num(rates.RMB,2)})</span><span>MYR (MYR 1.00)</span>`;
  }

  function quotationFactors(){return window.KEYSUITE_SECURE_DATA?.companyPricing?.quotation||{commission:.03,setDiscount:.068,finalDiscount:.08,includeCommission:true,includeSetDiscount:true,includeFinalDiscount:true,includeFuelCharge:true}}
  function formulaText(rule,rarity){
    const company=quotationFactors(),parts=['Highest of USD × USD rate / RMB × RMB rate / MYR','÷ (1 − Margin)'];
    if(rarity==='common'||rarity==='rare')parts.push('÷ (1 − Normal)');if(rarity==='rare')parts.push('÷ (1 − Rare)');parts.push('+ Transport');
    if(company.includeCommission!==false)parts.push('÷ (1 − Company Commission)');if(company.includeSetDiscount!==false)parts.push('÷ (1 − Company Set Discount)');if(company.includeFinalDiscount!==false)parts.push('÷ (1 − Company Final Discount)');if(company.includeFuelCharge!==false)parts.push('+ Company Fuel Charge');parts.push('Round up to RM10');return parts.join('  →  ');
  }

  function updateFormula(){
    const rule=readRule(false),box=byId('categoryFormulaPreview');if(!box)return;
    box.innerHTML=`<div class="category-formula-lines"><div class="category-formula-line"><b>Many</b>${esc(formulaText(rule,'many'))}</div><div class="category-formula-line"><b>Common</b>${esc(formulaText(rule,'common'))}</div><div class="category-formula-line"><b>Rare</b>${esc(formulaText(rule,'rare'))}</div></div>`;
    updateManualQuote();
  }

  function manualCategory(){
    const base=currentCategory()||{id:'manual',name:'Manual',productRules:{}};
    return {...base,productRules:{...(base.productRules||{}),[selectedProduct]:readRule(false)}};
  }

  function updateManualQuote(){
    const valueBox=byId('categoryManualQuotedValue'),detail=byId('categoryManualBreakdown');if(!valueBox||!detail)return;
    const source=Number(byId('categoryManualCost')?.value),currency=String(byId('categoryManualCurrency')?.value||'USD').toUpperCase(),rarity=String(byId('categoryManualRarity')?.value||'common').toLowerCase();
    if(!Number.isFinite(source)||source<=0){valueBox.textContent='RM 0.00';detail.textContent='Enter a cost figure to calculate.';return}
    const customer=window.KeySuiteApp?.getPricingCustomer?.()||window.KeySuiteApp?.getSelectedCustomer?.()||null;
    const calc=window.KeySuitePricing?.calculateManual?.(source,currency,rarity,manualCategory(),selectedProduct,{customer});
    if(!calc){valueBox.textContent='RM 0.00';detail.textContent='Unable to calculate with the current pricing rule.';return}
    const rarityName={many:'Many',common:'Common',rare:'Rare'}[rarity]||'Common';
    valueBox.textContent=`RM ${num(calc.finalPrice,2)}`;
    detail.textContent=`${currency} ${num(source,2)} × ${num(calc.multiplier,4)} = RM ${num(calc.baseMyr,2)} · ${rarityName} · Fuel RM ${num(calc.fuelCharge,2)} · rounded up to RM10${customer?` · ${customer.company||'active customer'}`:' · no active customer (fuel distance 0 km)'}`;
  }

  function fillRule(category){
    const rule=category?ruleFor(category,selectedProduct):newCategoryRule();
    byId('categoryMarginInput').value=num(rule.margin*100,2).replace(/,/g,'');byId('categoryNormalInput').value=num(rule.normal*100,2).replace(/,/g,'');byId('categoryRareInput').value=num(rule.rare*100,2).replace(/,/g,'');byId('categoryTransportInput').value=num(rule.transport,2).replace(/,/g,'');
    byId('categoryProductHeading').textContent=`${selectedProduct} Pricing Rule`;if(byId('categoryMarginLabel'))byId('categoryMarginLabel').textContent=`${selectedProduct} Margin`;
    document.querySelectorAll('[data-category-product]').forEach(button=>button.classList.toggle('active',button.dataset.categoryProduct===selectedProduct));
    setRuleFieldsEditable(editing);showCurrencySummary();updateFormula();
  }

  function fill(category=null){
    selectedId=category?.id||'';const name=category?.name||'';
    byId('categoryFormTitle').textContent=category?'Edit Category':'New Category';byId('categorySelectedName').textContent=category?name:'New Category';byId('categoryNameInput').value=name;fillRule(category);renderRows();
  }

  function openCategory(category,forEdit=false){if(!category)return;fill(category);setEditable(forEdit);message(forEdit?'Editing enabled. All category fields are unlocked.':'Category loaded. Hold the Edit button for 3 seconds to unlock all fields.','info')}

  function newCategory(){if(!isOwner()){message('Your role has view-only Category access.','error');return}selectedProduct='CHC';fill(null);setEditable(true);message('New category ready. All values start at 0.00 and are ready to edit.','info');setTimeout(()=>byId('categoryNameInput')?.focus(),0)}

  function renderRows(){
    const body=byId('categoryRows');if(!body)return;const rows=categories();
    if(!rows.length){body.innerHTML='<tr><td class="category-empty">No pricing categories yet.</td></tr>';return}
    body.innerHTML=rows.map(category=>{const name=String(category.name||category.category_name||'Unnamed Category').trim()||'Unnamed Category';return `<tr class="${category.id===selectedId?'category-row-selected':''}"><td><button class="category-name-button ${category.id===selectedId?'active':''}" type="button" data-category-open="${esc(category.id)}"><span>${esc(name)}</span></button></td></tr>`}).join('');
  }

  function mapRows(rows){
    return (rows||[]).map(c=>{
      let rules=c.product_rules||{};if(typeof rules==='string'){try{rules=JSON.parse(rules)}catch(_){rules={}}}
      const normalize=code=>normalizeRule(rules?.[code]||{},code==='CHC'?{margin:Number(c.chc_margin??c.chc_factor??.38),normal:0,rare:0,transport:Number(c.transport??30)}:{margin:0,normal:0,rare:0,transport:0});
      return {id:c.id,name:String(c.category_name||c.name||'Unnamed Category'),productRules:{CHC:normalize('CHC'),ES:normalize('ES'),GWS:normalize('GWS'),KEYPLC:normalize('KEYPLC'),MANIFOLD:normalize('MANIFOLD')},margins:{CHC:Number(c.chc_margin??c.chc_factor??0)},factors:{CHC:Number(c.chc_margin??c.chc_factor??0)},transport:Number(c.transport||0)};
    });
  }

  async function reload(){
    const client=window.KeySuiteAuth?.getClient?.();if(!client)return [];
    const {data,error}=await client.from('ks_pricing_categories').select('*').order('category_name');if(error)throw error;
    const mapped=mapRows(data),target=window.KEYSUITE_SECURE_DATA?.categories;if(Array.isArray(target))target.splice(0,target.length,...mapped);window.KeySuitePricing?.render?.();return mapped;
  }

  function percentValue(id,label,validate=true){const value=Number(byId(id)?.value);if(validate&&(!Number.isFinite(value)||value<0||value>=100))throw new Error(`${label} must be from 0% to below 100%.`);return Number.isFinite(value)?value/100:0}
  function readRule(validate=true){const transport=Number(byId('categoryTransportInput')?.value||0);if(validate&&(!Number.isFinite(transport)||transport<0))throw new Error('Transport must be RM0.00 or more.');return {margin:percentValue('categoryMarginInput',`${selectedProduct} Margin`,validate),normal:percentValue('categoryNormalInput','Normal',validate),rare:percentValue('categoryRareInput','Rare',validate),transport:Number.isFinite(transport)?transport:0}}

  async function save(event){
    event.preventDefault();if(!editing)return;if(!isOwner()){message('Your role is not allowed to edit pricing categories.','error');return}
    const name=byId('categoryNameInput').value.trim();if(!name){message('Category Name is required.','error');return}
    let rule;try{rule=readRule(true)}catch(error){message(error.message,'error');return}
    const client=window.KeySuiteAuth?.getClient?.();if(!client){message('Supabase is not connected.','error');return}
    const button=byId('saveCategoryRule'),original=button.textContent;button.disabled=true;button.textContent='Saving…';message('');
    try{
      const {error}=await client.rpc('keysuite_manage_pricing_category_v220',{p_category_id:selectedId||null,p_category_name:name,p_product_code:selectedProduct,p_margin:rule.margin,p_normal:rule.normal,p_rare:rule.rare,p_transport:rule.transport});
      if(error)throw error;const rows=await reload(),saved=(rows||categories()).find(item=>item.name.toLowerCase()===name.toLowerCase());openCategory(saved||rows[0],false);message(`${selectedProduct} pricing rule for “${name}” saved.`,'info');
    }catch(error){console.error(error);message(`${error.message||error}. Run V220_SUPABASE_MIGRATION.sql first.`,'error')}
    finally{button.disabled=false;button.textContent=original}
  }

  function cancel(){if(selectedId){const category=currentCategory();if(category)openCategory(category,false)}else{const first=categories()[0];if(first)openCategory(first,false);else newCategory()}}

  function unlockCategoryEditor(){
    if(!isOwner()||!selectedId)return;
    setEditable(true);message('All category fields unlocked. Edit the values, then press Save Category or Cancel.','info');byId('categoryNameInput')?.focus();byId('categoryNameInput')?.select();
  }

  function bindEditLongHold(target,callback){
    let timer=null,progress=null,start=0;const idle='Hold 3s to Edit';
    const stop=(restore=true)=>{if(timer)clearTimeout(timer);if(progress)clearInterval(progress);timer=progress=null;target.classList.remove('holding');if(restore&&target.style.display!=='none')target.textContent=idle};
    target.textContent=idle;
    target.addEventListener('pointerdown',event=>{if(event.pointerType==='mouse'&&event.button!==0)return;event.preventDefault();if(editing||!selectedId||!isOwner())return;start=Date.now();target.classList.add('holding');target.textContent='Hold 1/3s';progress=setInterval(()=>{const elapsed=Math.min(3,Math.max(1,Math.ceil((Date.now()-start)/1000)));target.textContent=`Hold ${elapsed}/3s`;},200);timer=setTimeout(()=>{stop(false);callback()},3000)});
    ['pointerup','pointercancel','pointerleave'].forEach(type=>target.addEventListener(type,()=>stop(true)));target.addEventListener('click',event=>event.preventDefault());target.addEventListener('contextmenu',event=>event.preventDefault());
  }

  function bind(){
    if(bound)return;bound=true;
    byId('categoryForm')?.addEventListener('submit',save);byId('newPricingCategory')?.addEventListener('click',newCategory);byId('cancelCategoryEdit')?.addEventListener('click',cancel);
    const editButton=byId('editCategoryRule');if(editButton)bindEditLongHold(editButton,unlockCategoryEditor);
    byId('categoryRows')?.addEventListener('click',event=>{const button=event.target.closest('[data-category-open]');if(!button)return;const category=categories().find(item=>item.id===button.dataset.categoryOpen);if(category)openCategory(category,false)});
    document.querySelectorAll('[data-category-product]').forEach(button=>button.addEventListener('click',()=>{selectedProduct=button.dataset.categoryProduct;fillRule(currentCategory());message(editing?`${selectedProduct} pricing rule loaded. All fields are unlocked.`:`${selectedProduct} pricing rule loaded. Hold the Edit button for 3 seconds to unlock all fields.`,'info')}));
    ['categoryMarginInput','categoryNormalInput','categoryRareInput','categoryTransportInput'].forEach(id=>{byId(id)?.addEventListener('input',updateFormula);byId(id)?.addEventListener('change',updateFormula)});
    ['categoryManualCost','categoryManualCurrency','categoryManualRarity'].forEach(id=>{byId(id)?.addEventListener('input',updateManualQuote);byId(id)?.addEventListener('change',updateManualQuote)});
  }

  function render(){
    if(!canView())return;const add=byId('newPricingCategory');if(add)add.style.display=isOwner()?'inline-flex':'none';const list=categories();if(selectedId&&!list.some(item=>item.id===selectedId))selectedId='';renderRows();showCurrencySummary();
    if(!selectedId&&list.length)openCategory(list[0],false);else if(selectedId){const category=currentCategory();if(category&&!editing){fill(category);setEditable(false)}}
    const notice=byId('categoryAccessNotice');if(notice)notice.innerHTML=`Signed in as <b>${esc(access?.display_name||access?.email||'user')}</b>. Select a Category Name on the left; its saved Margin, Normal, Rare and Transport rules will appear on the right. Company factors are maintained in Key → Company.`;
  }

  function init(data,userAccess){access=userAccess||access;bind();window.addEventListener('keysuite-company-pricing-changed',updateFormula);render()}
  function pageShown(id){if(id==='categoryManagement')render()}
  window.KeySuiteCategories={init,pageShown,reload,render};
})();
