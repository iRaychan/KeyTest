(() => {
  'use strict';

  const $=id=>document.getElementById(id);
  const esc=value=>String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  let selectedSeries='',frameReady=false,queued=null;

  const products=()=>window.KEYSUITE_SECURE_DATA?.products||[];
  const gwsProducts=()=>window.KEYSUITE_SECURE_DATA?.gwsProducts||[];
  const seriesName=model=>{const m=String(model||'').match(/^CHC\s+(\d+)/i);return m?`CHC ${m[1]}`:'Other'};
  const orderedSeries=()=>[...new Set(products().map(p=>seriesName(p.model)))].sort((a,b)=>Number((a.match(/\d+/)||[999])[0])-Number((b.match(/\d+/)||[999])[0]));

  function ensureFrame(){const frame=$('productSelectorFrame');if(frame&&frame.src==='about:blank')frame.src=frame.dataset.src;return frame}
  function options(){return {material:$('productMaterial')?.value||'SS304 (Cast Iron Connection)',seal:$('productSeal')?.value||'Car/Cer',elastomer:$('productElastomer')?.value||'Viton',connection:$('productConnection')?.value||'round',bare:!!$('productBareShaft')?.checked}}
  function send(model,action){const frame=ensureFrame();if(!frame)return;queued={type:'KEYSUITE_PRODUCT_ACTION',model,action,options:options()};if(frameReady)frame.contentWindow.postMessage(queued,'*')}

  function renderSeries(){
    const series=orderedSeries();if(!selectedSeries||!series.includes(selectedSeries))selectedSeries=series[0]||'';
    $('productSeriesList').innerHTML=series.map(name=>`<button type="button" class="product-series-button ${name===selectedSeries?'active':''}" data-product-series="${esc(name)}">${esc(name)}</button>`).join('');
    $('productSeriesList').querySelectorAll('[data-product-series]').forEach(button=>button.onclick=()=>{selectedSeries=button.dataset.productSeries;renderSeries();renderModels()});
  }

  function curveIcon(){return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 18c4-10 8 2 12-8 2-4 4-5 6-5"></path><path d="M3 20h18"></path></svg>'}

  function renderModels(){
    const query=String($('productModelInput')?.value||'').trim().toLowerCase();let rows=products().filter(p=>seriesName(p.model)===selectedSeries);if(query)rows=rows.filter(p=>String(p.model).toLowerCase().includes(query));
    $('productSeriesTitle').textContent=selectedSeries||'Models';$('productModelCount').textContent=`${rows.length} model${rows.length===1?'':'s'}`;
    $('productModelGrid').innerHTML=rows.length?rows.map(p=>`<div class="product-model-row"><h3>${esc(p.model)}</h3><div class="product-model-actions"><button class="btn secondary product-action-button icon-only" type="button" data-product-view="${esc(p.model)}" title="View Curve" aria-label="View Curve">${curveIcon()}</button><button class="btn green product-action-button" type="button" data-product-export="${esc(p.model)}">PDF</button><button class="btn secondary product-action-button" type="button" data-product-system="${esc(p.model)}">System</button><button class="btn secondary product-action-button" type="button" data-product-pumpset="${esc(p.model)}">Pumpset</button><button class="btn product-action-button" type="button" data-product-add="${esc(p.model)}">Quote</button></div></div>`).join(''):'<div class="product-empty">No matching CHC models.</div>';
    const grid=$('productModelGrid');
    grid.querySelectorAll('[data-product-view]').forEach(button=>button.onclick=()=>{const model=button.dataset.productView;$('productCurveTitle').textContent=model;const frame=ensureFrame(),host=$('productCurveHost');if(frame.parentNode!==host)host.appendChild(frame);frame.style.display='block';$('productCurveDialog').showModal();send(model,'view')});
    grid.querySelectorAll('[data-product-export]').forEach(button=>button.onclick=()=>send(button.dataset.productExport,'export'));
    grid.querySelectorAll('[data-product-add]').forEach(button=>button.onclick=()=>{if(!window.KeySuiteApp?.ensureQuotationPricingContext?.('add a product to the quotation'))return;send(button.dataset.productAdd,'add')});
    grid.querySelectorAll('[data-product-system]').forEach(button=>button.onclick=()=>{if(!window.KeySuiteApp?.ensureQuotationPricingContext?.('add a product to the system'))return;send(button.dataset.productSystem,'system')});
    grid.querySelectorAll('[data-product-pumpset]').forEach(button=>button.onclick=()=>{if(!window.KeySuiteApp?.ensureQuotationPricingContext?.('add a product to the pumpset'))return;send(button.dataset.productPumpset,'pumpset')});
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

  function renderGws(){
    const body=$('gwsProductRows');if(!body)return;gwsSeriesOptions();
    const series=$('gwsProductSeries')?.value||'ALL',query=String($('gwsProductSearch')?.value||'').trim().toLowerCase();
    const rows=gwsProducts().filter(product=>(series==='ALL'||gwsSeriesKey(product)===series)&&(!query||[product.seriesName,product.model,product.sizeCode,product.pressureBar].join(' ').toLowerCase().includes(query)));
    body.innerHTML=rows.map(product=>`<tr><td>${esc(product.seriesName)}</td><td><b>${esc(product.model)}</b></td><td>${esc(product.sizeLitres)} Litres</td><td>${esc(product.pressureBar)} Bar</td><td style="text-align:right"><div class="route-actions"><button class="btn secondary" type="button" data-gws-system="${esc(product.id)}">System</button><button class="btn secondary" type="button" data-gws-pumpset="${esc(product.id)}">Pumpset</button><button class="btn" type="button" data-gws-quote="${esc(product.id)}">Quote</button></div></td></tr>`).join('')||'<tr><td colspan="5" class="muted">No matching GWS Tank models.</td></tr>';
    $('gwsProductCount').textContent=`${rows.length} valid tank SKU${rows.length===1?'':'s'}`;
    body.querySelectorAll('[data-gws-quote]').forEach(button=>button.addEventListener('click',()=>window.KeySuitePricing?.addGwsToQuotation?.(button.dataset.gwsQuote,null)));
    ['system','pumpset'].forEach(route=>body.querySelectorAll(`[data-gws-${route}]`).forEach(button=>button.addEventListener('click',()=>{if(!window.KeySuiteApp?.ensureQuotationPricingContext?.(`add a product to the ${route}`))return;const item=window.KeySuitePricing?.buildGwsAssemblyItem?.(button.dataset[`gws${route[0].toUpperCase()+route.slice(1)}`],null);if(item)window.KeySuiteAssembly?.addItem?.(route,item);else alert('No price is available for this GWS Tank SKU.')})));
  }

  function render(){if($('productModelOptions'))$('productModelOptions').innerHTML=products().map(p=>`<option value="${esc(p.model)}"></option>`).join('');renderSeries();renderModels();renderGws()}
  function pageShown(id){if(id==='productChc'||id==='productGws')render()}

  window.addEventListener('message',event=>{if(event.source===$('productSelectorFrame')?.contentWindow&&event.data?.type==='KEYSUITE_PRODUCT_FRAME_READY'){frameReady=true;if(queued)$('productSelectorFrame').contentWindow.postMessage(queued,'*')}});
  document.addEventListener('DOMContentLoaded',()=>{
    $('productModelInput')?.addEventListener('input',()=>{const exact=products().find(p=>p.model.toLowerCase()===$('productModelInput').value.trim().toLowerCase());if(exact)selectedSeries=seriesName(exact.model);renderSeries();renderModels()});
    $('closeProductCurve')?.addEventListener('click',()=>$('productCurveDialog')?.close());$('gwsProductSeries')?.addEventListener('change',renderGws);$('gwsProductSearch')?.addEventListener('input',renderGws);
  });
  window.KeySuiteProduct={pageShown,render};
})();
