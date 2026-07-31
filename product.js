(() => {
  'use strict';

  const $=id=>document.getElementById(id);
  const esc=value=>String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  let selectedSeries='',frameReady=false,queued=null,currentCurveModel='';

  const products=()=>window.KEYSUITE_SECURE_DATA?.products||[];
  const gwsProducts=()=>window.KEYSUITE_SECURE_DATA?.gwsProducts||[];
  const esProducts=()=>window.KEYSUITE_SECURE_DATA?.esProducts||[];
  const seriesName=model=>{const m=String(model||'').match(/^CHC\s+(\d+)/i);return m?`CHC ${m[1]}`:'Other'};
  const orderedSeries=()=>[...new Set(products().map(p=>seriesName(p.model)))].sort((a,b)=>Number((a.match(/\d+/)||[999])[0])-Number((b.match(/\d+/)||[999])[0]));

  function ensureFrame(){const frame=$('productSelectorFrame');if(frame&&frame.src==='about:blank')frame.src=frame.dataset.src;return frame}
  function options(){return {material:$('productMaterial')?.value||'SS304 (Cast Iron Connection)',seal:$('productSeal')?.value||'Car/Cer',elastomer:$('productElastomer')?.value||'Viton',connection:$('productConnection')?.value||'round',bare:!!$('productBareShaft')?.checked,hz:50}}
  function send(model,action){const frame=ensureFrame();if(!frame)return;queued={type:'KEYSUITE_PRODUCT_MODEL',model,action,options:options()};const dispatch=()=>{try{frame.contentWindow.postMessage(queued,'*')}catch(_){}};dispatch();setTimeout(dispatch,350);setTimeout(dispatch,1000)}

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

  function renderGws(){
    const body=$('gwsProductRows');if(!body)return;gwsSeriesOptions();
    const series=$('gwsProductSeries')?.value||'ALL',query=String($('gwsProductSearch')?.value||'').trim().toLowerCase();
    const rows=gwsProducts().filter(product=>(series==='ALL'||gwsSeriesKey(product)===series)&&(!query||[product.seriesName,product.model,product.sizeCode,product.pressureBar].join(' ').toLowerCase().includes(query)));
    body.innerHTML=rows.map(product=>`<tr><td>${esc(product.seriesName)}</td><td><b>${esc(product.model)}</b></td><td>${esc(product.sizeLitres)} Litres</td><td>${esc(product.pressureBar)} Bar</td><td style="text-align:right"><div class="route-actions"><button class="btn secondary" type="button" data-gws-assembly="${esc(product.id)}">Add to Assembly</button><button class="btn" type="button" data-gws-quote="${esc(product.id)}">Quote</button></div></td></tr>`).join('')||'<tr><td colspan="5" class="muted">No matching GWS Tank models.</td></tr>';
    $('gwsProductCount').textContent=`${rows.length} valid tank SKU${rows.length===1?'':'s'}`;
    body.querySelectorAll('[data-gws-quote]').forEach(button=>button.addEventListener('click',()=>window.KeySuitePricing?.addGwsToQuotation?.(button.dataset.gwsQuote,null)));
    body.querySelectorAll('[data-gws-assembly]').forEach(button=>button.addEventListener('click',()=>{if(!window.KeySuiteApp?.ensureQuotationPricingContext?.('add a tank to Assembly'))return;const item=window.KeySuitePricing?.buildGwsAssemblyItem?.(button.dataset.gwsAssembly,null);if(item){item.assemblyLevel='SYSTEM_COMPONENT';item.assemblySection='tank';window.KeySuiteAssembly?.addItem?.(item)}else alert('No price is available for this GWS Tank SKU.')}));
  }


  function renderEs(){
    const body=$('esProductRows');if(!body)return;const q=String($('esProductSearch')?.value||'').trim().toLowerCase();
    const rows=esProducts().filter(x=>!q||x.model.toLowerCase().includes(q));
    body.innerHTML=rows.map(x=>{const v=(x.variants||[]).find(v=>['priceUsd','priceRmb','priceMyr'].some(key=>Number(v[key])>0))||x.variants?.[0]||{};return `<tr><td><b>${esc(x.model)}</b></td><td>${esc(v.material||'Standard')}</td><td style="text-align:right"><div class="route-actions"><button class="btn secondary" data-es-assembly="${esc(x.id)}">Assembly</button><button class="btn" data-es-quote="${esc(x.id)}">Quote</button></div></td></tr>`}).join('')||'<tr><td colspan="3" class="muted">No matching ES models.</td></tr>';
    $('esProductCount').textContent=`${rows.length} model${rows.length===1?'':'s'}`;
    body.querySelectorAll('[data-es-assembly]').forEach(b=>b.onclick=()=>window.KeySuitePricing?.addEs?.(b.dataset.esAssembly,'assembly'));
    body.querySelectorAll('[data-es-quote]').forEach(b=>b.onclick=()=>window.KeySuitePricing?.addEs?.(b.dataset.esQuote,'quotation'));
  }
  function render(){if($('productModelOptions'))$('productModelOptions').innerHTML=products().map(p=>`<option value="${esc(p.model)}"></option>`).join('');renderSeries();renderModels();renderEs();renderGws()}
  function pageShown(id){if(['productChc','productEs','productGws'].includes(id))render()}

  window.addEventListener('message',event=>{if(event.source===$('productSelectorFrame')?.contentWindow&&event.data?.type==='KEYSUITE_PRODUCT_FRAME_READY'){frameReady=true;if(queued)$('productSelectorFrame').contentWindow.postMessage(queued,'*')}});
  document.addEventListener('DOMContentLoaded',()=>{
    $('productModelInput')?.addEventListener('input',()=>{const exact=products().find(p=>p.model.toLowerCase()===$('productModelInput').value.trim().toLowerCase());if(exact)selectedSeries=seriesName(exact.model);renderSeries();renderModels()});
    $('closeProductCurve')?.addEventListener('click',()=>$('productCurveDialog')?.close());$('exportProductCurve')?.addEventListener('click',()=>{if(currentCurveModel)send(currentCurveModel,'export')});$('esProductSearch')?.addEventListener('input',renderEs);$('gwsProductSeries')?.addEventListener('change',renderGws);$('gwsProductSearch')?.addEventListener('input',renderGws);
  });
  window.KeySuiteProduct={pageShown,render};
})();
