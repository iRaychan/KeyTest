(() => {
  'use strict';

  const $=id=>document.getElementById(id);
  const esc=value=>String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  let selectedSeries='',frameReady=false,queued=null,currentCurveModel='';

  const products=()=>window.KEYSUITE_SECURE_DATA?.products||[];
  const gwsProducts=()=>window.KEYSUITE_SECURE_DATA?.gwsProducts||[];
  const esProducts=()=>window.KEYSUITE_SECURE_DATA?.esProducts||[];
  const keyplcProducts=()=>window.KEYSUITE_SECURE_DATA?.keyplcProducts||[];
  const ES_DEFAULT_MATERIAL='CI / SS / SS / MS';
  const ES_DEFAULT_SEAL='Carbon Ceramic (Ca Ce)';
  const ES_DEFAULT_ELASTOMER='Viton';
  const ES_SEALS=['Carbon Ceramic (Ca Ce)','Silicon Carbide (Sic Sic)','Tungsten (Tuc Tuc)'];
  const ES_ELASTOMERS=['Viton','EPDM','NBR'];
  const seriesName=model=>{const m=String(model||'').match(/^CHC\s+(\d+)/i);return m?`CHC ${m[1]}`:'Other'};
  const orderedSeries=()=>[...new Set(products().map(p=>seriesName(p.model)))].sort((a,b)=>Number((a.match(/\d+/)||[999])[0])-Number((b.match(/\d+/)||[999])[0]));
  const normMaterial=value=>String(value||'').toUpperCase().replace(/[^A-Z0-9]+/g,'');

  function updateDefaultState(control){
    if(!control)return;
    if(control.type==='checkbox'){
      const defaultChecked=String(control.dataset.defaultChecked||'false')==='true';
      (control.closest('.default-choice-control')||control).classList.toggle('non-default-selection',control.checked!==defaultChecked);
      return;
    }
    if(control.dataset.defaultValue!==undefined)control.classList.toggle('non-default-selection',String(control.value)!==String(control.dataset.defaultValue));
  }

  function bindDefaultState(control){if(!control||control.dataset.defaultStateBound==='1')return;control.dataset.defaultStateBound='1';const refresh=()=>updateDefaultState(control);control.addEventListener('change',refresh);control.addEventListener('input',refresh);refresh()}
  function bindStaticDefaults(){['pumpMaterial','sealFaces','sealElastomer','connectionType','bareShaft','productMaterial','productSeal','productElastomer','productConnection','productBareShaft'].forEach(id=>bindDefaultState($(id)))}

  function ensureFrame(){const frame=$('productSelectorFrame');if(frame&&frame.src==='about:blank'){frameReady=false;frame.src=frame.dataset.src}return frame}
  function options(){return {material:$('productMaterial')?.value||'SS304 (Cast Iron Connection)',seal:$('productSeal')?.value||'Car/Cer',elastomer:$('productElastomer')?.value||'Viton',connection:$('productConnection')?.value||'round',bare:!!$('productBareShaft')?.checked,hz:50}}
  function postToFrame(frame,message){try{frame.contentWindow.postMessage(message,'*')}catch(error){console.error('Unable to contact CHC product frame.',error)}}
  function send(model,action){
    const frame=ensureFrame();if(!frame)return;
    const message={type:'KEYSUITE_PRODUCT_MODEL',model,action,options:options()};
    if(frameReady){queued=null;postToFrame(frame,message)}else queued=message;
  }

  function renderSeries(){
    const series=orderedSeries();if(!selectedSeries||!series.includes(selectedSeries))selectedSeries=series[0]||'';
    $('productSeriesList').innerHTML=series.map(name=>`<button type="button" class="product-series-button ${name===selectedSeries?'active':''}" data-product-series="${esc(name)}">${esc(name)}</button>`).join('');
    $('productSeriesList').querySelectorAll('[data-product-series]').forEach(button=>button.onclick=()=>{selectedSeries=button.dataset.productSeries;renderSeries();renderModels()});
  }

  function curveIcon(){return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 18c4-10 8 2 12-8 2-4 4-5 6-5"></path><path d="M3 20h18"></path></svg>'}

  function renderModels(){
    const query=String($('productModelInput')?.value||'').trim().toLowerCase();let rows=products().filter(p=>seriesName(p.model)===selectedSeries);if(query)rows=rows.filter(p=>String(p.model).toLowerCase().includes(query));
    $('productSeriesTitle').textContent=selectedSeries||'Models';$('productModelCount').textContent=`${rows.length} model${rows.length===1?'':'s'}`;
    $('productModelGrid').innerHTML=rows.length?rows.map(p=>`<div class="product-model-row"><h3>${esc(p.model)}</h3><div class="product-model-actions"><button class="btn secondary product-action-button" type="button" data-product-view="${esc(p.model)}">Curve</button><button class="btn action-assembly product-action-button" type="button" data-product-assembly="${esc(p.model)}">Assembly</button><button class="btn action-quote product-action-button" type="button" data-product-add="${esc(p.model)}">Quote</button></div></div>`).join(''):'<div class="product-empty">No matching CHC models.</div>';
    const grid=$('productModelGrid');
    grid.querySelectorAll('[data-product-view]').forEach(button=>button.onclick=()=>{const model=button.dataset.productView;currentCurveModel=model;$('productCurveTitle').textContent=model;const frame=ensureFrame(),host=$('productCurveHost');if(frame.parentNode!==host)host.appendChild(frame);frame.style.display='block';$('productCurveDialog').showModal();send(model,'view')});
    grid.querySelectorAll('[data-product-add]').forEach(button=>button.onclick=()=>{if(!window.KeySuiteApp?.ensureQuotationPricingContext?.('add a product to the quotation'))return;send(button.dataset.productAdd,'add')});
    grid.querySelectorAll('[data-product-assembly]').forEach(button=>button.onclick=()=>{if(!window.KeySuiteApp?.ensureQuotationPricingContext?.('add a product to Assembly'))return;send(button.dataset.productAssembly,'assembly')});
  }

  function gwsSeriesKey(product){
    const name=String(product?.seriesName||'').trim();
    return /superflow/i.test(name)?'Superflow Series':name;
  }

  function gwsSeriesOptions(){
    const select=$('gwsProductSeries');if(!select)return;
    const current=select.value||'ALL',series=[...new Set(gwsProducts().map(gwsSeriesKey).filter(Boolean))];
    select.innerHTML='<option value="ALL">All Series</option>'+series.map(name=>`<option value="${esc(name)}">${esc(name)}</option>`).join('');select.value=series.includes(current)?current:'ALL';
  }

  function gwsModelOptions(){
    const select=$('gwsProductModel');if(!select)return;
    const series=$('gwsProductSeries')?.value||'ALL',current=select.value||'ALL';
    const rows=gwsProducts().filter(product=>series==='ALL'||gwsSeriesKey(product)===series);
    const models=[...new Set(rows.map(product=>String(product.model||'').trim()).filter(Boolean))].sort((a,b)=>a.localeCompare(b,undefined,{numeric:true}));
    select.innerHTML='<option value="ALL">All Models</option>'+models.map(model=>`<option value="${esc(model)}">${esc(model)}</option>`).join('');
    select.value=models.includes(current)?current:'ALL';
  }

  function renderGws(){
    const body=$('gwsProductRows');if(!body)return;gwsSeriesOptions();gwsModelOptions();
    const series=$('gwsProductSeries')?.value||'ALL',model=$('gwsProductModel')?.value||'ALL';
    const rows=gwsProducts().filter(product=>(series==='ALL'||gwsSeriesKey(product)===series)&&(model==='ALL'||String(product.model)===model));
    body.innerHTML=rows.map(product=>`<tr><td>${esc(product.seriesName)}</td><td><b>${esc(product.model)}</b></td><td>${esc(product.sizeLitres)} Litres</td><td>${esc(product.pressureBar)} Bar</td><td style="text-align:right"><div class="route-actions"><button class="btn action-assembly" type="button" data-gws-assembly="${esc(product.id)}">Add to Assembly</button><button class="btn action-quote" type="button" data-gws-quote="${esc(product.id)}">Quote</button></div></td></tr>`).join('')||'<tr><td colspan="5" class="muted">No matching GWS Tank models.</td></tr>';
    $('gwsProductCount').textContent=`${rows.length} valid tank SKU${rows.length===1?'':'s'}`;
    body.querySelectorAll('[data-gws-quote]').forEach(button=>button.addEventListener('click',()=>window.KeySuitePricing?.addGwsToQuotation?.(button.dataset.gwsQuote,null)));
    body.querySelectorAll('[data-gws-assembly]').forEach(button=>button.addEventListener('click',()=>{if(!window.KeySuiteApp?.ensureQuotationPricingContext?.('add a tank to Assembly'))return;const item=window.KeySuitePricing?.buildGwsAssemblyItem?.(button.dataset.gwsAssembly,null);if(item){item.assemblyLevel='SYSTEM_COMPONENT';item.assemblySection='tank';window.KeySuiteAssembly?.addItem?.(item)}else alert('No price is available for this GWS Tank SKU.')}));
  }


  function renderEs(){
    const body=$('esProductRows');if(!body)return;const q=String($('esProductSearch')?.value||'').trim().toLowerCase();
    const rows=esProducts().filter(x=>!q||x.model.toLowerCase().includes(q));
    body.innerHTML=rows.map(x=>{
      const materials=[...new Set((x.variants||[]).map(v=>String(v.material||'').trim()).filter(value=>value&&!/\bBR\b/i.test(value)))];
      if(!materials.some(value=>normMaterial(value)===normMaterial(ES_DEFAULT_MATERIAL)))materials.unshift(ES_DEFAULT_MATERIAL);
      const materialOrder=['CI SS SS MS','CI SS SS GP','CI CI SS MS','CI CI SS GP','SS 304','SS 316'];
      const materialRank=value=>{const normalized=normMaterial(value);const index=materialOrder.findIndex(item=>normMaterial(item)===normalized);return index<0?999:index};
      const ordered=[...materials].sort((a,b)=>materialRank(a)-materialRank(b)||a.localeCompare(b));
      const options=ordered.map(material=>`<option value="${esc(material)}" ${normMaterial(material)===normMaterial(ES_DEFAULT_MATERIAL)?'selected':''}>${esc(material.replace(/\s*\/\s*/g,' '))}</option>`).join('');
      const sealOptions=ES_SEALS.map(value=>`<option value="${esc(value)}" ${value===ES_DEFAULT_SEAL?'selected':''}>${esc(value)}</option>`).join('');
      const elastomerOptions=ES_ELASTOMERS.map(value=>`<option value="${esc(value)}" ${value===ES_DEFAULT_ELASTOMER?'selected':''}>${esc(value)}</option>`).join('');
      return `<tr data-es-product-row="${esc(x.id)}"><td><b>${esc(x.model)}</b></td><td><select class="es-product-material" data-es-material-select data-default-value="${esc(ES_DEFAULT_MATERIAL)}" aria-label="Material for ${esc(x.model)}">${options}</select></td><td><select class="es-product-seal" data-es-seal-select data-default-value="${esc(ES_DEFAULT_SEAL)}" aria-label="Mechanical seal material for ${esc(x.model)}">${sealOptions}</select></td><td><select class="es-product-elastomer" data-es-elastomer-select data-default-value="${esc(ES_DEFAULT_ELASTOMER)}" aria-label="Elastomer for ${esc(x.model)}">${elastomerOptions}</select></td><td style="text-align:right"><div class="route-actions"><button class="btn action-assembly" data-es-assembly="${esc(x.id)}">Assembly</button><button class="btn action-quote" data-es-quote="${esc(x.id)}">Quote</button></div></td></tr>`;
    }).join('')||'<tr><td colspan="5" class="muted">No matching ES models.</td></tr>';
    $('esProductCount').textContent=`${rows.length} model${rows.length===1?'':'s'}`;
    const refreshSealApplicability=row=>{const material=row.querySelector('[data-es-material-select]')?.value||'';const seal=row.querySelector('[data-es-seal-select]');const gland=/\bGP\b/i.test(material);if(seal){seal.disabled=gland;seal.title=gland?'Not applicable to Gland Packing construction':'';if(gland){seal.value=ES_DEFAULT_SEAL;updateDefaultState(seal)}}};
    body.querySelectorAll('[data-es-material-select],[data-es-seal-select],[data-es-elastomer-select]').forEach(bindDefaultState);
    body.querySelectorAll('[data-es-product-row]').forEach(row=>{refreshSealApplicability(row);row.querySelector('[data-es-material-select]')?.addEventListener('change',()=>refreshSealApplicability(row))});
    const choicesFor=button=>{const row=button.closest('[data-es-product-row]');return {material:row?.querySelector('[data-es-material-select]')?.value||ES_DEFAULT_MATERIAL,seal:row?.querySelector('[data-es-seal-select]')?.value||ES_DEFAULT_SEAL,elastomer:row?.querySelector('[data-es-elastomer-select]')?.value||ES_DEFAULT_ELASTOMER}};
    body.querySelectorAll('[data-es-assembly]').forEach(b=>b.onclick=()=>{const c=choicesFor(b);window.KeySuitePricing?.addEs?.(b.dataset.esAssembly,'assembly',c.material,{seal:c.seal,elastomer:c.elastomer})});
    body.querySelectorAll('[data-es-quote]').forEach(b=>b.onclick=()=>{const c=choicesFor(b);window.KeySuitePricing?.addEs?.(b.dataset.esQuote,'quotation',c.material,{seal:c.seal,elastomer:c.elastomer})});
  }
  function renderKeyplc(){
    const body=$('keyplcProductRows');if(!body)return;
    const q=String($('keyplcProductSearch')?.value||'').trim().toLowerCase();
    const rows=keyplcProducts().filter(x=>!q||String(x.model||'').toLowerCase().includes(q));
    const pumpOptions=Array.from({length:6},(_,i)=>`<option value="${i+1}" ${i+1===2?'selected':''}>${i+1} ${i===0?'Pump':'Pumps'}</option>`).join('');
    const actions=(product,type)=>`<div class="route-actions keyplc-route-actions"><button class="btn action-assembly" type="button" data-keyplc-assembly="${esc(product.id)}" data-keyplc-type="${type}">Assembly</button><button class="btn action-quote" type="button" data-keyplc-quote="${esc(product.id)}" data-keyplc-type="${type}">Quote</button></div>`;
    body.innerHTML=rows.map(product=>`<tr data-keyplc-product-row="${esc(product.id)}"><td><b>${esc(product.model)}</b></td><td><select data-keyplc-pump-count data-default-value="2" aria-label="Number of pumps for ${esc(product.model)}">${pumpOptions}</select></td><td>${actions(product,'indoor')}</td><td>${actions(product,'sheltered')}<div class="keyplc-surcharge-note">Indoor + RM 1,000.00</div></td></tr>`).join('')||'<tr><td colspan="4" class="muted">No matching KeyPLC panel models.</td></tr>';
    $('keyplcProductCount').textContent=`${rows.length} panel model${rows.length===1?'':'s'}`;
    const qtyFor=button=>Number(button.closest('[data-keyplc-product-row]')?.querySelector('[data-keyplc-pump-count]')?.value||1);
    body.querySelectorAll('[data-keyplc-pump-count]').forEach(bindDefaultState);
    body.querySelectorAll('[data-keyplc-assembly]').forEach(button=>button.addEventListener('click',()=>window.KeySuitePricing?.addKeyplc?.(button.dataset.keyplcAssembly,qtyFor(button),'assembly',button.dataset.keyplcType||'indoor')));
    body.querySelectorAll('[data-keyplc-quote]').forEach(button=>button.addEventListener('click',()=>window.KeySuitePricing?.addKeyplc?.(button.dataset.keyplcQuote,qtyFor(button),'quotation',button.dataset.keyplcType||'indoor')));
  }

  function render(){if($('productModelOptions'))$('productModelOptions').innerHTML=products().map(p=>`<option value="${esc(p.model)}"></option>`).join('');bindStaticDefaults();renderSeries();renderModels();renderEs();renderGws();renderKeyplc()}
  function pageShown(id){if(['productChc','productEs','productGws','productKeyplc'].includes(id))render()}

  window.addEventListener('message',event=>{if(event.source===$('productSelectorFrame')?.contentWindow&&event.data?.type==='KEYSUITE_PRODUCT_FRAME_READY'){frameReady=true;if(queued){const message=queued;queued=null;postToFrame($('productSelectorFrame'),message)}}});
  document.addEventListener('DOMContentLoaded',()=>{
    $('productModelInput')?.addEventListener('input',()=>{const exact=products().find(p=>p.model.toLowerCase()===$('productModelInput').value.trim().toLowerCase());if(exact)selectedSeries=seriesName(exact.model);renderSeries();renderModels()});
    bindStaticDefaults();
    $('closeProductCurve')?.addEventListener('click',()=>$('productCurveDialog')?.close());$('exportProductCurve')?.addEventListener('click',()=>{if(currentCurveModel)send(currentCurveModel,'export')});$('esProductSearch')?.addEventListener('input',renderEs);$('gwsProductSeries')?.addEventListener('change',()=>{if($('gwsProductModel'))$('gwsProductModel').value='ALL';renderGws()});$('gwsProductModel')?.addEventListener('change',renderGws);$('keyplcProductSearch')?.addEventListener('input',renderKeyplc);
  });
  window.KeySuiteProduct={pageShown,render};
})();
