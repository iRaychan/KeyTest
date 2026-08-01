(() => {
'use strict';
const $=id=>document.getElementById(id);
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let type='system',drafts=[],current=null,loaded=false,autoSaveTimer=null,saveQueue=Promise.resolve();
const dirtyDraftIds=new Set(),autoSaveRetries=new Map();
const sections={system:['pumpset','control_panel','manifold','tank','misc'],pumpset:['pump','motor','coupling','baseplate']};
const labels={pumpset:'Pumpset',control_panel:'Control Panel',manifold:'Manifold',tank:'Tank',misc:'MISC',pump:'Pump',motor:'Motor',coupling:'Coupling',baseplate:'Baseplate'};
const key=()=>`ks_v201_assembly_${window.KEYSUITE_PROFILE?.company_id||'company'}`;
const uid=()=>crypto.randomUUID?.()||`asm-${Date.now()}-${Math.random().toString(16).slice(2)}`;
const customers=()=>window.KeySuiteApp?.getCustomers?.()||[];
const keyplcProducts=()=>window.KEYSUITE_SECURE_DATA?.keyplcProducts||[];
function quoteCustomerId(){return window.KeySuiteApp?.getPricingCustomerId?.()||''}
function blank(t=type){return {id:uid(),assembly_type:t,model_item:'',description:'',name:t==='system'?'New System':'New Pumpset',customer_id:quoteCustomerId(),status:'draft',quote_qty:1,quote_unit_price:null,quote_price_manual:false,items:[],created_at:new Date().toISOString(),updated_at:new Date().toISOString()}}
function sourceObject(item){const raw=item?.pricingSource;if(!raw)return {};if(typeof raw==='object')return raw;try{return JSON.parse(raw)}catch(_){return {}}}
function quoteMetaFromItems(items=[]){for(const item of items||[]){const meta=sourceObject(item).assembly_quote;if(meta&&typeof meta==='object')return meta}return null}
function quoteMeta(d){return {qty:Math.max(.01,Number(d?.quote_qty||1)),unitPrice:Number.isFinite(Number(d?.quote_unit_price))?Math.max(0,Number(d.quote_unit_price)):null,manual:!!d?.quote_price_manual}}
function defaultSection(t,item){if(t==='pumpset')return item?.section||'pump';return item?.section||'misc'}
function normalizePanelType(value){return /^shelter/i.test(String(value||''))?'sheltered':'indoor'}
function panelTypeLabel(value){return normalizePanelType(value)==='sheltered'?'Sheltered':'Indoor Type'}
function normalizeItem(item={},assemblyType=type){
 const source=sourceObject(item),normalized={...item,pricingSource:source,section:item.section||defaultSection(assemblyType,item)};
 if(!normalized.keyplcData&&String(source.product_family||'').toUpperCase()==='KEYPLC'){
   const product=keyplcProducts().find(x=>String(x.id)===String(source.product_id))||{};
   const pumpQty=Math.max(1,Number(String(source.variant||source.material||'1').replace(/\D/g,''))||1);
   normalized.keyplcData={productId:source.product_id||product.id||'',motorRating:product.model||String(normalized.model||'').match(/KeyPLC\s+([^·]+)/i)?.[1]?.trim()||'',pumpQty,enclosure:normalizePanelType(source.panel_type),indoorUnitPrice:Math.max(0,Number(normalized.unitPrice||0)-Number(source.enclosure_surcharge||0)),shelteredSurcharge:1000,autoSized:!!source.auto_sized_panel};
 }
 if(normalized.keyplcData)normalized.keyplcData={shelteredSurcharge:1000,enclosure:'indoor',...normalized.keyplcData};
 return normalized;
}
function normalize(input){
 const original=input||{},assemblyType=original.assembly_type||type,items=(original.items||[]).map(x=>normalizeItem(x,assemblyType)),meta=quoteMetaFromItems(items),d={...blank(assemblyType),...original,items};
 d.quote_qty=Math.max(.01,Number(original.quote_qty??meta?.qty??1)||1);d.quote_price_manual=original.quote_price_manual==null?!!meta?.manual:!!original.quote_price_manual;
 const storedPrice=original.quote_unit_price??meta?.unitPrice;d.quote_unit_price=storedPrice==null?null:Math.max(0,Number(storedPrice)||0);return d
}
function localLoad(){try{return (JSON.parse(localStorage.getItem(key())||'[]')||[]).map(normalize)}catch(_){return []}}
function localSave(){localStorage.setItem(key(),JSON.stringify(drafts))}
function total(d=current){return (d?.items||[]).reduce((n,x)=>n+Number(x.qty||0)*Number(x.unitPrice||0),0)}
function quoteUnitPrice(d=current){const value=Number(d?.quote_unit_price);return d?.quote_price_manual&&Number.isFinite(value)?Math.max(0,value):total(d)}
function syncQuoteUnitPrice(d=current){if(!d)return;if(!d.quote_price_manual)d.quote_unit_price=total(d)}
function money(n){return `RM ${Number(n||0).toLocaleString('en-MY',{minimumFractionDigits:2,maximumFractionDigits:2})}`}
function tankDescription(item,qty=item?.qty){
 const litres=Number(item?.tankData?.sizeLitres||0),pressure=Number(item?.tankData?.pressureBar||0),quantity=Math.max(0,Number(qty)||0);
 if(!(litres>0)||!(pressure>0))return item?.description||'';
 const clean=value=>Number.isInteger(value)?value.toFixed(0):String(value);
 return `c/w ${clean(litres)} litres (${clean(pressure)} bar) non-jkkp approved tank @ ${clean(quantity)} ${quantity===1?'unit':'units'}`;
}
function replaceDescriptionBlock(source,previous,next){
 const text=String(source||'');if(!previous||previous===next)return text;
 const index=text.indexOf(previous);if(index<0)return text;
 return text.slice(0,index)+next+text.slice(index+previous.length);
}
function removeDescriptionBlock(source,block){
 const text=String(source||''),needle=String(block||'').trim();if(!needle)return text;
 const index=text.indexOf(needle);if(index<0)return text;
 let before=text.slice(0,index),after=text.slice(index+needle.length);
 if(after.startsWith('\n\n'))after=after.slice(2);else if(after.startsWith('\n'))after=after.slice(1);else if(before.endsWith('\n\n'))before=before.slice(0,-2);else if(before.endsWith('\n'))before=before.slice(0,-1);
 return `${before}${after}`.replace(/\n{3,}/g,'\n\n').trim();
}
function keyplcDescription(item){
 const data=item?.keyplcData||{},qty=Math.max(1,Number(data.pumpQty)||1),numberWord=qty===1?'no':'nos';
 return `c/w KeyPLC Control Panel (${panelTypeLabel(data.enclosure)})\nPump Controller & HMI Touch Screen @ 1 Lot\n${data.motorRating||''} VFD @ ${qty} ${numberWord} & Pressure Transmitter @ 1 no\nWiring for pumps & pressure transmitter within pump skid @ 1 Lot`;
}
function pumpMotorKw(item){return Number(item?.pumpData?.motor_kw??item?.pumpData?.motorKw??item?.motor_kw??item?.motorKw??0)}
function pumpItems(d=current){return (d?.items||[]).filter(x=>x.section==='pumpset'||x.section==='pump'||pumpMotorKw(x)>0).filter(x=>!x.keyplcData&&String(sourceObject(x).product_family||'').toUpperCase()!=='KEYPLC')}
function totalPumpQty(d=current){return pumpItems(d).reduce((sum,item)=>sum+Math.max(0,Number(item.qty)||0),0)}
function systemModelPumpQty(d=current){
 const pumps=pumpItems(d);if(!pumps.length)return 0;
 const quantities=pumps.map(item=>Math.max(1,Number(item.qty)||1));
 if(quantities.length===1)return quantities[0];
 return quantities.some(qty=>qty>1)?Math.max(...quantities):quantities.reduce((sum,qty)=>sum+qty,0);
}
function updateModelSuggestions(){
 const list=$('assemblyModelItemOptions');if(!list)return;
 if(type!=='system'){list.innerHTML='';return}
 const count=Math.max(1,systemModelPumpQty(current)||1),suffix=`${count}Pump${count===1?'':'s'} System`;
 list.innerHTML=[`KeyPLC VSD Booster System (${suffix})`,`KeyPLC VSD Transfer System (${suffix})`].map(value=>`<option value="${esc(value)}"></option>`).join('');
 const input=$('assemblyModelItem'),value=String(input?.value||current?.model_item||'');
 if(/^(KeyPLC VSD (?:Booster|Transfer) System) \(\d+Pumps? System\)$/i.test(value)){
   const base=value.match(/^(KeyPLC VSD (?:Booster|Transfer) System)/i)?.[1]||'';
   const next=`${base} (${suffix})`;if(input)input.value=next;if(current)current.model_item=next;
 }
}
function appendCompactDescription(d,description){const existing=String(d.description||'').replace(/\s+$/,'');d.description=existing?`${existing}\n${description}`:description}
function removeAutoPanel(d){
 const panels=(d.items||[]).filter(item=>item.keyplcData?.autoSized||sourceObject(item).auto_sized_panel);
 panels.forEach(panel=>{d.description=removeDescriptionBlock(d.description,panel.description)});
 d.items=(d.items||[]).filter(item=>!panels.includes(item));
}
function nearestKeyplcProduct(requiredKw){return keyplcProducts().filter(p=>Number(p.motorKw||String(p.model||'').replace(/[^0-9.]/g,''))>=requiredKw-1e-9).sort((a,b)=>Number(a.motorKw||0)-Number(b.motorKw||0))[0]||null}
function syncAutomaticControlPanel(d=current){
 if(!d||d.assembly_type!=='system')return;
 const pumps=pumpItems(d),qty=Math.round(totalPumpQty(d)),requiredKw=Math.max(0,...pumps.map(pumpMotorKw));
 if(!pumps.length||qty<1||requiredKw<=0){removeAutoPanel(d);syncQuoteUnitPrice(d);return}
 const product=nearestKeyplcProduct(requiredKw);if(!product)return;
 const priceQty=Math.max(1,Math.min(6,qty));
 let panel=(d.items||[]).find(item=>item.keyplcData?.autoSized||sourceObject(item).auto_sized_panel);
 if(!panel)panel=(d.items||[]).find(item=>item.section==='control_panel'&&(item.keyplcData||String(sourceObject(item).product_family||'').toUpperCase()==='KEYPLC'));
 const previous=panel?.description||'',existingEnclosure=normalizePanelType(panel?.keyplcData?.enclosure||sourceObject(panel).panel_type||'indoor');
 const found=window.KeySuitePricing?.findKeyplcPrice?.(product.id,priceQty,{enclosure:existingEnclosure});
 const indoorPrice=Number(found?.calc?.indoorPrice??Math.max(0,Number(panel?.unitPrice||0)-(existingEnclosure==='sheltered'?1000:0)));
 const surcharge=existingEnclosure==='sheltered'?1000:0;
 const data={productId:product.id,motorRating:product.model,pumpQty:qty,enclosure:existingEnclosure,indoorUnitPrice:indoorPrice,shelteredSurcharge:1000,autoSized:true};
 const model=`KeyPLC ${product.model} · ${qty} ${qty===1?'Pump':'Pumps'} · ${panelTypeLabel(existingEnclosure)}`;
 const pricingSource={...(panel?sourceObject(panel):{}),product_family:'KEYPLC',product_id:product.id,variant:`P${priceQty}`,material:`P${priceQty}`,panel_type:existingEnclosure,enclosure_surcharge:surcharge,calculated_price:Number(found?.calc?.finalPrice??indoorPrice+surcharge),auto_sized_panel:true};
 if(!panel){panel={id:uid(),section:'control_panel',model,bomDescription:model,description:'',qty:1,unitPrice:Number(found?.calc?.finalPrice??indoorPrice+surcharge),pricingSource,pumpData:null,keyplcData:data};d.items.push(panel)}
 else{panel.section='control_panel';panel.model=model;panel.bomDescription=model;panel.qty=1;panel.unitPrice=Number(found?.calc?.finalPrice??indoorPrice+surcharge);panel.pricingSource=pricingSource;panel.keyplcData=data}
 panel.description=keyplcDescription(panel);
 if(previous)d.description=replaceDescriptionBlock(d.description,previous,panel.description);else appendCompactDescription(d,panel.description);
 const duplicates=(d.items||[]).filter(item=>item!==panel&&(item.keyplcData?.autoSized||sourceObject(item).auto_sized_panel));
 duplicates.forEach(item=>{d.description=removeDescriptionBlock(d.description,item.description)});d.items=d.items.filter(item=>!duplicates.includes(item));
 syncQuoteUnitPrice(d);
}
function updateKeyplcItem(item,enclosure){
 if(!item?.keyplcData)return;
 const previous=item.description||'',data=item.keyplcData,qty=Math.max(1,Number(data.pumpQty)||1);data.enclosure=normalizePanelType(enclosure);
 item.model=`KeyPLC ${data.motorRating||''} · ${qty} ${qty===1?'Pump':'Pumps'} · ${panelTypeLabel(data.enclosure)}`;item.bomDescription=item.model;item.description=keyplcDescription(item);
 const priceQty=Math.max(1,Math.min(6,qty)),found=window.KeySuitePricing?.findKeyplcPrice?.(data.productId,priceQty,{enclosure:data.enclosure});
 const indoor=Number(found?.calc?.indoorPrice??data.indoorUnitPrice??item.unitPrice??0),surcharge=data.enclosure==='sheltered'?Number(data.shelteredSurcharge||1000):0;data.indoorUnitPrice=indoor;item.unitPrice=Number(found?.calc?.finalPrice??indoor+surcharge);
 item.pricingSource={...sourceObject(item),product_family:'KEYPLC',product_id:data.productId,variant:`P${priceQty}`,material:`P${priceQty}`,panel_type:data.enclosure,enclosure_surcharge:surcharge,calculated_price:item.unitPrice,...(data.autoSized?{auto_sized_panel:true}:{})};
 current.description=replaceDescriptionBlock(current.description,previous,item.description);syncQuoteUnitPrice(current);if($('assemblyDescription'))$('assemblyDescription').value=current.description||'';
}
async function load(){
 const localById=new Map(localLoad().map(d=>[d.id,d])),client=window.KeySuiteAuth?.getClient?.();
 if(client){
   try{
     const {data,error}=await client.rpc('keysuite_list_assemblies_v201');if(error)throw error;
     drafts=(data||[]).map(remote=>{
       const local=localById.get(remote.id)||{};
       const items=(remote.items||[]).map(item=>{
         const localItem=(local.items||[]).find(x=>x.id===item.id)||{};
         return {...item,bomDescription:localItem.bomDescription,tankData:localItem.tankData,keyplcData:localItem.keyplcData};
       });
       const meta=quoteMetaFromItems(items);
       return normalize({...remote,quote_qty:local.quote_qty??meta?.qty,quote_unit_price:local.quote_unit_price??meta?.unitPrice,quote_price_manual:local.quote_price_manual??meta?.manual,items});
     });
     loaded=true;localSave();return;
   }catch(e){console.warn('Assembly V2.01 Supabase fallback',e)}
 }
 drafts=localLoad();loaded=true;
}
async function persist(d){
 const originalId=d.id,wasCurrent=current?.id===originalId,meta=quoteMeta(d),items=(d.items||[]).map((item,index)=>index===0?{...item,pricingSource:{...sourceObject(item),assembly_quote:meta}}:item),payload=JSON.parse(JSON.stringify({...d,items,updated_at:new Date().toISOString()}));let savedDraft=d;const client=window.KeySuiteAuth?.getClient?.();
 if(client){const {data,error}=await client.rpc('keysuite_save_assembly_v201',{p_assembly:payload});if(error)throw error;const saved=Array.isArray(data)?data[0]:data,latest=drafts.find(x=>x.id===originalId)||d;if(saved)savedDraft=normalize({...saved,...latest,id:saved.id||latest.id,created_at:saved.created_at||latest.created_at,updated_at:saved.updated_at||payload.updated_at,items:latest.items})}
 else d.updated_at=payload.updated_at;
 const i=drafts.findIndex(x=>x.id===originalId);if(i>=0)drafts[i]=savedDraft;else drafts.unshift(savedDraft);if(wasCurrent)current=savedDraft;localSave();return savedDraft
}
function scheduleAutoSave(delay=650){
 if(!current)return;dirtyDraftIds.add(current.id);autoSaveRetries.set(current.id,0);localSave();if($('assemblyNotice'))$('assemblyNotice').textContent='Saving changes automatically…';clearTimeout(autoSaveTimer);const id=current.id;autoSaveTimer=setTimeout(()=>flushAutoSave(id),delay)
}
function flushAutoSave(preferredId){
 clearTimeout(autoSaveTimer);autoSaveTimer=null;const id=preferredId&&dirtyDraftIds.has(preferredId)?preferredId:dirtyDraftIds.values().next().value;if(!id)return;dirtyDraftIds.delete(id);const draft=drafts.find(x=>x.id===id);if(!draft)return;
 saveQueue=saveQueue.then(async()=>{try{await persist(draft);autoSaveRetries.delete(id);if(current?.id===id){renderList();$('assemblyNotice').textContent='Saved automatically.'}}catch(e){const tries=(autoSaveRetries.get(id)||0)+1;autoSaveRetries.set(id,tries);if(tries<=1)dirtyDraftIds.add(id);if(current?.id===id)$('assemblyNotice').textContent=tries<=1?`Auto-save failed. Retrying once… (${e.message||e})`:`Auto-save failed. Your changes remain on this device. (${e.message||e})`}}).finally(()=>{if(dirtyDraftIds.size){clearTimeout(autoSaveTimer);const retrying=[...dirtyDraftIds].some(draftId=>(autoSaveRetries.get(draftId)||0)>0);autoSaveTimer=setTimeout(()=>flushAutoSave(),retrying?2000:300)}})
}
async function remove(){if(!current||!confirm(`Delete ${current.name}?`))return;const client=window.KeySuiteAuth?.getClient?.();if(client){const {error}=await client.rpc('keysuite_delete_assembly_v200',{p_assembly_id:current.id});if(error)throw error}drafts=drafts.filter(x=>x.id!==current.id);localSave();current=drafts.find(x=>x.assembly_type===type)||blank();render()}
function read(){
 if(!current)return;current.model_item=$('assemblyModelItem')?.value.trim()||'';current.description=$('assemblyDescription')?.value||'';current.quote_qty=Math.max(.01,Number($('assemblyQuoteQty')?.value)||1);
 const priceInput=$('assemblyQuoteUnitPrice');if(priceInput){if(priceInput.value===''){current.quote_price_manual=false;current.quote_unit_price=total(current)}else{current.quote_unit_price=Math.max(0,Number(priceInput.value)||0)}}
 current.name=current.model_item||current.name||(`New ${type==='system'?'System':'Pumpset'}`);current.customer_id=quoteCustomerId()||current.customer_id||'';current.status=$('assemblyStatus')?.value||current.status||'draft';
 document.querySelectorAll('[data-assembly-item]').forEach(row=>{const item=current.items.find(x=>x.id===row.dataset.assemblyItem);if(item){const previousDescription=item.description||'';item.qty=Math.max(0,Number(row.querySelector('.assembly-qty').value)||0);item.unitPrice=Math.max(0,Number(row.querySelector('.assembly-price').value)||0);if(item.keyplcData){const currentSurcharge=normalizePanelType(item.keyplcData.enclosure)==='sheltered'?Number(item.keyplcData.shelteredSurcharge||1000):0;item.keyplcData.indoorUnitPrice=Math.max(0,item.unitPrice-currentSurcharge)}if(item.tankData){item.description=tankDescription(item,item.qty);current.description=replaceDescriptionBlock(current.description,previousDescription,item.description)}}});
 syncAutomaticControlPanel(current);syncQuoteUnitPrice(current);if($('assemblyDescription'))$('assemblyDescription').value=current.description||''
}
function renderList(){const list=$('assemblyDraftList');if(!list)return;const rows=drafts.filter(x=>x.assembly_type===type);list.innerHTML=rows.map(d=>`<button type="button" class="${d.id===current?.id?'active':''}" data-draft="${esc(d.id)}"><b>${esc(d.model_item||d.name)}</b><br><small>${esc(d.status)} · ${money(quoteUnitPrice(d))}</small></button>`).join('')||'<div class="muted">No saved drafts.</div>';list.querySelectorAll('[data-draft]').forEach(b=>b.onclick=()=>{current=drafts.find(x=>x.id===b.dataset.draft);render()})}
function itemHtml(x){const panel=x.keyplcData?`<div class="assembly-item-option"><label>Panel Type</label><select class="assembly-keyplc-type"><option value="indoor" ${normalizePanelType(x.keyplcData.enclosure)==='indoor'?'selected':''}>Indoor</option><option value="sheltered" ${normalizePanelType(x.keyplcData.enclosure)==='sheltered'?'selected':''}>Sheltered (+ RM 1,000.00)</option></select></div>`:'';return `<div class="assembly-item" data-assembly-item="${esc(x.id)}"><div><b>${esc(x.bomDescription||x.model)}</b>${panel}</div><div><label>Qty</label><input class="assembly-qty" type="number" min="0" step="1" value="${Number(x.qty||1)}"></div><div><label>Unit Price</label><input class="assembly-price" type="number" min="0" step="0.01" value="${Number(x.unitPrice||0).toFixed(2)}"></div><div><label>Total Price</label><div class="assembly-line-total">${money(Number(x.qty||0)*Number(x.unitPrice||0))}</div></div><button class="btn danger assembly-delete" type="button">Delete</button></div>`}
function renderItems(){
 const box=$('assemblyItems');if(!box)return;box.innerHTML=sections[type].map(section=>{const rows=(current?.items||[]).filter(x=>x.section===section);return `<section class="assembly-section"><div class="assembly-section-head"><h2>${labels[section]}</h2><span>${rows.length} item${rows.length===1?'':'s'}</span></div><div class="assembly-section-body">${rows.map(itemHtml).join('')||'<p class="muted assembly-empty">Empty</p>'}</div></section>`}).join('');
 box.querySelectorAll('input').forEach(i=>i.oninput=()=>{read();renderItems();renderQuoteFields();scheduleAutoSave()});
 box.querySelectorAll('.assembly-keyplc-type').forEach(select=>select.onchange=()=>{read();const row=select.closest('[data-assembly-item]'),item=current.items.find(x=>x.id===row?.dataset.assemblyItem);updateKeyplcItem(item,select.value);localSave();renderItems();renderQuoteFields();scheduleAutoSave(100)});
 box.querySelectorAll('.assembly-delete').forEach(b=>b.onclick=()=>{read();const row=b.closest('[data-assembly-item]'),item=current.items.find(x=>x.id===row?.dataset.assemblyItem);if(item)current.description=removeDescriptionBlock(current.description,item.description);current.items=current.items.filter(x=>x.id!==row.dataset.assemblyItem);syncAutomaticControlPanel(current);syncQuoteUnitPrice(current);if($('assemblyDescription'))$('assemblyDescription').value=current.description||'';localSave();renderItems();renderQuoteFields();scheduleAutoSave(100)});
 $('assemblyTotal').textContent=money(total())
}
function renderQuoteFields(){
 updateModelSuggestions();if($('assemblyModelItem'))$('assemblyModelItem').value=current.model_item||'';if($('assemblyQuoteQty'))$('assemblyQuoteQty').value=Number(current.quote_qty||1);if($('assemblyQuoteUnitPrice'))$('assemblyQuoteUnitPrice').value=Number(quoteUnitPrice(current)).toFixed(2)
}
function render(){
 if(!current||current.assembly_type!==type)current=drafts.find(x=>x.assembly_type===type)||blank(type);current=normalize(current);const qCustomer=quoteCustomerId();if(qCustomer)current.customer_id=qCustomer;syncAutomaticControlPanel(current);syncQuoteUnitPrice(current);
 $('assemblyBuilderTitle').textContent=type==='system'?'System':'Pumpset';$('assemblyDescription').value=current.description||'';$('assemblyDescriptionLabel').textContent=type==='system'?'System Description':'Pumpset Description';$('assemblyCustomer').innerHTML='<option value="">No quotation customer selected</option>'+customers().map(c=>`<option value="${esc(c.id)}">${esc(c.company)}</option>`).join('');$('assemblyCustomer').value=current.customer_id||'';$('assemblyCustomer').disabled=true;if($('assemblyStatus'))$('assemblyStatus').value=current.status||'draft';$('assemblyNotice').textContent=qCustomer?'Customer is locked to the active Quotation selection. The KeyPLC panel is sized automatically from the pump quantity and highest motor kW.':'Select a customer in Dashboard or Quotation first. Assembly customer cannot be entered manually.';renderQuoteFields();renderList();renderItems()
}
async function open(t){type=t;window.KeySuiteApp?.showPage?.('assemblyBuilder');if(!loaded)await load();if(!current||current.assembly_type!==type)current=drafts.find(x=>x.assembly_type===type&&x.status==='draft')||drafts.find(x=>x.assembly_type===type)||blank(type);render()}
function routeItem(item={}){const level=String(item.assemblyLevel||item.assembly_level||'').toUpperCase();const section=String(item.assemblySection||item.assembly_section||'').toLowerCase();if(level==='COMPLETE_PUMPSET'||section==='pumpset')return {type:'system',section:'pumpset'};if(['pump','motor','coupling','baseplate'].includes(section))return {type:'pumpset',section};if(['control_panel','manifold','tank','misc'].includes(section))return {type:'system',section};const model=String(item.model||'');if(/^CHC\b/i.test(model))return {type:'system',section:'pumpset'};if(/^ES\b/i.test(model))return {type:'pumpset',section:'pump'};if(/tank|gws/i.test(model+' '+(item.description||'')))return {type:'system',section:'tank'};return {type:'system',section:'misc'}}
async function addItem(item,explicitRoute){
 const route=explicitRoute||routeItem(item),customerId=quoteCustomerId();if(!customerId){alert('Select the customer in Dashboard or Quotation first. Assembly follows the Quotation customer and cannot be filled manually.');window.KeySuiteApp?.showPage?.('dashboard');return}if(!loaded)await load();type=route.type;const target=drafts.find(x=>x.assembly_type===type&&x.status==='draft'&&x.customer_id===customerId)||blank(type);if(!drafts.some(x=>x.id===target.id))drafts.unshift(target);target.customer_id=customerId;
 const rawDescription=item.keyplcData?keyplcDescription(item):String(item.description||'').trim(),description=String(rawDescription||'').trimEnd();if(description){const existing=String(target.description||'').replace(/\s+$/,'');const compact=route.section==='tank'||route.section==='control_panel';target.description=existing?`${existing}${compact?'\n':'\n\n'}${description}`:description}if(type==='pumpset'&&route.section==='pump'&&!target.model_item)target.model_item=item.model||'';
 target.items.push(normalizeItem({id:uid(),section:route.section,model:item.model||'Product',bomDescription:item.bomDescription||item.model||'Product',description,qty:Number(item.qty||1),unitPrice:Number(item.unitPrice||0),pricingSource:item.pricingSource||null,pumpData:item.pumpData||null,tankData:item.tankData||null,keyplcData:item.keyplcData||null},type));
 current=target;syncAutomaticControlPanel(current);syncQuoteUnitPrice(current);localSave();await open(type);scheduleAutoSave(100);$('assemblyNotice').textContent=`${item.model||'Product'} routed to ${type==='system'?'System':'Pumpset'} → ${labels[route.section]}. Saving automatically…`;
}
async function toQuotation(){
 read();if(!current?.items?.length){alert('Add at least one component first.');return}if(!current.customer_id){alert('Select a customer for this assembly.');return}window.KeySuiteApp?.selectCustomerForQuotation?.(current.customer_id);window.KeySuiteApp?.showPage?.('quotation');const componentText=sections[type].map(s=>{const xs=current.items.filter(x=>x.section===s);return xs.length?`${labels[s]}:\n${xs.map(x=>`• ${x.model} × ${x.qty}`).join('\n')}`:''}).filter(Boolean).join('\n\n');const description=[current.description,componentText].filter(Boolean).join('\n\n');const row=window.KeySuiteApp?.addExternalQuoteItem?.({model:current.model_item||current.name||'',qty:Number(current.quote_qty||1),unitPrice:quoteUnitPrice(current),description});if(!row){alert('Unable to add the assembly to Quotation.');return}current.status='quoted';dirtyDraftIds.delete(current.id);try{await persist(current)}catch(e){alert(`Assembly quotation was created, but the assembly status could not be saved: ${e.message||e}`)}
}
function pageShown(id){if(id==='assemblyBuilder'&&loaded)render()}
document.addEventListener('DOMContentLoaded',()=>{
 document.querySelectorAll('[data-assembly-open]').forEach(b=>b.onclick=()=>open(b.dataset.assemblyOpen));$('newAssemblyDraft')?.addEventListener('click',()=>{current=blank(type);render()});$('deleteAssemblyDraft')?.addEventListener('click',()=>remove().catch(e=>alert(e.message||e)));$('assemblyToQuotation')?.addEventListener('click',()=>toQuotation());
 $('assemblyModelItem')?.addEventListener('input',()=>{current.model_item=$('assemblyModelItem').value.trim();current.name=current.model_item||current.name;scheduleAutoSave()});
 $('assemblyQuoteQty')?.addEventListener('input',()=>{current.quote_qty=Math.max(.01,Number($('assemblyQuoteQty').value)||1);scheduleAutoSave()});
 $('assemblyQuoteUnitPrice')?.addEventListener('input',()=>{const value=$('assemblyQuoteUnitPrice').value;if(value===''){current.quote_price_manual=false;syncQuoteUnitPrice(current);$('assemblyQuoteUnitPrice').value=Number(quoteUnitPrice(current)).toFixed(2)}else{current.quote_price_manual=true;current.quote_unit_price=Math.max(0,Number(value)||0)}scheduleAutoSave()});
 const main=$('assemblyDescription'),dlg=$('assemblyDescriptionDialog'),popup=$('assemblyDescriptionPopup');main?.addEventListener('input',()=>{read();scheduleAutoSave()});main?.addEventListener('dblclick',()=>{popup.value=main.value;dlg.showModal()});$('saveAssemblyDescriptionPopup')?.addEventListener('click',()=>{main.value=popup.value;read();scheduleAutoSave(100)})
});
window.KeySuiteAssembly={open,addItem,routeItem,pageShown,refreshAutomaticPanel:()=>{if(current){syncAutomaticControlPanel(current);render();scheduleAutoSave(100)}}};
})();
