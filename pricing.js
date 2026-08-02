(() => {
  'use strict';

  let secureData={
    companies:[],users:[],categories:[],products:[],esProducts:[],gwsProducts:[],keyplcProducts:[],manifoldProducts:[],
    productMultipliers:{CHC:{USD:5.8,RMB:.65,MYR:1},ES:{USD:5.8,RMB:.65,MYR:1},GWS:{USD:5.8,RMB:.65,MYR:1},KEYPLC:{USD:5.8,RMB:.65,MYR:1},MANIFOLD:{USD:5.8,RMB:.65,MYR:1}},
    fuel_price:2,fuel_base_price:2
  };
  let access=null;
  let companyId='';
  let categoryId='';
  let visibleRows=[];
  let bound=false;
  let selectedPricingFamily='CHC';
  let pricingFormulaVisible=false;

  const byId=id=>document.getElementById(id);
  const e=value=>String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  const n=(value,d=2)=>Number(value||0).toLocaleString('en-MY',{minimumFractionDigits:d,maximumFractionDigits:d});
  const cash=value=>`RM ${n(value,2)}`;
  const percent=value=>`${n(Number(value||0)*100,1)}%`;
  const role=()=>String(access?.role||window.KEYSUITE_ACCESS?.role||'viewer').toLowerCase();
  const permissionLevel=key=>window.KeySuitePermissions?.level?.(key,role())||(role()==='owner'?'full':'none');
  const canViewPricing=()=>permissionLevel('company_pricing')!=='none';
  const canEditPricing=()=>permissionLevel('company_pricing')==='full';
  const canChangeFuel=()=>permissionLevel('change_fuel_price')==='full';
  const roundUp10=value=>Math.ceil((Number(value||0)-1e-9)/10)*10;
  const normalizeRarity=value=>['common','many','rare'].includes(String(value||'').toLowerCase())?String(value).toLowerCase():'common';
  const rarityLabel=value=>({common:'Common',many:'Many',rare:'Rare'})[normalizeRarity(value)];
  const normMaterial=value=>String(value||'').toUpperCase().replace(/[^A-Z0-9]+/g,'');

  function customersList(){return window.KeySuiteApp?.getCustomers?.()||[]}
  function company(){return customersList().find(x=>x.id===companyId)||null}
  function category(){return secureData.categories.find(x=>x.id===categoryId)||null}
  function quotationCustomer(){return window.KeySuiteApp?.getPricingCustomer?.()||window.KeySuiteApp?.getSelectedCustomer?.()||null}
  function selectedCustomer(){return quotationCustomer()||company()}
  function categoryForCustomer(customer){return secureData.categories.find(x=>x.id===customer?.pricingCategoryId)||null}
  function context(options={}){
    const customer=options.customer||selectedCustomer();
    return {customer,distanceKm:Math.max(0,Number(options.distanceKm??customer?.distanceKm??0)),fuelPrice:Math.max(0,Number(options.fuelPrice??secureData.fuel_price??2)),fuelBasePrice:Math.max(0,Number(options.fuelBasePrice??secureData.fuel_base_price??2))};
  }

  function multipliers(family='CHC'){
    const raw=String(family||'CHC').toUpperCase();const code=['CHC','ES','GWS','KEYPLC','MANIFOLD'].includes(raw)?raw:'CHC',rates=secureData.productMultipliers?.[code]||{};
    return {USD:Number(rates.USD??secureData.usd_multiplier??5.8),RMB:Number(rates.RMB??secureData.rmb_multiplier??.65),MYR:1};
  }

  function normalizeRule(raw={},family='CHC',cat=null){
    const fallback={margin:.38,normal:0,rare:0,transport:30,commission:.03,setDiscount:.068,finalDiscount:.08,includeCommission:true,includeSetDiscount:true,includeFinalDiscount:true,includeFuelCharge:true};
    return {
      margin:Number(raw.margin??(family==='CHC'?(cat?.margins?.CHC??cat?.factors?.CHC):fallback.margin)??fallback.margin),normal:Number(raw.normal??fallback.normal),rare:Number(raw.rare??fallback.rare),transport:Number(raw.transport??cat?.transport??fallback.transport),commission:Number(raw.commission??cat?.commission??fallback.commission),
      setDiscount:Number(raw.setDiscount??raw.set_discount??cat?.set_discount??fallback.setDiscount),finalDiscount:Number(raw.finalDiscount??raw.final_discount??cat?.final_discount??fallback.finalDiscount),
      includeCommission:raw.includeCommission??raw.include_commission??true,includeSetDiscount:raw.includeSetDiscount??raw.include_set_discount??true,includeFinalDiscount:raw.includeFinalDiscount??raw.include_final_discount??true,includeFuelCharge:raw.includeFuelCharge??raw.include_fuel_charge??true
    };
  }

  function categoryRule(cat,family='CHC'){const raw=String(family||'CHC').toUpperCase();const code=['CHC','ES','GWS','KEYPLC','MANIFOLD'].includes(raw)?raw:'CHC';return normalizeRule(cat?.productRules?.[code]||{},code,code==='CHC'?cat:null)}

  function formula(cat=category(),family='CHC',rarity='many'){
    const rule=categoryRule(cat,family),level=normalizeRarity(rarity),parts=['Highest of (USD × USD rate), (RMB × RMB rate), MYR','÷ (1 − Margin)'];
    if(level==='common'||level==='rare')parts.push('÷ (1 − Normal)');if(level==='rare')parts.push('÷ (1 − Rare)');parts.push('+ Transport');if(rule.includeCommission)parts.push('÷ (1 − Commission)');if(rule.includeSetDiscount)parts.push('÷ (1 − Set Discount)');if(rule.includeFinalDiscount)parts.push('÷ (1 − Final Discount)');if(rule.includeFuelCharge)parts.push('+ Fuel Charge');parts.push('Round up to RM10');
    return `${family} ${rarityLabel(level)} = ${parts.join(' → ')}`;
  }

  function hasPricingContext(customer=quotationCustomer()){return !!(customer&&customer.pricingCategoryId&&secureData.categories.some(x=>x.id===customer.pricingCategoryId))}

  function currencyCandidates(priceBook={},rarityBook={},variant,family='CHC'){
    const rates=multipliers(family);
    return ['USD','RMB','MYR'].map(currency=>{
      const raw=priceBook?.[currency]?.[variant],valid=raw!==null&&raw!==''&&Number.isFinite(Number(raw))&&Number(raw)>0;
      return valid?{currency,sourcePrice:Number(raw),multiplier:rates[currency],baseMyr:Number(raw)*rates[currency],rarity:normalizeRarity(rarityBook?.[currency]?.[variant])}:null;
    }).filter(Boolean);
  }

  function calculatePrice(priceBook,variant,cat=category(),family='CHC',options={}){
    if(!cat)return null;
    const candidates=currencyCandidates(priceBook,options.rarityBook||{},variant,family);if(!candidates.length)return null;
    const chosen=candidates.reduce((best,row)=>!best||row.baseMyr>best.baseMyr?row:best,null),rule=categoryRule(cat,family),priceContext=context(options),rarity=normalizeRarity(options.rarity||chosen.rarity);
    const marginPrice=chosen.baseMyr/Math.max(.0001,1-rule.margin);
    const afterNormal=(rarity==='common'||rarity==='rare')?marginPrice/Math.max(.0001,1-rule.normal):marginPrice;
    const afterRare=rarity==='rare'?afterNormal/Math.max(.0001,1-rule.rare):afterNormal;
    const withTransport=afterRare+rule.transport;
    const afterCommission=rule.includeCommission?withTransport/Math.max(.0001,1-rule.commission):withTransport;
    const afterSetDiscount=rule.includeSetDiscount?afterCommission/Math.max(.0001,1-rule.setDiscount):afterCommission;
    const beforeFuel=rule.includeFinalDiscount?afterSetDiscount/Math.max(.0001,1-rule.finalDiscount):afterSetDiscount;
    const fuelCharge=rule.includeFuelCharge?priceContext.distanceKm*Math.max(priceContext.fuelPrice-priceContext.fuelBasePrice,0):0;
    const unroundedPrice=beforeFuel+fuelCharge,finalPrice=roundUp10(unroundedPrice);
    return {family,variant,rarity,candidates,sourceCurrency:chosen.currency,sourcePrice:chosen.sourcePrice,multiplier:chosen.multiplier,baseMyr:chosen.baseMyr,margin:rule.margin,normal:rule.normal,rare:rule.rare,transport:rule.transport,commission:rule.commission,setDiscount:rule.setDiscount,finalDiscount:rule.finalDiscount,includeCommission:rule.includeCommission,includeSetDiscount:rule.includeSetDiscount,includeFinalDiscount:rule.includeFinalDiscount,includeFuelCharge:rule.includeFuelCharge,marginPrice,afterNormal,afterRare,withTransport,afterCommission,afterSetDiscount,beforeFuel,distanceKm:priceContext.distanceKm,fuelPrice:priceContext.fuelPrice,fuelBasePrice:priceContext.fuelBasePrice,fuelCharge,unroundedPrice,finalPrice};
  }

  function calculate(sourceOrBook,material='CHC',cat=category(),options={}){
    if(sourceOrBook&&typeof sourceOrBook==='object')return calculatePrice(sourceOrBook,material,cat,options.productFamily||'CHC',options);
    return calculatePrice({USD:{[material]:sourceOrBook},RMB:{},MYR:{}},material,cat,options.productFamily||'CHC',options);
  }

  function calculateManual(sourcePrice,currency='USD',rarity='common',cat=category(),family='CHC',options={}){
    const code=['USD','RMB','MYR'].includes(String(currency||'').toUpperCase())?String(currency).toUpperCase():'USD';
    const value=Number(sourcePrice);if(!cat||!Number.isFinite(value)||value<=0)return null;
    const variant='MANUAL',book={USD:{},RMB:{},MYR:{}};book[code][variant]=value;
    return calculatePrice(book,variant,cat,family,{...options,rarity:normalizeRarity(rarity)});
  }

  function variants(includeUnpriced=false){
    const result=[];
    for(const product of secureData.products||[])for(const material of ['CHC','CHCS','CHCN']){
      const candidates=currencyCandidates(product.pricesByCurrency||{},product.rarityByCurrency||{},material,'CHC');if(candidates.length||includeUnpriced)result.push({product,material,priced:!!candidates.length});
    }
    return result;
  }

  function syncCompanyCategory(){categoryId=company()?.pricingCategoryId||'';if(byId('pricingCategorySelect'))byId('pricingCategorySelect').value=categoryId}

  function fillSelects(){
    const cs=byId('pricingCompanySelect'),cats=byId('pricingCategorySelect'),list=customersList();
    if(cs){cs.innerHTML='<option value="">Select customer/company</option>'+list.map(x=>`<option value="${e(x.id)}">${e(x.company)}</option>`).join('');cs.value=list.some(x=>x.id===companyId)?companyId:''}
    if(cats){cats.innerHTML='<option value="">No pricing category assigned</option>'+(secureData.categories||[]).map(x=>`<option value="${e(x.id)}">${e(x.name)}</option>`).join('');cats.value=categoryId;cats.disabled=!canEditPricing()||!company()}
    const save=byId('savePricingCategory');if(save){save.style.display=canEditPricing()?'inline-block':'none';save.disabled=!company()}
  }

  function renderFuelSetting(){
    const input=byId('pricingFuelPrice'),button=byId('saveFuelPrice'),message=byId('pricingFuelMessage');if(!input||!button||!message)return;
    if(document.activeElement!==input)input.value=Number(secureData.fuel_price??2).toFixed(2);input.disabled=!canChangeFuel();button.disabled=!canChangeFuel();button.style.display=canChangeFuel()?'inline-block':'none';message.textContent=canChangeFuel()?`Saved globally until changed. Base fuel price: ${cash(secureData.fuel_base_price??2)}/L`:`Current fuel price: ${cash(secureData.fuel_price??2)}/L`;
  }

  function ruleSummary(cat,family){
    const rule=categoryRule(cat,family),rates=multipliers(family);
    return [[`${family} Margin`,percent(rule.margin)],['Normal',percent(rule.normal)],['Rare',percent(rule.rare)],['Transport',cash(rule.transport)],['Commission',rule.includeCommission?percent(rule.commission):'Not included'],['Set Discount',rule.includeSetDiscount?percent(rule.setDiscount):'Not included'],['Final Discount',rule.includeFinalDiscount?percent(rule.finalDiscount):'Not included'],['Fuel Charge',rule.includeFuelCharge?'Included':'Not included'],[`${family} Currency`,`USD (MYR ${n(rates.USD,2)}) · RMB (MYR ${n(rates.RMB,2)}) · MYR (MYR 1.00)`]];
  }

  function renderPricingManualQuote(){
    const valueBox=byId('pricingManualQuotedValue'),detail=byId('pricingManualBreakdown');if(!valueBox||!detail)return;
    const source=Number(byId('pricingManualCost')?.value),currency=String(byId('pricingManualCurrency')?.value||'USD').toUpperCase(),rarity=String(byId('pricingManualRarity')?.value||'common').toLowerCase();
    const c=company()||quotationCustomer(),cat=category()||categoryForCustomer(c);
    if(!c||!cat){valueBox.textContent='RM 0.00';detail.textContent='Select a customer with a Pricing Category.';return}
    if(!Number.isFinite(source)||source<=0){valueBox.textContent='RM 0.00';detail.textContent='Enter a cost figure to calculate.';return}
    const calc=calculateManual(source,currency,rarity,cat,selectedPricingFamily,{customer:c});
    if(!calc){valueBox.textContent='RM 0.00';detail.textContent='Unable to calculate with the selected rule.';return}
    valueBox.textContent=cash(calc.finalPrice);detail.textContent=`${currency} ${n(source,2)} × ${n(calc.multiplier,4)} = ${cash(calc.baseMyr)} · ${rarityLabel(rarity)} · Fuel ${cash(calc.fuelCharge)} · rounded up to RM10`;
  }

  function renderSummary(){
    const c=company(),cat=category(),quoteCustomer=quotationCustomer(),ctx=context({customer:c||quoteCustomer});byId('pricingCompanyCount').textContent=customersList().length;byId('pricingCategoryCount').textContent=(secureData.categories||[]).length;byId('pricingModelCount').textContent=(secureData.products||[]).length;byId('pricingVariantCount').textContent=variants(false).length;
    let notice=`Signed in as <b>${e(access?.display_name||access?.email||'approved user')}</b>. `;if(!quoteCustomer)notice+='No quotation pricing customer selected.';else if(!hasPricingContext(quoteCustomer))notice+=`Quotation pricing customer: <b>${e(quoteCustomer.company)}</b>. No Pricing Category is assigned.`;else notice+=`Quotation pricing customer: <b>${e(quoteCustomer.company)}</b> · Category: <b>${e(categoryForCustomer(quoteCustomer)?.name||'-')}</b> · Distance: <b>${n(quoteCustomer.distanceKm,1)} km</b>.`;
    byId('pricingAccessNotice').innerHTML=notice;byId('pricingAccessNotice').classList.add('active-customer');
    byId('pricingCompanySummary').innerHTML=c?[[ 'Company Name',c.company],['Classification',c.classification||'-'],['Pricing Category',categoryForCustomer(c)?.name||'Not assigned'],['Assigned User',typeof customerOwnerName==='function'?customerOwnerName(c.assignedUserEmail):(c.assignedUserEmail||'-')],['Phone',c.companyPhone||'-'],['Payment Term',c.terms||'-'],['TIN',c.tinNumber||'-'],['Business Registration No.',c.brnNumber||'-'],['SST No.',c.sstNumber||'-'],['Address',c.address||'-'],['Distance',`${n(c.distanceKm,1)} km`]].map(([k,v])=>`<div class="pricing-kv"><b>${e(k)}</b><span>${e(v)}</span></div>`).join(''):'<p class="muted">Select a customer/company to view its saved details.</p>';
    document.querySelectorAll('[data-pricing-family]').forEach(button=>{const active=button.dataset.pricingFamily===selectedPricingFamily;button.classList.toggle('active',active);button.setAttribute('aria-selected',String(active))});
    const otherRows=[['Current Fuel Price',`${cash(ctx.fuelPrice)}/L`],['Customer Distance',`${n(ctx.distanceKm,1)} km`]];
    byId('pricingCategorySummary').innerHTML=cat?[['Category Name',cat.name],...ruleSummary(cat,selectedPricingFamily),...otherRows].map(([k,v])=>`<div class="pricing-kv"><b>${e(k)}</b><span>${e(v)}</span></div>`).join(''):'<p class="muted">No pricing category is assigned to this customer.</p>';
    const formulaBox=byId('pricingFormula'),formulaToggle=byId('togglePricingFormula');
    if(formulaBox){formulaBox.textContent=cat?[formula(cat,selectedPricingFamily,'many'),formula(cat,selectedPricingFamily,'common'),formula(cat,selectedPricingFamily,'rare')].join('\n'):'';formulaBox.style.display=pricingFormulaVisible&&cat?'block':'none'}
    if(formulaToggle){formulaToggle.textContent=pricingFormulaVisible?'Hide Formula':'Show Formula';formulaToggle.setAttribute('aria-expanded',String(pricingFormulaVisible));formulaToggle.disabled=!cat}
    renderFuelSetting();fillSelects();renderPricingManualQuote();
  }

  function renderTable(){
    if(!byId('pricingRows'))return;
    const search=(byId('pricingModelSearch').value||'').trim().toLowerCase(),material=byId('pricingMaterialFilter').value,showUnpriced=byId('pricingShowUnpriced').checked;
    visibleRows=variants(showUnpriced).filter(row=>(material==='ALL'||row.material===material)&&(!search||row.product.model.toLowerCase().includes(search)||row.material.toLowerCase().includes(search)));
    const c=company(),cat=category();byId('pricingSourceCurrencyHeader').textContent='Highest Source';
    byId('pricingRows').innerHTML=visibleRows.map((row,index)=>{
      const calc=c&&cat?calculatePrice(row.product.pricesByCurrency||{},row.material,cat,'CHC',{customer:c,rarityBook:row.product.rarityByCurrency||{}}):null;
      return `<tr><td><b>${e(row.product.model)}</b></td><td><span class="pricing-badge ${calc?'ok':'warn'}">${e(row.material)}</span></td><td><span class="pricing-badge">${e(calc?rarityLabel(calc.rarity):'-')}</span></td><td class="num">${calc?`${e(calc.sourceCurrency)} ${n(calc.sourcePrice,2)}`:'-'}</td><td class="num">${calc?cash(calc.baseMyr):'-'}</td><td class="num">${calc?percent(calc.margin):'-'}</td><td class="num">${calc?cash(calc.marginPrice):'-'}</td><td class="num">${calc?cash(calc.withTransport):'-'}</td><td class="num">${calc?cash(calc.beforeFuel):'-'}</td><td class="num">${calc?cash(calc.fuelCharge):'-'}</td><td class="num"><b>${calc?cash(calc.finalPrice):'-'}</b></td><td>${calc?`<button type="button" class="btn green" data-pricing-add="${index}">Add to Quotation</button>`:''}</td></tr>`;
    }).join('')||'<tr><td colspan="12" class="muted">No matching products.</td></tr>';
    const contextText=!c?'Select a customer/company in Key.':!cat?'Assign a Pricing Category to generate prices.':'The highest converted currency is used together with that winning currency record’s rarity; final prices round upward to RM10.';byId('pricingCount').textContent=`Showing ${visibleRows.length.toLocaleString('en-MY')} variants. ${contextText}`;document.querySelectorAll('[data-pricing-add]').forEach(button=>button.addEventListener('click',()=>addToQuotation(Number(button.dataset.pricingAdd))));
  }

  function findPrice(model,options={}){
    const customer=options.customer||quotationCustomer(),cat=options.category||categoryForCustomer(customer);if(!customer||!cat)return null;
    const text=String(model||'').trim();let material='CHC',base=text;if(/^CHCS\b/i.test(text)){material='CHCS';base=text.replace(/^CHCS\b/i,'CHC')}else if(/^CHCN\b/i.test(text)){material='CHCN';base=text.replace(/^CHCN\b/i,'CHC')}
    const product=(secureData.products||[]).find(p=>String(p.model).toLowerCase()===base.toLowerCase());if(!product)return null;
    const calc=calculatePrice(product.pricesByCurrency||{},material,cat,'CHC',{...options,customer,rarityBook:product.rarityByCurrency||{}});return calc?{product,material,rarity:calc.rarity,calc,category:cat,customer,family:'CHC'}:null;
  }

  function findGwsPrice(model,pressure,options={}){
    const customer=options.customer||quotationCustomer(),cat=options.category||categoryForCustomer(customer);if(!customer||!cat)return null;
    const wanted=String(model||'').toLowerCase(),product=(secureData.gwsProducts||[]).find(p=>String(p.id).toLowerCase()===wanted||String(p.model).toLowerCase()===wanted);if(!product)return null;
    const calc=calculatePrice(product.pricesByCurrency||{},'SKU',cat,'GWS',{...options,customer,rarityBook:product.rarityByCurrency||{}});return calc?{product,material:'SKU',variant:'SKU',rarity:calc.rarity,calc,category:cat,customer,family:'GWS'}:null;
  }

  function findAutoGwsTank(sizeLitres,minimumPressureBar=0,options={}){
    const customer=options.customer||quotationCustomer(),cat=options.category||categoryForCustomer(customer);if(!customer||!cat)return null;
    const size=Number(sizeLitres),minimum=Math.max(0,Number(minimumPressureBar)||0);
    const candidates=(secureData.gwsProducts||[]).filter(product=>Number(product.sizeLitres||0)===size&&Number(product.pressureBar||0)>minimum+1e-9).sort((a,b)=>Number(a.pressureBar||0)-Number(b.pressureBar||0)||String(a.seriesCode||'').localeCompare(String(b.seriesCode||'')));
    for(const product of candidates){const found=findGwsPrice(product.id,null,{...options,customer,category:cat});if(found)return found}
    return null;
  }

  function sourceSnapshot(found){return {product_family:found.family||found.calc.family||'CHC',product_id:found.product.id,material:found.material,variant:found.variant||found.material,rarity:found.calc.rarity,customer_id:found.customer?.id||'',category_id:found.category?.id||'',source_currency:found.calc.sourceCurrency,currency_multiplier:found.calc.multiplier,source_price:found.calc.sourcePrice,distance_km:found.calc.distanceKm,fuel_price:found.calc.fuelPrice,fuel_base_price:found.calc.fuelBasePrice,fuel_charge:found.calc.fuelCharge,unrounded_price:found.calc.unroundedPrice,calculated_price:found.calc.finalPrice,...(found.enclosure?{panel_type:found.enclosure,enclosure_surcharge:Number(found.calc.enclosureSurcharge||0)}:{}),...(found.sourceExtra||{})}}

  function applyPriceToQuoteRow(row,model,options={}){if(window.KeySuiteApp?.canEditQuotation&&!window.KeySuiteApp.canEditQuotation(true))return false;const found=options.productFamily==='GWS'?findGwsPrice(model,options.pressure,options):findPrice(model,options);if(!row||!found)return false;const input=row.querySelector('.item-price');if(!input)return false;input.value=found.calc.finalPrice.toFixed(2);row.dataset.pricingSource=JSON.stringify(sourceSnapshot(found));if(typeof calcTotal==='function')calcTotal();return true}

  function refreshQuotePrices(){
    const customer=quotationCustomer(),cat=categoryForCustomer(customer);if(!customer||!cat)return;
    for(const row of [...document.querySelectorAll('.quote-item[data-pricing-source]')]){
      let source={};try{source=JSON.parse(row.dataset.pricingSource||'{}')}catch(_){ }
      let found=null;
      if(source.product_family==='GWS'){const product=(secureData.gwsProducts||[]).find(p=>p.id===source.product_id);if(product)found=findGwsPrice(product.id,null,{customer,category:cat})}
      else if(source.product_family==='ES'){const product=(secureData.esProducts||[]).find(p=>p.id===source.product_id);if(product)found=findEsPrice(product.id,source.variant||source.material,{customer,category:cat})}
      else if(source.product_family==='KEYPLC'){const product=(secureData.keyplcProducts||[]).find(p=>p.id===source.product_id);if(product)found=findKeyplcPrice(product.id,Number(String(source.variant||source.material||'1').replace(/\D/g,''))||1,{customer,category:cat,enclosure:source.panel_type||'indoor'})}
      else if(source.product_family==='MANIFOLD'){found=window.KeySuiteManifold?.findConfiguredPrice?.(source.configuration||{}, {customer,category:cat})||null}
      else{const product=(secureData.products||[]).find(p=>p.id===source.product_id);if(product){const model=(source.material==='CHC'?product.model:product.model.replace(/^CHC\b/,source.material||'CHC'));found=findPrice(model,{customer,category:cat})}}
      if(!found)continue;row.querySelector('.item-price').value=found.calc.finalPrice.toFixed(2);const refreshed=sourceSnapshot(found);if(source.product_family==='ES'){refreshed.seal_material=source.seal_material||ES_DEFAULT_SEAL;refreshed.elastomer=source.elastomer||ES_DEFAULT_ELASTOMER}row.dataset.pricingSource=JSON.stringify(refreshed);
    }
    if(typeof calcTotal==='function')calcTotal();
  }

  function quoteRowForNewItem(){const rows=[...document.querySelectorAll('.quote-item')],first=rows[0],empty=rows.length===1&&first&&!first.querySelector('.item-model').value&&!first.querySelector('.item-description').value&&!Number(first.querySelector('.item-price').value||0);return empty?first:quoteItemRow({})}

  function addToQuotation(index){
    if(window.KeySuiteApp?.canEditQuotation&&!window.KeySuiteApp.canEditQuotation(true))return;
    const customer=quotationCustomer();if(!customer){if(typeof showPage==='function')showPage('quotation');alert('Select a pricing customer before adding an item.');return}
    const cat=categoryForCustomer(customer);if(!cat){alert(`No Pricing Category is assigned to ${customer.company}.`);return}
    const row=visibleRows[index];if(!row)return;const calc=calculatePrice(row.product.pricesByCurrency||{},row.material,cat,'CHC',{customer,rarityBook:row.product.rarityByCurrency||{}});if(!calc)return;
    const shownModel=row.material==='CHC'?row.product.model:row.product.model.replace(/^CHC\b/,row.material),description=`B.G.Reich Vertical Multistage Pump Model: ${shownModel}`;
    const quoteRow=quoteRowForNewItem();quoteRow.querySelector('.item-model').value=shownModel;quoteRow.querySelector('.item-qty').value=1;quoteRow.querySelector('.item-price').value=calc.finalPrice.toFixed(2);quoteRow.querySelector('.item-description').value=description;quoteRow.dataset.pricingSource=JSON.stringify(sourceSnapshot({product:row.product,material:row.material,rarity:calc.rarity,calc,category:cat,customer,family:'CHC'}));calcTotal();refreshItemExportButtons();showPage('quotation');
  }

  function gwsQuoteTitle(product){const litres=Number(product?.sizeLitres||String(product?.sizeCode||'').replace(/\D/g,'')||0);return `${litres.toLocaleString('en-MY')} Litres (${Number(product?.pressureBar||0)} Bar)`}
  function gwsDescription(product){
    const model=product?.model||'',pressure=Number(product?.pressureBar||0),series=String(product?.seriesCode||'').toUpperCase(),lines=[];
    if(series==='PEB')lines.push(`E-Wave Series (${pressure} Bar)`,`GWS E-Wave Tank Model: ${model}`);else if(series==='PWB')lines.push(`Pressure Wave Series (${pressure} Bar)`,`GWS Pressure Wave Tank Model: ${model}`);else if(series==='MXB')lines.push(`Max Series (${pressure} Bar)`,`GWS Max Tank Model: ${model}`);else if(series==='UMB')lines.push(`Ultra Max Series (${pressure} Bar)`,`GWS Ultra Max Tank Model: ${model}`);else if(series==='GCB')lines.push('Challenger Series',`Challenger Series Model: ${model}`);else if(['SFB','SMB','SUB'].includes(series))lines.push(`Superflow Series Model: ${model}`);else lines.push(`GWS Tank Model: ${model}`);
    if(product?.systemConnection)lines.push(`${series==='GCB'?'System Connection':'Standard System Connection'}: ${product.systemConnection}`);if(product?.prechargeText)lines.push(`Tank precharge: ${product.prechargeText}`);if(product?.maxWorkingPressureText)lines.push(`Maximum Working Pressure: ${product.maxWorkingPressureText}`);if(product?.maxWorkingTemperatureText)lines.push(`Maximum Working Temperature: ${product.maxWorkingTemperatureText}`);return lines.join('\n');
  }

  function addGwsToQuotation(model,pressure){
    if(window.KeySuiteApp?.canEditQuotation&&!window.KeySuiteApp.canEditQuotation(true))return;
    const customer=quotationCustomer();if(!customer){if(typeof showPage==='function')showPage('quotation');alert('Select a pricing customer before adding a GWS Tank.');return}
    const found=findGwsPrice(model,pressure,{customer});if(!found){alert('No price is available for this GWS Tank SKU, or the customer has no pricing category.');return}
    const quoteRow=quoteRowForNewItem();quoteRow.querySelector('.item-model').value=gwsQuoteTitle(found.product);quoteRow.querySelector('.item-qty').value=1;quoteRow.querySelector('.item-price').value=found.calc.finalPrice.toFixed(2);quoteRow.querySelector('.item-description').value=gwsDescription(found.product);quoteRow.dataset.pricingSource=JSON.stringify(sourceSnapshot(found));calcTotal();refreshItemExportButtons();showPage('quotation');
  }

  async function savePricingCategory(){
    if(!canEditPricing()){alert('Your role is not allowed to assign a Pricing Category.');return}
    const c=company(),message=byId('pricingCategoryMessage'),button=byId('savePricingCategory');if(!c){alert('Select a customer/company first.');return}
    const next=byId('pricingCategorySelect')?.value||'';button.disabled=true;button.textContent='Saving…';try{await window.KeySuiteApp?.updateCustomerPricingCategory?.(c.id,next);categoryId=next;if(message)message.textContent=next?`Pricing Category saved for ${c.company}.`:`Pricing Category removed from ${c.company}.`;renderSummary();renderTable();refreshQuotePrices()}catch(error){console.error(error);alert(`Pricing Category could not be saved: ${error.message||error}`)}finally{button.disabled=false;button.textContent='Save Category'}
  }

  async function saveFuelPrice(){
    if(!canChangeFuel()){alert('Your role is not allowed to change Fuel Price.');return}
    const input=byId('pricingFuelPrice'),button=byId('saveFuelPrice'),message=byId('pricingFuelMessage'),value=Number(input?.value);if(!Number.isFinite(value)||value<0){alert('Enter a valid Fuel Price.');return}
    const client=window.KeySuiteAuth?.getClient?.();if(!client){alert('Supabase is not connected.');return}
    const originalButton=button.innerHTML;button.disabled=true;button.textContent='…';try{const {data,error}=await client.rpc('keysuite_save_fuel_price_v124',{p_fuel_price:value});if(error)throw error;const saved=Array.isArray(data)?data[0]:data||{};secureData.fuel_price=Number(saved?.fuel_price??value);secureData.fuel_base_price=Number(saved?.fuel_base_price??secureData.fuel_base_price??2);if(window.KEYSUITE_SECURE_DATA){window.KEYSUITE_SECURE_DATA.fuel_price=secureData.fuel_price;window.KEYSUITE_SECURE_DATA.fuel_base_price=secureData.fuel_base_price}message.textContent=`Saved: ${cash(secureData.fuel_price)}/L · Base ${cash(secureData.fuel_base_price)}/L`;renderSummary();renderTable();refreshQuotePrices()}catch(error){console.error(error);alert(`Fuel Price could not be saved: ${error.message||error}. Run the V1.24 Supabase migration.`)}finally{button.disabled=!canChangeFuel();button.innerHTML=originalButton}
  }

  function exportCsv(){
    const rows=[['Customer','Category','Model','Variant','Rarity','Source Currency','Source Price','Base MYR','Margin','Normal','Rare','Transport','Fuel Charge','Final Price']],c=company(),cat=category();
    for(const row of visibleRows){const calc=c&&cat?calculatePrice(row.product.pricesByCurrency||{},row.material,cat,'CHC',{customer:c,rarityBook:row.product.rarityByCurrency||{}}):null;if(calc)rows.push([c.company,cat.name,row.product.model,row.material,rarityLabel(calc.rarity),calc.sourceCurrency,calc.sourcePrice,calc.baseMyr,calc.margin,calc.normal,calc.rare,calc.transport,calc.fuelCharge,calc.finalPrice])}
    const csv=rows.map(r=>r.map(v=>`"${String(v??'').replace(/"/g,'""')}"`).join(',')).join('\r\n'),link=document.createElement('a');link.href=URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8'}));link.download='KeySuite_V1.20_Visible_Pricing.csv';link.click();setTimeout(()=>URL.revokeObjectURL(link.href),1000);
  }

  function selectCustomer(id,rerender=true){companyId=id||'';syncCompanyCategory();fillSelects();if(rerender){renderSummary();renderTable()}}
  function refreshCustomers(){const list=customersList(),quoteId=quotationCustomer()?.id||'';if(quoteId&&list.some(x=>x.id===quoteId))companyId=quoteId;else if(companyId&&!list.some(x=>x.id===companyId))companyId='';if(!companyId&&list.length)companyId=list[0].id;syncCompanyCategory();fillSelects();renderSummary();renderTable()}

  function bind(){
    if(bound)return;bound=true;
    byId('pricingCompanySelect')?.addEventListener('change',event=>selectCustomer(event.target.value));
    byId('pricingCategorySelect')?.addEventListener('change',event=>{categoryId=event.target.value;renderSummary();renderTable()});
    byId('savePricingCategory')?.addEventListener('click',savePricingCategory);
    byId('saveFuelPrice')?.addEventListener('click',saveFuelPrice);
    ['pricingManualCost','pricingManualCurrency','pricingManualRarity'].forEach(id=>{byId(id)?.addEventListener('input',renderPricingManualQuote);byId(id)?.addEventListener('change',renderPricingManualQuote)});
    document.querySelectorAll('[data-pricing-family]').forEach(button=>button.addEventListener('click',()=>{selectedPricingFamily=['CHC','ES','GWS','KEYPLC','MANIFOLD'].includes(button.dataset.pricingFamily)?button.dataset.pricingFamily:'CHC';renderSummary()}));
    byId('togglePricingFormula')?.addEventListener('click',()=>{pricingFormulaVisible=!pricingFormulaVisible;renderSummary()});
  }

  function syncPriceListSettings(next={}){secureData={...secureData,...next};renderSummary();renderTable();refreshQuotePrices()}
  function init(data,userAccess){secureData={...secureData,...(data||{})};access=userAccess||access;const list=customersList(),quoteId=quotationCustomer()?.id||'';companyId=(quoteId&&list.some(x=>x.id===quoteId))?quoteId:(list[0]?.id||'');syncCompanyCategory();fillSelects();bind();renderSummary();renderTable()}



  function esPriceBook(product){
    const book={USD:{},RMB:{},MYR:{}};
    (product?.variants||[]).forEach(variant=>{
      const material=String(variant.material||'').trim();if(!material)return;
      book.USD[material]=variant.priceUsd===null||variant.priceUsd===''?null:Number(variant.priceUsd);
      book.RMB[material]=variant.priceRmb===null||variant.priceRmb===''?null:Number(variant.priceRmb);
      book.MYR[material]=variant.priceMyr===null||variant.priceMyr===''?null:Number(variant.priceMyr);
    });
    return book;
  }

  function findEsPrice(id,material=null,options={}){
    const product=(secureData.esProducts||[]).find(x=>x.id===id);if(!product)return null;
    const cat=options.category||categoryForCustomer(options.customer||selectedCustomer());if(!cat)return null;
    const variants=product.variants||[];
    const variant=material?variants.find(v=>normMaterial(v.material)===normMaterial(material)):variants.find(v=>['priceUsd','priceRmb','priceMyr'].some(key=>Number(v[key])>0));
    if(!variant)return null;
    const calc=calculatePrice(esPriceBook(product),variant.material,cat,'ES',{...options,rarity:product.rarity||'common'});
    return calc?{product,variant,calc}:null;
  }

  const ES_DEFAULT_SEAL='Carbon Ceramic (Ca Ce)';
  const ES_DEFAULT_ELASTOMER='Viton';
  function esModelName(model){return String(model||'').replace(/^ES\s+/i,'').trim()}
  function esConnectionSizes(model){
    const discharge=Number((esModelName(model).match(/^(\d+)/)||[])[1]||0),suctionMap={32:50,40:65,50:65,65:80,80:100,100:125,125:150,150:200,200:250,250:300};
    return {suction:suctionMap[discharge]||discharge,discharge};
  }
  function esMaterialDescription(material){
    const raw=String(material||'').trim(),parts=raw.split('/').map(x=>x.trim()).filter(Boolean);
    if(parts.length>=4){const ending=/^GP$/i.test(parts[3])?'Gland Packing':'Mech Seal';return `${parts[0]} / ${parts[1]} / ${parts[2]} / ${ending}`}
    if(/^SS\s*304$/i.test(raw))return 'SS304';if(/^SS\s*316$/i.test(raw))return 'SS316';
    return raw.replace(/\bMS\b/gi,'Mech Seal').replace(/\bGP\b/gi,'Gland Packing');
  }
  function esDescription(product,material,options={}){
    const seal=String(options.seal||ES_DEFAULT_SEAL),elastomer=String(options.elastomer||ES_DEFAULT_ELASTOMER),sizes=esConnectionSizes(product?.model),isGland=/\bGP\b/i.test(String(material||''));
    const lines=[`B.G.Reich End Suction Pump Model: ${esModelName(product?.model)}`,`Suction x Discharge: DN${sizes.suction} x DN${sizes.discharge}`,`Pump Material: ${esMaterialDescription(material)}`];
    if(!isGland&&seal!==ES_DEFAULT_SEAL)lines.push(`Mech Seal Material: ${seal}`);
    if(elastomer!==ES_DEFAULT_ELASTOMER)lines.push(`Elastomer: ${elastomer}`);
    lines.push('(Bare shaft pump only)');return lines.join('\n');
  }
  function addEs(id,route='quotation',material='CI / SS / SS / MS',options={}){
    if(!window.KeySuiteApp?.ensureQuotationPricingContext?.(`add an ES pump to the ${route==='assembly'?'Assembly':'quotation'}`))return;
    const found=findEsPrice(id,material);if(!found){alert(`No ES source price or ES Category Pricing Rule is available for ${material}.`);return}
    const {product,variant,calc}=found,seal=String(options.seal||ES_DEFAULT_SEAL),elastomer=String(options.elastomer||ES_DEFAULT_ELASTOMER),description=esDescription(product,variant.material,{seal,elastomer});
    const item={model:product.model,description,qty:1,unitPrice:calc.finalPrice,pricingSource:{product_family:'ES',product_id:product.id,variant:variant.material,material:variant.material,source_currency:calc.sourceCurrency,source_price:calc.sourcePrice,multiplier:calc.multiplier,rarity:product.rarity||'common',seal_material:seal,elastomer},assemblyLevel:'PUMPSET_COMPONENT',assemblySection:'pump'};
    if(route==='assembly'){window.KeySuiteAssembly?.addItem?.(item);return}
    if(window.KeySuiteApp?.canEditQuotation&&!window.KeySuiteApp.canEditQuotation(true))return;
    const row=quoteRowForNewItem();row.querySelector('.item-model').value=product.model;row.querySelector('.item-qty').value=1;row.querySelector('.item-price').value=calc.finalPrice.toFixed(2);row.querySelector('.item-description').value=item.description;row.dataset.pricingSource=JSON.stringify(item.pricingSource);calcTotal();refreshItemExportButtons();showPage('quotation');
  }
  function buildChcAssemblyItem(model,options={}){
    const found=findPrice(model,options);if(!found)return null;
    const shownModel=found.material==='CHC'?found.product.model:found.product.model.replace(/^CHC\b/,found.material);
    return {model:shownModel,description:`B.G.Reich Vertical Multistage Pump Model: ${shownModel}`,qty:1,unitPrice:found.calc.finalPrice,pricingSource:sourceSnapshot(found),productFamily:'CHC'};
  }
  function gwsAssemblyDescription(product,qty=1){
    const litres=Number(product?.sizeLitres||String(product?.sizeCode||'').replace(/\D/g,'')||0);
    const pressureBar=Number(product?.pressureBar||0);
    const quantity=Math.max(0,Number(qty)||1);
    const clean=value=>Number.isInteger(value)?value.toFixed(0):String(value);
    return `c/w ${clean(litres)} litres (${clean(pressureBar)} bar) non-jkkp approved tank @ ${clean(quantity)} ${quantity===1?'unit':'units'}`;
  }
  function buildGwsAssemblyItem(model,pressure,options={}){
    const found=findGwsPrice(model,pressure,options);if(!found)return null;
    return {model:gwsQuoteTitle(found.product),description:gwsAssemblyDescription(found.product,1),qty:1,unitPrice:found.calc.finalPrice,pricingSource:sourceSnapshot(found),productFamily:'GWS',tankData:{sizeLitres:Number(found.product?.sizeLitres||0),pressureBar:Number(found.product?.pressureBar||0)}};
  }

  function keyplcPriceBook(product){
    const book={USD:{},RMB:{},MYR:{}};
    (product?.variants||[]).forEach(variant=>{
      const qty=Math.max(1,Math.min(6,Number(variant.pumpQty||variant.pump_qty||String(variant.label||'').match(/\d+/)?.[0]||0)));if(!qty)return;
      const key=`P${qty}`;
      book.USD[key]=variant.priceUsd===null||variant.priceUsd===''?null:Number(variant.priceUsd);
      book.RMB[key]=variant.priceRmb===null||variant.priceRmb===''?null:Number(variant.priceRmb);
      book.MYR[key]=variant.priceMyr===null||variant.priceMyr===''?null:Number(variant.priceMyr);
    });
    return book;
  }

  function normalizePanelType(value){return /^shelter/i.test(String(value||''))?'sheltered':'indoor'}
  function keyplcPanelLabel(value){return normalizePanelType(value)==='sheltered'?'Sheltered':'Indoor Type'}

  function findKeyplcPrice(id,pumpQty=1,options={}){
    const product=(secureData.keyplcProducts||[]).find(x=>String(x.id)===String(id)||String(x.model).toLowerCase()===String(id||'').toLowerCase());if(!product)return null;
    const customer=options.customer||quotationCustomer(),cat=options.category||categoryForCustomer(customer);if(!customer||!cat)return null;
    const qty=Math.max(1,Math.min(6,Number(pumpQty)||1)),variant=`P${qty}`,enclosure=normalizePanelType(options.enclosure);
    const baseCalc=calculatePrice(keyplcPriceBook(product),variant,cat,'KEYPLC',{...options,customer,rarity:product.rarity||'common'});if(!baseCalc)return null;
    const enclosureSurcharge=enclosure==='sheltered'?1000:0;
    const calc={...baseCalc,indoorPrice:baseCalc.finalPrice,enclosureSurcharge,unroundedPrice:Number(baseCalc.unroundedPrice||0)+enclosureSurcharge,finalPrice:Number(baseCalc.finalPrice||0)+enclosureSurcharge};
    return {product,material:variant,variant,rarity:calc.rarity,pumpQty:qty,enclosure,calc,category:cat,customer,family:'KEYPLC'};
  }

  function keyplcTitle(product,pumpQty,enclosure='indoor'){const qty=Math.max(1,Number(pumpQty)||1);return `KeyPLC ${product?.model||''} · ${qty} ${qty===1?'Pump':'Pumps'} · ${keyplcPanelLabel(enclosure)}`}
  function keyplcDescription(product,pumpQty,enclosure='indoor',options={}){
    const qty=Math.max(1,Math.min(6,Number(pumpQty)||1)),numberWord=qty===1?'no':'nos',includeCw=!!options.includeCw,indent=includeCw?'\t':'';
    const first=`${includeCw?'c/w ':''}KeyPLC Control Panel (${keyplcPanelLabel(enclosure)})`;
    return `${first}
${indent}Pump Controller & HMI Touch Screen @ 1 Lot
${indent}${product?.model||''} VFD @ ${qty} ${numberWord} & Pressure Transmitter @ 1 no
${indent}Wiring for pumps & pressure transmitter within pump skid @ 1 Lot`;
  }

  function addKeyplc(id,pumpQty=1,route='quotation',enclosure='indoor'){
    if(!window.KeySuiteApp?.ensureQuotationPricingContext?.(`add a KeyPLC panel to the ${route==='assembly'?'Assembly':'quotation'}`))return;
    const found=findKeyplcPrice(id,pumpQty,{enclosure});if(!found){alert('No KeyPLC source price or KeyPLC Category Pricing Rule is available for this panel.');return}
    const item={model:keyplcTitle(found.product,found.pumpQty,found.enclosure),description:keyplcDescription(found.product,found.pumpQty,found.enclosure,{includeCw:route==='assembly'}),qty:1,unitPrice:found.calc.finalPrice,pricingSource:sourceSnapshot(found),productFamily:'KEYPLC',assemblyLevel:'SYSTEM_COMPONENT',assemblySection:'control_panel',keyplcData:{productId:found.product.id,motorRating:found.product.model,pumpQty:found.pumpQty,enclosure:found.enclosure,indoorUnitPrice:found.calc.indoorPrice,shelteredSurcharge:1000}};
    if(route==='assembly'){window.KeySuiteAssembly?.addItem?.(item);return}
    if(window.KeySuiteApp?.canEditQuotation&&!window.KeySuiteApp.canEditQuotation(true))return;
    const row=quoteRowForNewItem();row.querySelector('.item-model').value=item.model;row.querySelector('.item-qty').value=1;row.querySelector('.item-price').value=found.calc.finalPrice.toFixed(2);row.querySelector('.item-description').value=item.description;row.dataset.pricingSource=JSON.stringify(item.pricingSource);calcTotal();refreshItemExportButtons();showPage('quotation');
  }

  window.KeySuitePricing={init,calculate,calculatePrice,calculateManual,findPrice,findGwsPrice,findAutoGwsTank,findKeyplcPrice,applyPriceToQuoteRow,refreshQuotePrices,addGwsToQuotation,addEs,esDescription,addKeyplc,keyplcDescription,keyplcTitle,normalizePanelType,findEsPrice,buildChcAssemblyItem,buildGwsAssemblyItem,selectCustomer,refreshCustomers,hasPricingContext,syncPriceListSettings,render:()=>{renderSummary();renderTable()}};
})();
