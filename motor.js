(() => {
  'use strict';
  const PREFIX_TO_IE=Object.freeze({BM:'IE1','2BM':'IE2','3BM':'IE3','4BM':'IE4','5BM':'IE5'});
  const IE_TO_PREFIX=Object.freeze({IE1:'BM',IE2:'2BM',IE3:'3BM',IE4:'4BM',IE5:'5BM'});
  const CURRENCIES=['USD','RMB','MYR'],RARITIES=['common','many','rare'];
  let secureData={motorProducts:[],categories:[],productMultipliers:{MOTOR:{USD:1,RMB:1,MYR:1}}},access=null,bound=false;
  const byId=id=>document.getElementById(id);
  const esc=value=>String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  const number=value=>Number.isFinite(Number(value))?Number(value):0;
  const money=value=>`RM ${number(value).toLocaleString('en-MY',{minimumFractionDigits:2,maximumFractionDigits:2})}`;
  const hpLabel=value=>Number.isInteger(Number(value))?String(Number(value)):String(Number(value)).replace(/0+$/,'').replace(/\.$/,'');
  const permissionLevel=key=>window.KeySuitePermissions?.level?.(key,String(access?.role||window.KEYSUITE_ACCESS?.role||'viewer').toLowerCase())||'none';
  const canEditPrices=()=>permissionLevel('manage_price_list')==='full';
  const products=()=>secureData.motorProducts||[];
  const categories=()=>secureData.categories||[];
  const pricingCustomer=()=>window.KeySuiteApp?.getPricingCustomer?.()||window.KeySuiteApp?.getSelectedCustomer?.()||null;
  function categoryFor(customer=pricingCustomer()){
    if(!customer)return null;const wanted=customer.pricingCategoryId||customer.pricing_category_id||customer.categoryId||customer.category_id||'';
    return categories().find(row=>String(row.id)===String(wanted))||null;
  }
  function parseMotorModel(value){
    const model=String(value||'').trim().toUpperCase(),match=model.match(/^(BM|2BM|3BM|4BM|5BM)(\d+(?:\.\d+)?)-(\d+)$/);if(!match)return null;
    const hp=Number(match[2]),pole=Number(match[3]),efficiencyClass=PREFIX_TO_IE[match[1]];if(!(hp>0)||!Number.isInteger(pole)||pole<=0)return null;
    return {model,prefix:match[1],efficiencyClass,hp,pole,description:`${hpLabel(hp)}HP ${pole}Pole ${efficiencyClass} Motor`};
  }
  function buildMotorModel(efficiencyClass,hp,pole){const prefix=IE_TO_PREFIX[String(efficiencyClass||'').toUpperCase()];return prefix?parseMotorModel(`${prefix}${hpLabel(hp)}-${Number(pole)}`):null}
  function priceBook(product){return product?.pricesByCurrency||{USD:{MOTOR:number(product?.priceUsd??product?.price_usd)},RMB:{MOTOR:number(product?.priceRmb??product?.price_rmb)},MYR:{MOTOR:number(product?.priceMyr??product?.price_myr)}}}
  function rarityBook(product){const rarity=String(product?.rarity||'common').toLowerCase();return product?.rarityByCurrency||{USD:{MOTOR:rarity},RMB:{MOTOR:rarity},MYR:{MOTOR:rarity}}}
  function findPrice(idOrModel,options={}){
    const product=products().find(row=>String(row.id)===String(idOrModel)||String(row.model).toLowerCase()===String(idOrModel||'').toLowerCase());
    const customer=options.customer||pricingCustomer(),category=options.category||categoryFor(customer);if(!product||!customer||!category)return null;
    const calc=window.KeySuitePricing?.calculatePrice?.(priceBook(product),'MOTOR',category,'MOTOR',{...options,customer,rarity:product.rarity||'common',rarityBook:rarityBook(product),pricingMode:options.pricingMode||'quotation'});if(!calc)return null;
    return {product,material:'MOTOR',variant:'MOTOR',rarity:calc.rarity,calc,category,customer,family:'MOTOR'};
  }
  function snapshot(found){return window.KeySuitePricing?.sourceSnapshot?.(found)||{product_family:'MOTOR',product_id:found.product.id,material:'MOTOR',variant:'MOTOR',rarity:found.calc.rarity,pricing_mode:found.calc.pricingMode,calculated_price:found.calc.finalPrice}}
  function makeItem(found){return {model:found.product.model,description:found.product.description,qty:1,unitPrice:number(found.calc.finalPrice),pricingSource:snapshot(found),productFamily:'MOTOR',assemblyLevel:'PUMPSET_COMPONENT',assemblySection:'motor',section:'motor',motorData:{productId:found.product.id,efficiencyClass:found.product.efficiencyClass,hp:number(found.product.hp),pole:number(found.product.pole)}}}
  function requireContext(action){return window.KeySuiteApp?.ensureQuotationPricingContext?.(action)!==false}
  async function addProduct(product,route){
    if(!product||!requireContext(`add a Motor to the ${route==='assembly'?'Assembly':'quotation'}`))return;
    const found=findPrice(product.id,{pricingMode:route==='assembly'?'assembly':'quotation'});if(!found){alert('No Motor source price or Motor Category Pricing Rule is available for this model.');return}
    const item=makeItem(found);
    if(route==='assembly'){await window.KeySuiteAssembly?.addItem?.(item,{type:'pumpset',section:'motor'});return}
    if(!window.KeySuitePricing?.ensureQuoteableCalculation?.(found.calc,product.model))return;
    const row=window.KeySuiteApp?.addExternalQuoteItem?.(item);if(row)window.KeySuiteApp?.showPage?.('quotation');
  }
  async function addCustom(route){
    const parsed=parseMotorModel(byId('motorCustomModel')?.value),unitPrice=number(byId('motorCustomPrice')?.value);if(!parsed){message('motorProductMessage','Use a model such as BM20-2, 2BM20-4, 3BM50-5, 4BM20-4 or 5BM20-4.','error');return}
    if(!requireContext(`add a custom Motor to the ${route==='assembly'?'Assembly':'quotation'}`))return;
    if(route==='quotation'&&unitPrice<=0){message('motorProductMessage','Enter a positive custom unit price before adding this motor to Quotation.','error');return}
    const item={model:parsed.model,description:parsed.description,qty:1,unitPrice,pricingSource:{product_family:'MANUAL',pricing_mode:route==='assembly'?'assembly':'quotation',source_kind:'CUSTOM_MOTOR',motor_model:parsed.model},productFamily:'MOTOR',assemblyLevel:'PUMPSET_COMPONENT',assemblySection:'motor',section:'motor',motorData:{custom:true,...parsed}};
    if(route==='assembly'){await window.KeySuiteAssembly?.addItem?.(item,{type:'pumpset',section:'motor'});return}
    const row=window.KeySuiteApp?.addExternalQuoteItem?.(item);if(row)window.KeySuiteApp?.showPage?.('quotation');
  }
  function message(id,text,type='info'){const box=byId(id);if(!box)return;box.textContent=text||'';box.className=text?`auth-message show ${type}`:'auth-message'}
  function filteredProducts(){const ie=byId('motorEfficiencyFilter')?.value||'',hp=String(byId('motorHpFilter')?.value||'').trim(),pole=byId('motorPoleFilter')?.value||'',search=String(byId('motorSearch')?.value||'').trim().toLowerCase();return products().filter(p=>(!ie||p.efficiencyClass===ie)&&(!hp||hpLabel(p.hp).includes(hp))&&(!pole||String(p.pole)===pole)&&(!search||`${p.model} ${p.description}`.toLowerCase().includes(search)))}
  function renderProduct(){
    const body=byId('motorProductRows');if(!body)return;const customer=pricingCustomer(),category=categoryFor(customer);
    const notice=byId('motorProductNotice');if(notice)notice.textContent=customer&&category?`Pricing customer: ${customer.company||customer.name||'Selected customer'} · ${category.name}`:'Select a quotation customer with a Pricing Category before pricing a motor.';
    body.innerHTML=filteredProducts().map(p=>{const found=findPrice(p.id,{pricingMode:'assembly'});return `<tr><td><b>${esc(p.model)}</b></td><td>${esc(p.efficiencyClass)}</td><td>${esc(hpLabel(p.hp))}</td><td>${esc(p.pole)}</td><td>${esc(p.description)}</td><td>${found?money(found.calc.finalPrice):'<span class="muted">Not priced</span>'}</td><td><div class="actions" style="margin:0;justify-content:flex-end"><button class="btn action-assembly" type="button" data-motor-assembly="${esc(p.id)}">Assembly</button><button class="btn green" type="button" data-motor-quote="${esc(p.id)}">Quote</button></div></td></tr>`}).join('')||'<tr><td colspan="7" class="muted">No Motor models match the filters.</td></tr>';
    body.querySelectorAll('[data-motor-assembly]').forEach(button=>button.addEventListener('click',()=>addProduct(products().find(p=>p.id===button.dataset.motorAssembly),'assembly')));
    body.querySelectorAll('[data-motor-quote]').forEach(button=>button.addEventListener('click',()=>addProduct(products().find(p=>p.id===button.dataset.motorQuote),'quotation')));
    const count=byId('motorProductCount');if(count)count.textContent=`${filteredProducts().length} of ${products().length} models`;
  }
  function priceField(currency){return currency==='USD'?'priceUsd':currency==='RMB'?'priceRmb':'priceMyr'}
  function filteredPrices(){const ie=byId('motorPriceEfficiency')?.value||'',search=String(byId('motorPriceSearch')?.value||'').trim().toLowerCase();return products().filter(p=>(!ie||p.efficiencyClass===ie)&&(!search||`${p.model} ${p.description} ${p.hp} ${p.pole}`.toLowerCase().includes(search)))}
  function renderPriceList(){
    const body=byId('motorPriceRows');if(!body)return;const currency=byId('motorPriceCurrency')?.value||'MYR',field=priceField(currency),editable=canEditPrices();
    body.innerHTML=filteredPrices().map(p=>`<tr data-motor-price-row="${esc(p.id)}"><td><b>${esc(p.model)}</b></td><td>${esc(p.efficiencyClass)}</td><td>${esc(hpLabel(p.hp))}</td><td>${esc(p.pole)}</td><td><select class="motor-row-rarity" ${editable?'':'disabled'}>${RARITIES.map(r=>`<option value="${r}" ${r===p.rarity?'selected':''}>${r[0].toUpperCase()+r.slice(1)}</option>`).join('')}</select></td><td><input class="motor-row-price" type="number" min="0" step="0.01" value="${number(p[field])}" ${editable?'':'readonly'}></td><td><button class="btn secondary motor-row-save" type="button" ${editable?'':'disabled'}>Save</button></td></tr>`).join('')||'<tr><td colspan="7" class="muted">No Motor models match the filters.</td></tr>';
    body.querySelectorAll('[data-motor-price-row]').forEach(row=>row.querySelector('.motor-row-save')?.addEventListener('click',()=>savePrice(row.dataset.motorPriceRow,row)));
    const rates=secureData.productMultipliers?.MOTOR||{};if(byId('motorUsdRate'))byId('motorUsdRate').value=number(rates.USD);if(byId('motorRmbRate'))byId('motorRmbRate').value=number(rates.RMB);
    ['saveMotorUsdRate','saveMotorRmbRate'].forEach(id=>{if(byId(id))byId(id).disabled=!editable});const count=byId('motorPriceCount');if(count)count.textContent=`${filteredPrices().length} of ${products().length} models`;
  }
  async function savePrice(id,row){
    if(!canEditPrices())return;const currency=byId('motorPriceCurrency')?.value||'MYR',price=number(row.querySelector('.motor-row-price')?.value),rarity=row.querySelector('.motor-row-rarity')?.value||'common',client=window.KeySuiteAuth?.getClient?.();if(!client)return;
    try{const {error}=await client.rpc('keysuite_save_motor_price_v223',{p_product_id:id,p_currency:currency,p_price:price,p_rarity:rarity});if(error)throw error;const product=products().find(p=>p.id===id);if(product){product[priceField(currency)]=price;product.pricesByCurrency[currency].MOTOR=price;product.rarity=rarity;CURRENCIES.forEach(code=>product.rarityByCurrency[code].MOTOR=rarity)}message('motorPriceMessage',`${product?.model||'Motor'} ${currency} price saved.`,'info');renderProduct()}catch(error){message('motorPriceMessage',`${error.message||error}. Run V223_SUPABASE_MIGRATION.sql first.`,'error')}
  }
  async function saveRate(currency){
    if(!canEditPrices())return;const input=byId(currency==='USD'?'motorUsdRate':'motorRmbRate'),value=number(input?.value),client=window.KeySuiteAuth?.getClient?.();if(!client||value<=0){message('motorPriceMessage',`${currency} rate must be greater than zero.`,'error');return}
    try{const {error}=await client.rpc('keysuite_save_motor_multiplier_v223',{p_currency:currency,p_multiplier:value});if(error)throw error;secureData.productMultipliers.MOTOR={...(secureData.productMultipliers.MOTOR||{}),[currency]:value,MYR:1};window.KeySuitePricing?.syncPriceListSettings?.(secureData);message('motorPriceMessage',`Motor ${currency} rate saved.`,'info');renderProduct()}catch(error){message('motorPriceMessage',error.message||String(error),'error')}
  }
  function decodeCustom(){const parsed=parseMotorModel(byId('motorCustomModel')?.value),box=byId('motorCustomDecoded');if(box)box.textContent=parsed?parsed.description:'Invalid Motor model format.'}
  function bind(){
    if(bound)return;bound=true;['motorEfficiencyFilter','motorHpFilter','motorPoleFilter','motorSearch'].forEach(id=>{byId(id)?.addEventListener('input',renderProduct);byId(id)?.addEventListener('change',renderProduct)});['motorPriceCurrency','motorPriceEfficiency','motorPriceSearch'].forEach(id=>{byId(id)?.addEventListener('input',renderPriceList);byId(id)?.addEventListener('change',renderPriceList)});
    byId('motorCustomModel')?.addEventListener('input',decodeCustom);byId('motorCustomAssembly')?.addEventListener('click',()=>addCustom('assembly'));byId('motorCustomQuote')?.addEventListener('click',()=>addCustom('quotation'));byId('saveMotorUsdRate')?.addEventListener('click',()=>saveRate('USD'));byId('saveMotorRmbRate')?.addEventListener('click',()=>saveRate('RMB'));
    window.addEventListener('keysuite-customer-pricing-changed',renderProduct);decodeCustom();
  }
  function init(data,userAccess){secureData=data||secureData;access=userAccess||access;bind();renderProduct();renderPriceList()}
  function pageShown(id){if(id==='productMotor')renderProduct();if(id==='motorPriceList')renderPriceList()}
  window.KeySuiteMotor={init,pageShown,renderProduct,renderPriceList,findPrice,parseMotorModel,buildMotorModel,addProduct,PREFIX_TO_IE,IE_TO_PREFIX};
})();
