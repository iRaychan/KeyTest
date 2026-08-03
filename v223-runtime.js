(() => {
  'use strict';

  const root = typeof window !== 'undefined' ? window : globalThis;
  const PREFIX_TO_IE = Object.freeze({BM:'IE1','2BM':'IE2','3BM':'IE3','4BM':'IE4','5BM':'IE5'});
  const IE_TO_PREFIX = Object.freeze({IE1:'BM',IE2:'2BM',IE3:'3BM',IE4:'4BM',IE5:'5BM'});
  const CURRENCIES = ['USD','RMB','MYR'];
  const RARITIES = ['common','many','rare'];
  const state = {products:[],currency:'MYR',rates:{USD:1,RMB:1,MYR:1},loaded:false,bound:false,prefix:''};
  const $ = id => typeof document === 'undefined' ? null : document.getElementById(id);
  const esc = value => String(value ?? '').replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  const num = value => Number.isFinite(Number(value)) ? Number(value) : 0;
  const money = value => `RM ${num(value).toLocaleString('en-MY',{minimumFractionDigits:2,maximumFractionDigits:2})}`;
  const hpLabel = value => Number.isInteger(Number(value)) ? String(Number(value)) : String(Number(value)).replace(/0+$/,'').replace(/\.$/,'');
  const client = () => root.KeySuiteAuth?.getClient?.() || null;
  const isOwner = () => String(root.KEYSUITE_ACCESS?.role || '').toLowerCase() === 'owner';

  function parseMotorModel(value){
    const model = String(value || '').trim().toUpperCase();
    const match = model.match(/^(BM|2BM|3BM|4BM|5BM)(\d+(?:\.\d+)?)-(\d+)$/);
    if(!match) return null;
    const hp = Number(match[2]), pole = Number(match[3]), efficiencyClass = PREFIX_TO_IE[match[1]];
    if(!Number.isFinite(hp) || hp <= 0 || !Number.isInteger(pole) || pole <= 0) return null;
    return {model,prefix:match[1],efficiencyClass,hp,pole,description:`${hpLabel(hp)}HP ${pole}Pole ${efficiencyClass} Motor`};
  }

  function buildMotorModel(efficiencyClass,hp,pole){
    const ie = String(efficiencyClass || '').toUpperCase(), prefix = IE_TO_PREFIX[ie];
    if(!prefix || !(Number(hp)>0) || !(Number(pole)>0)) return null;
    return parseMotorModel(`${prefix}${hpLabel(hp)}-${Number(pole)}`);
  }

  function sourceField(currency){return currency === 'USD' ? 'price_usd' : currency === 'RMB' ? 'price_rmb' : 'price_myr'}
  function pricingCustomer(){return root.KeySuiteApp?.getPricingCustomer?.() || root.KeySuiteApp?.getSelectedCustomer?.() || null}
  function categories(){return root.KEYSUITE_SECURE_DATA?.categories || []}
  function categoryFor(customer=pricingCustomer()){
    if(!customer) return null;
    const id = customer.pricingCategoryId || customer.pricing_category_id || customer.categoryId || customer.category_id || '';
    const name = customer.pricingCategory || customer.pricing_category || customer.category || '';
    return categories().find(row => String(row.id)===String(id)) || categories().find(row => String(row.name||row.category_name||'').toLowerCase()===String(name).toLowerCase()) || categories()[0] || null;
  }
  function priceBook(product){return {USD:{MOTOR:num(product.price_usd)},RMB:{MOTOR:num(product.price_rmb)},MYR:{MOTOR:num(product.price_myr)}}}
  function calculate(product,pricingMode='assembly'){
    const category = categoryFor();
    if(!product || !category || !root.KeySuitePricing?.calculatePrice) return null;
    return root.KeySuitePricing.calculatePrice(priceBook(product),'MOTOR',category,'MOTOR',{rarity:product.rarity||'common',pricingMode});
  }
  function sourceSnapshot(product,calc,pricingMode){
    return {
      ...(root.KeySuitePricing?.sourceSnapshot?.({product,variant:{material:'MOTOR'},calc,category:categoryFor(),customer:pricingCustomer()}) || {}),
      product_family:'MOTOR',product_id:product.id,variant:'MOTOR',material:'MOTOR',rarity:product.rarity||'common',
      source_currency:calc?.sourceCurrency||'',source_price:num(calc?.sourcePrice),currency_multiplier:num(calc?.multiplier),
      calculated_price:num(calc?.finalPrice),pricing_mode:pricingMode
    };
  }
  function motorItem(product,route='assembly'){
    const calc = calculate(product,route==='assembly'?'assembly':'quotation');
    return {
      model:product.model,description:product.description,qty:1,unitPrice:num(calc?.finalPrice),
      pricingSource:sourceSnapshot(product,calc,route==='assembly'?'assembly':'quotation'),
      productFamily:'MOTOR',assemblyLevel:'PUMPSET_COMPONENT',assemblySection:'motor',section:'motor',
      motorData:{productId:product.id,efficiencyClass:product.efficiency_class,hp:num(product.hp),pole:num(product.pole)}
    };
  }

  function addProduct(product,route){
    if(!product) return;
    if(!root.KeySuiteApp?.ensureQuotationPricingContext?.(`add a Motor to the ${route==='assembly'?'Assembly':'quotation'}`)) return;
    const item = motorItem(product,route), calc = calculate(product,route==='assembly'?'assembly':'quotation');
    if(route === 'assembly'){
      root.KeySuiteAssembly?.addItem?.(item,'pumpset');
      return;
    }
    if(!calc || num(calc.finalPrice)<=0){alert('Enter a positive Motor source price and Motor Category Pricing Rule before adding this motor to Quotation.');return}
    if(root.KeySuiteApp?.canEditQuotation && !root.KeySuiteApp.canEditQuotation(true)) return;
    const row = root.KeySuiteApp?.addExternalQuoteItem?.(item) || root.addExternalQuoteItem?.(item);
    if(row) root.KeySuiteApp?.showPage?.('quotation');
  }

  function addCustom(route){
    const parsed = parseMotorModel($('motorCustomModel')?.value), price = num($('motorCustomPrice')?.value);
    if(!parsed){setMessage('motorProductMessage','Use a model such as BM20-2, 2BM20-4, 3BM50-5, 4BM20-4 or 5BM20-4.','error');return}
    const item={model:parsed.model,description:parsed.description,qty:1,unitPrice:price,pricingSource:{product_family:'MOTOR',product_id:'CUSTOM',variant:'CUSTOM',material:'MOTOR',pricing_mode:route==='assembly'?'assembly':'quotation'},productFamily:'MOTOR',assemblyLevel:'PUMPSET_COMPONENT',assemblySection:'motor',section:'motor',motorData:{custom:true,...parsed}};
    if(route==='assembly'){root.KeySuiteAssembly?.addItem?.(item,'pumpset');return}
    if(price<=0){setMessage('motorProductMessage','Enter a positive custom unit price before adding the custom motor to Quotation.','error');return}
    const row=root.KeySuiteApp?.addExternalQuoteItem?.(item)||root.addExternalQuoteItem?.(item);if(row)root.KeySuiteApp?.showPage?.('quotation');
  }

  function setMessage(id,text,type='info'){
    const box=$(id);if(!box)return;box.textContent=text||'';box.className=text?`auth-message show ${type}`:'auth-message';
  }
  function showPage(id){
    if(root.KeySuiteApp?.showPage) root.KeySuiteApp.showPage(id); else if(typeof root.showPage==='function') root.showPage(id);
    if(id==='productMotor') renderProduct();
    if(id==='motorPriceList') renderPriceList();
  }

  function pageHtml(){
    return `<section id="productMotor" class="page hidden">
      <div class="card"><div class="section-heading"><div><h2>Motor</h2><p>IE1 to IE5 motor selection. Assembly always routes to Pumpset → Motor.</p></div></div>
      <div id="motorProductMessage" class="auth-message"></div>
      <div class="motor-filter-grid">
        <label>Efficiency<select id="motorEfficiencyFilter"><option value="">All</option>${Object.keys(IE_TO_PREFIX).map(x=>`<option>${x}</option>`).join('')}</select></label>
        <label>HP<input id="motorHpFilter" type="search" placeholder="e.g. 20"></label>
        <label>Pole<select id="motorPoleFilter"><option value="">All</option><option>2</option><option>4</option><option>6</option><option>8</option></select></label>
        <label>Search<input id="motorSearch" type="search" placeholder="Model or description"></label>
      </div>
      <div class="table-wrap"><table><thead><tr><th>Model</th><th>Efficiency</th><th>HP</th><th>Pole</th><th>Description</th><th>Assembly Price</th><th>Action</th></tr></thead><tbody id="motorProductRows"></tbody></table></div>
      </div>
      <div class="card"><h3>Custom Motor Model</h3><p class="muted">Custom poles are accepted, including <b>3BM50-5</b>.</p>
        <div class="motor-custom-grid"><label>Model<input id="motorCustomModel" value="3BM50-5"></label><label>Manual Unit Price (RM)<input id="motorCustomPrice" type="number" min="0" step="0.01" value="0"></label><div class="route-actions"><button class="btn action-assembly" id="motorCustomAssembly" type="button">Assembly</button><button class="btn action-quote" id="motorCustomQuote" type="button">Quote</button></div></div>
        <div id="motorCustomDecoded" class="pricing-formula"></div>
      </div>
    </section>
    <section id="motorPriceList" class="page hidden">
      <div class="card"><div class="section-heading"><div><h2>Motor Price List</h2><p>IE1–IE5, independent USD/RMB/MYR source prices and model rarity.</p></div></div>
      <div id="motorPriceMessage" class="auth-message"></div>
      <div class="motor-filter-grid">
        <label>Currency<select id="motorPriceCurrency">${CURRENCIES.map(x=>`<option>${x}</option>`).join('')}</select></label>
        <label>Efficiency<select id="motorPriceEfficiency"><option value="">All</option>${Object.keys(IE_TO_PREFIX).map(x=>`<option>${x}</option>`).join('')}</select></label>
        <label>Search<input id="motorPriceSearch" type="search" placeholder="Model / HP / pole"></label>
        <div class="motor-rate-box"><label>USD Rate<input id="motorUsdRate" type="number" min="0.0001" step="0.0001"></label><button id="saveMotorUsdRate" class="btn secondary" type="button">Save USD</button></div>
        <div class="motor-rate-box"><label>RMB Rate<input id="motorRmbRate" type="number" min="0.0001" step="0.0001"></label><button id="saveMotorRmbRate" class="btn secondary" type="button">Save RMB</button></div>
      </div>
      <div class="table-wrap motor-price-wrap"><table><thead><tr><th>Model</th><th>Efficiency</th><th>HP</th><th>Pole</th><th>Rarity</th><th>Source Price</th><th>Save</th></tr></thead><tbody id="motorPriceRows"></tbody></table></div>
      </div>
      <div class="card"><h3>Motor Category Pricing Rule</h3><div id="motorRuleMessage" class="auth-message"></div>
        <div class="motor-rule-grid"><label>Category<select id="motorRuleCategory"></select></label><label>Margin %<input id="motorRuleMargin" type="number" min="0" max="99.99" step="0.01"></label><label>Normal %<input id="motorRuleNormal" type="number" min="0" max="99.99" step="0.01"></label><label>Rare %<input id="motorRuleRare" type="number" min="0" max="99.99" step="0.01"></label><label>Transport RM<input id="motorRuleTransport" type="number" min="0" step="0.01"></label></div>
        <div class="motor-checks"><label><input id="motorRuleCommission" type="checkbox"> Use Commission</label><label><input id="motorRuleSetDiscount" type="checkbox"> Use Set Discount</label><label><input id="motorRuleFinalDiscount" type="checkbox"> Use Final Discount</label><label><input id="motorRuleFuel" type="checkbox"> Use Fuel Charge</label></div>
        <button id="saveMotorRule" class="btn" type="button">Save Motor Rule</button>
      </div>
    </section>`;
  }

  function injectStyle(){
    if(typeof document==='undefined'||$('v223RuntimeStyle'))return;
    const style=document.createElement('style');style.id='v223RuntimeStyle';style.textContent=`
      .motor-filter-grid{display:grid;grid-template-columns:repeat(4,minmax(150px,1fr));gap:12px;align-items:end;margin:12px 0}.motor-filter-grid label,.motor-custom-grid label,.motor-rule-grid label{display:grid;gap:5px;font-size:12px;color:var(--muted)}
      .motor-filter-grid input,.motor-filter-grid select,.motor-custom-grid input,.motor-rule-grid input,.motor-rule-grid select{width:100%}.motor-custom-grid{display:grid;grid-template-columns:minmax(220px,1fr) minmax(180px,.7fr) auto;gap:12px;align-items:end}.motor-rule-grid{display:grid;grid-template-columns:repeat(5,minmax(130px,1fr));gap:10px;margin:12px 0}.motor-checks{display:flex;gap:16px;flex-wrap:wrap;margin:10px 0 14px}.motor-rate-box{display:flex;gap:6px;align-items:end}.motor-price-wrap{max-height:65vh;overflow:auto}.motor-price-wrap thead{position:sticky;top:0;z-index:2}.v223-prefix-card{margin-top:16px}.v223-prefix-row{display:grid;grid-template-columns:minmax(150px,260px) auto;gap:10px;align-items:end}.v223-prefix-row input{text-transform:uppercase}@media(max-width:900px){.motor-filter-grid,.motor-rule-grid{grid-template-columns:1fr 1fr}.motor-custom-grid{grid-template-columns:1fr}}@media(max-width:520px){.motor-filter-grid,.motor-rule-grid{grid-template-columns:1fr}}
    `;document.head.appendChild(style);
  }

  function cloneNav(sourcePage,targetPage,label){
    if(typeof document==='undefined'||document.querySelector(`[data-page="${targetPage}"]`))return;
    const source=document.querySelector(`[data-page="${sourcePage}"]`);if(!source)return;
    const button=source.cloneNode(true);button.dataset.page=targetPage;button.removeAttribute('id');
    const textNode=[...button.childNodes].find(node=>node.nodeType===3&&node.textContent.trim());
    if(textNode)textNode.textContent=label;else button.textContent=label;
    button.addEventListener('click',event=>{event.preventDefault();showPage(targetPage)});source.insertAdjacentElement('afterend',button);
  }

  function injectPages(){
    if(typeof document==='undefined'||$('productMotor'))return;
    const main=document.querySelector('main')||$('appView')||document.body;main.insertAdjacentHTML('beforeend',pageHtml());
    cloneNav('productManifold','productMotor','Motor');
    cloneNav('manifoldPriceList','motorPriceList','Motor');
    if(!document.querySelector('[data-page="productMotor"]')){
      const nav=document.querySelector('aside nav,aside,.nav');if(nav){const b=document.createElement('button');b.type='button';b.className='nav-item';b.dataset.page='productMotor';b.textContent='Motor';b.onclick=()=>showPage('productMotor');nav.appendChild(b)}
    }
    bind();
  }

  function productFilter(){
    const ie=$('motorEfficiencyFilter')?.value||'', hp=String($('motorHpFilter')?.value||'').trim(), pole=$('motorPoleFilter')?.value||'', search=String($('motorSearch')?.value||'').trim().toLowerCase();
    return state.products.filter(p=>(!ie||p.efficiency_class===ie)&&(!hp||hpLabel(p.hp).includes(hp))&&(!pole||String(p.pole)===pole)&&(!search||`${p.model} ${p.description}`.toLowerCase().includes(search)));
  }
  function renderProduct(){
    const body=$('motorProductRows');if(!body)return;
    body.innerHTML=productFilter().map(p=>{const calc=calculate(p,'assembly');return `<tr><td><b>${esc(p.model)}</b></td><td>${esc(p.efficiency_class)}</td><td>${esc(hpLabel(p.hp))}</td><td>${esc(p.pole)}</td><td>${esc(p.description)}</td><td>${calc?money(calc.finalPrice):'<span class="muted">Not priced</span>'}</td><td><div class="route-actions"><button class="btn secondary action-assembly" data-motor-assembly="${esc(p.id)}">Assembly</button><button class="btn action-quote" data-motor-quote="${esc(p.id)}">Quote</button></div></td></tr>`}).join('')||'<tr><td colspan="7" class="muted">No Motor models match the filters.</td></tr>';
    body.querySelectorAll('[data-motor-assembly]').forEach(b=>b.onclick=()=>addProduct(state.products.find(p=>p.id===b.dataset.motorAssembly),'assembly'));
    body.querySelectorAll('[data-motor-quote]').forEach(b=>b.onclick=()=>addProduct(state.products.find(p=>p.id===b.dataset.motorQuote),'quotation'));
  }

  function priceFilter(){
    const ie=$('motorPriceEfficiency')?.value||'', search=String($('motorPriceSearch')?.value||'').trim().toLowerCase();
    return state.products.filter(p=>(!ie||p.efficiency_class===ie)&&(!search||`${p.model} ${p.hp} ${p.pole}`.toLowerCase().includes(search)));
  }
  function renderPriceList(){
    const body=$('motorPriceRows');if(!body)return;const currency=$('motorPriceCurrency')?.value||state.currency,field=sourceField(currency);state.currency=currency;
    body.innerHTML=priceFilter().map(p=>`<tr data-motor-price-row="${esc(p.id)}"><td><b>${esc(p.model)}</b></td><td>${esc(p.efficiency_class)}</td><td>${esc(hpLabel(p.hp))}</td><td>${esc(p.pole)}</td><td><select class="motor-row-rarity">${RARITIES.map(r=>`<option value="${r}" ${r===p.rarity?'selected':''}>${r[0].toUpperCase()+r.slice(1)}</option>`).join('')}</select></td><td><input class="motor-row-price" type="number" min="0" step="0.01" value="${num(p[field])}"></td><td><button class="btn secondary motor-row-save" type="button" ${isOwner()?'':'disabled'}>Save</button></td></tr>`).join('')||'<tr><td colspan="7" class="muted">No Motor models match the filters.</td></tr>';
    body.querySelectorAll('[data-motor-price-row]').forEach(row=>row.querySelector('.motor-row-save').onclick=()=>savePrice(row.dataset.motorPriceRow,row));
    if($('motorUsdRate'))$('motorUsdRate').value=state.rates.USD;if($('motorRmbRate'))$('motorRmbRate').value=state.rates.RMB;
    renderRule();
  }

  async function savePrice(id,row){
    if(!isOwner()){setMessage('motorPriceMessage','Only the Owner can maintain Motor prices.','error');return}
    const currency=$('motorPriceCurrency')?.value||'MYR',price=num(row.querySelector('.motor-row-price')?.value),rarity=row.querySelector('.motor-row-rarity')?.value||'common',c=client();if(!c)return;
    try{const {error}=await c.rpc('keysuite_save_motor_price_v223',{p_product_id:id,p_currency:currency,p_price:price,p_rarity:rarity});if(error)throw error;const p=state.products.find(x=>x.id===id);if(p){p[sourceField(currency)]=price;p.rarity=rarity}setMessage('motorPriceMessage',`${p?.model||'Motor'} ${currency} price saved.`,'info');renderProduct()}catch(error){setMessage('motorPriceMessage',`${error.message||error}. Run V223_SUPABASE_MIGRATION.sql first.`,'error')}
  }
  async function saveRate(currency){
    if(!isOwner())return;const input=$(currency==='USD'?'motorUsdRate':'motorRmbRate'),value=num(input?.value),c=client();if(!c||value<=0){setMessage('motorPriceMessage',`${currency} rate must be greater than zero.`,'error');return}
    try{const {error}=await c.rpc('keysuite_save_motor_multiplier_v223',{p_currency:currency,p_multiplier:value});if(error)throw error;state.rates[currency]=value;root.KEYSUITE_SECURE_DATA.productMultipliers=root.KEYSUITE_SECURE_DATA.productMultipliers||{};root.KEYSUITE_SECURE_DATA.productMultipliers.MOTOR={...state.rates};setMessage('motorPriceMessage',`Motor ${currency} rate saved.`,'info');renderProduct()}catch(error){setMessage('motorPriceMessage',error.message||String(error),'error')}
  }

  function rawRule(category){
    const raw=category?.productRules?.MOTOR||category?.product_rules?.MOTOR||{};return {margin:num(raw.margin),normal:num(raw.normal),rare:num(raw.rare),transport:num(raw.transport),useCommission:raw.useCommission??raw.use_commission??true,useSetDiscount:raw.useSetDiscount??raw.use_set_discount??true,useFinalDiscount:raw.useFinalDiscount??raw.use_final_discount??true,useFuelCharge:raw.useFuelCharge??raw.use_fuel_charge??true};
  }
  function renderRule(){
    const select=$('motorRuleCategory');if(!select)return;const list=categories();if(!select.options.length)select.innerHTML=list.map(c=>`<option value="${esc(c.id)}">${esc(c.name||c.category_name)}</option>`).join('');const category=list.find(c=>String(c.id)===String(select.value))||list[0],rule=rawRule(category);if(category)select.value=category.id;
    [['motorRuleMargin',rule.margin*100],['motorRuleNormal',rule.normal*100],['motorRuleRare',rule.rare*100],['motorRuleTransport',rule.transport]].forEach(([id,value])=>{if($(id))$(id).value=Number(value).toFixed(id==='motorRuleTransport'?2:2)});
    [['motorRuleCommission',rule.useCommission],['motorRuleSetDiscount',rule.useSetDiscount],['motorRuleFinalDiscount',rule.useFinalDiscount],['motorRuleFuel',rule.useFuelCharge]].forEach(([id,value])=>{if($(id))$(id).checked=!!value});
    if($('saveMotorRule'))$('saveMotorRule').disabled=!isOwner();
  }
  async function saveRule(){
    if(!isOwner())return;const id=$('motorRuleCategory')?.value,c=client();if(!c||!id)return;const pct=id=>num($(id)?.value)/100,payload={p_category_id:id,p_margin:pct('motorRuleMargin'),p_normal:pct('motorRuleNormal'),p_rare:pct('motorRuleRare'),p_transport:num($('motorRuleTransport')?.value),p_use_commission:!!$('motorRuleCommission')?.checked,p_use_set_discount:!!$('motorRuleSetDiscount')?.checked,p_use_final_discount:!!$('motorRuleFinalDiscount')?.checked,p_use_fuel_charge:!!$('motorRuleFuel')?.checked};
    try{const {data,error}=await c.rpc('keysuite_save_motor_category_rule_v223',payload);if(error)throw error;const category=categories().find(x=>String(x.id)===String(id));if(category){const row=Array.isArray(data)?data[0]:data||{};category.productRules=category.productRules||{};category.productRules.MOTOR=row.product_rule||row.productRule||{margin:payload.p_margin,normal:payload.p_normal,rare:payload.p_rare,transport:payload.p_transport,useCommission:payload.p_use_commission,useSetDiscount:payload.p_use_set_discount,useFinalDiscount:payload.p_use_final_discount,useFuelCharge:payload.p_use_fuel_charge}}setMessage('motorRuleMessage','Motor Category Pricing Rule saved.','info');renderProduct()}catch(error){setMessage('motorRuleMessage',error.message||String(error),'error')}
  }

  function decodeCustom(){const parsed=parseMotorModel($('motorCustomModel')?.value);if($('motorCustomDecoded'))$('motorCustomDecoded').textContent=parsed?parsed.description:'Invalid Motor model format.'}
  function bind(){
    if(state.bound||typeof document==='undefined')return;state.bound=true;
    ['motorEfficiencyFilter','motorHpFilter','motorPoleFilter','motorSearch'].forEach(id=>$(id)?.addEventListener('input',renderProduct));
    ['motorPriceCurrency','motorPriceEfficiency','motorPriceSearch'].forEach(id=>$(id)?.addEventListener('input',renderPriceList));
    $('motorCustomModel')?.addEventListener('input',decodeCustom);$('motorCustomAssembly')?.addEventListener('click',()=>addCustom('assembly'));$('motorCustomQuote')?.addEventListener('click',()=>addCustom('quotation'));
    $('saveMotorUsdRate')?.addEventListener('click',()=>saveRate('USD'));$('saveMotorRmbRate')?.addEventListener('click',()=>saveRate('RMB'));
    $('motorRuleCategory')?.addEventListener('change',renderRule);$('saveMotorRule')?.addEventListener('click',saveRule);decodeCustom();
  }

  async function load(){
    const c=client();if(!c)return false;
    try{
      const [productsResult,settingsResult,categoriesResult]=await Promise.all([
        c.from('ks_products_motor').select('*').eq('active',true).order('efficiency_class').order('hp').order('pole'),
        c.from('ks_app_settings').select('motor_usd_multiplier,motor_rmb_multiplier').eq('id','default').limit(1),
        c.from('ks_pricing_categories').select('id,category_name,product_rules').order('category_name')
      ]);
      if(productsResult.error)throw productsResult.error;if(settingsResult.error)throw settingsResult.error;
      state.products=productsResult.data||[];const settings=settingsResult.data?.[0]||{};state.rates={USD:num(settings.motor_usd_multiplier)||1,RMB:num(settings.motor_rmb_multiplier)||1,MYR:1};
      const secure=root.KEYSUITE_SECURE_DATA||(root.KEYSUITE_SECURE_DATA={});secure.motorProducts=state.products;secure.productMultipliers=secure.productMultipliers||{};secure.productMultipliers.MOTOR={...state.rates};
      if(!categoriesResult.error){for(const raw of categoriesResult.data||[]){const category=categories().find(x=>String(x.id)===String(raw.id));if(category){category.productRules=category.productRules||{};category.productRules.MOTOR=raw.product_rules?.MOTOR||category.productRules.MOTOR}else categories().push({id:raw.id,name:raw.category_name,productRules:{MOTOR:raw.product_rules?.MOTOR||{}}})}}
      state.loaded=true;renderProduct();renderPriceList();return true;
    }catch(error){setMessage('motorProductMessage',`${error.message||error}. Run V223_SUPABASE_MIGRATION.sql first.`,'error');setMessage('motorPriceMessage',`${error.message||error}. Run V223_SUPABASE_MIGRATION.sql first.`,'error');return false}
  }

  function scanRunningFloor(prefix,date=new Date()){
    if(typeof localStorage==='undefined'||!prefix)return 0;const yy=String(date.getFullYear()).slice(-2),rx=new RegExp(`^${String(prefix).replace(/[.*+?^${}()|[\]\\]/g,'\\$&')}-${yy}\\d{2}-(\\d+)$`,'i');let max=0;
    const visit=value=>{if(typeof value==='string'){const m=value.match(rx);if(m)max=Math.max(max,Number(m[1])||0);return}if(Array.isArray(value)){value.forEach(visit);return}if(value&&typeof value==='object')Object.values(value).forEach(visit)};
    for(let i=0;i<localStorage.length;i++){try{visit(JSON.parse(localStorage.getItem(localStorage.key(i))))}catch(_){visit(localStorage.getItem(localStorage.key(i)))}}return max;
  }
  async function getPrefix(){const c=client();if(!c)return '';const {data,error}=await c.rpc('keysuite_get_quotation_prefix_v223');if(error)throw error;const row=Array.isArray(data)?data[0]:data||{};state.prefix=String(row.quotation_prefix||row.quotationPrefix||'');return state.prefix}
  async function savePrefix(){const value=String($('v223QuotationPrefix')?.value||'').trim().toUpperCase(),c=client();if(!c)return;try{const {data,error}=await c.rpc('keysuite_save_quotation_prefix_v223',{p_prefix:value});if(error)throw error;const row=Array.isArray(data)?data[0]:data||{};state.prefix=row.quotation_prefix||value;if($('v223QuotationPrefix'))$('v223QuotationPrefix').value=state.prefix;setMessage('v223PrefixMessage','Quotation prefix saved.','info')}catch(error){setMessage('v223PrefixMessage',error.message||String(error),'error')}
  }
  async function nextQuotationReference(){
    const c=client();if(!c)throw new Error('Supabase is not connected.');const prefix=state.prefix||await getPrefix();if(!prefix)throw new Error('Set your quotation prefix before creating a quotation.');const floor=scanRunningFloor(prefix),{data,error}=await c.rpc('keysuite_next_quotation_reference_v223',{p_minimum_last_number:floor});if(error)throw error;const row=Array.isArray(data)?data[0]:data||{};return row.quotation_reference||row.quotationReference;
  }
  function injectPrefix(){
    if(typeof document==='undefined'||$('v223QuotationPrefix'))return;const host=$('ownProfile')||$('profile')||document.querySelector('[id*="profile" i]')||$('keyDashboard')||document.querySelector('main');if(!host)return;
    const card=document.createElement('div');card.className='card v223-prefix-card';card.innerHTML=`<h3>Quotation Reference Prefix</h3><p class="muted">Format: Prefix-YYMM-Running Number. Prefixes must be unique; the running number resets only when the calendar year changes.</p><div id="v223PrefixMessage" class="auth-message"></div><div class="v223-prefix-row"><label>My Prefix<input id="v223QuotationPrefix" maxlength="8" placeholder="e.g. B"></label><button id="v223SavePrefix" class="btn" type="button">Save Prefix</button></div>`;host.appendChild(card);$('v223SavePrefix')?.addEventListener('click',savePrefix);getPrefix().then(value=>{if($('v223QuotationPrefix'))$('v223QuotationPrefix').value=value}).catch(error=>setMessage('v223PrefixMessage',`${error.message||error}. Run V223_SUPABASE_MIGRATION.sql first.`,'error'));
  }

  async function init(){injectStyle();injectPages();injectPrefix();await load()}
  function start(){
    if(typeof document==='undefined')return;const run=()=>{init();let tries=0;const timer=setInterval(async()=>{tries++;if(state.loaded||await load()||tries>30)clearInterval(timer)},500)};
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',run,{once:true});else run();
  }

  root.KeySuiteV223={init,load,parseMotorModel,buildMotorModel,nextQuotationReference,getPrefix,savePrefix,addProduct,state,PREFIX_TO_IE,IE_TO_PREFIX};
  start();
})();
