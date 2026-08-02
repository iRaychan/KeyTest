(() => {
'use strict';
const $=id=>document.getElementById(id);
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let type='system',drafts=[],current=null,loaded=false,autoSaveTimer=null,saveQueue=Promise.resolve(),currentPinned=false;
const dirtyDraftIds=new Set(),autoSaveRetries=new Map();
const sections={system:['pumpset','control_panel','manifold','tank'],pumpset:['pump','motor','coupling','baseplate']};
const labels={pumpset:'Pumpset',control_panel:'Control Panel',manifold:'Manifold',tank:'Tank',pump:'Pump',motor:'Motor',coupling:'Coupling',baseplate:'Baseplate'};
const key=()=>`ks_v201_assembly_${window.KEYSUITE_PROFILE?.company_id||'company'}`;
const uid=()=>crypto.randomUUID?.()||`asm-${Date.now()}-${Math.random().toString(16).slice(2)}`;
const customers=()=>window.KeySuiteApp?.getCustomers?.()||[];
const keyplcProducts=()=>window.KEYSUITE_SECURE_DATA?.keyplcProducts||[];
function quoteCustomerId(){return window.KeySuiteApp?.getPricingCustomerId?.()||''}
function quoteSessionId(){return window.KeySuiteApp?.getQuotationSessionId?.()||'quotation-session'}
function blank(t=type){return {id:uid(),assembly_type:t,model_item:'',description:'',description_manual:false,name:t==='system'?'New System':'New Pumpset',customer_id:quoteCustomerId(),quote_session_id:quoteSessionId(),status:'draft',quote_qty:1,quote_unit_price:null,quote_price_manual:false,auto_suppressed:{manifold:false,tank:false},items:[],created_at:new Date().toISOString(),updated_at:new Date().toISOString()}}
function sourceObject(item){const raw=item?.pricingSource;if(!raw)return {};if(typeof raw==='object')return raw;try{return JSON.parse(raw)}catch(_){return {}}}
function quoteMetaFromItems(items=[]){for(const item of items||[]){const meta=sourceObject(item).assembly_quote;if(meta&&typeof meta==='object')return meta}return null}
function quoteMeta(d){return {qty:Math.max(.01,Number(d?.quote_qty||1)),unitPrice:Number.isFinite(Number(d?.quote_unit_price))?Math.max(0,Number(d.quote_unit_price)):null,manual:!!d?.quote_price_manual,descriptionManual:!!d?.description_manual,autoSuppressed:{manifold:!!d?.auto_suppressed?.manifold,tank:!!d?.auto_suppressed?.tank}}}
function defaultSection(t,item){if(t==='pumpset')return item?.section||'pump';return item?.section||'unsupported'}
function normalizePanelType(value){return /^shelter/i.test(String(value||''))?'sheltered':'indoor'}
function panelTypeLabel(value){return normalizePanelType(value)==='sheltered'?'Sheltered':'Indoor Type'}
function normalizeDescriptionIndentation(value){
 const lines=String(value||'').replace(/\r\n?/g,'\n').split('\n');
 return lines.map(line=>{
   if(/^c\/w(?:\t+| +)/i.test(line))return `c/w\t${line.replace(/^c\/w(?:\t+| +)/i,'')}`;
   if(/^(?:\t+| {4,})/.test(line))return `\t\t${line.replace(/^(?:\t+| +)/,'')}`;
   return line;
 }).join('\n');
}
function normalizeItem(item={},assemblyType=type){
 const source=sourceObject(item),normalized={...item,description:normalizeDescriptionIndentation(item.description),pricingSource:source,section:item.section||defaultSection(assemblyType,item)};
 if(!normalized.keyplcData&&String(source.product_family||'').toUpperCase()==='KEYPLC'){
   const product=keyplcProducts().find(x=>String(x.id)===String(source.product_id))||{};
   const pumpQty=Math.max(1,Number(String(source.variant||source.material||'1').replace(/\D/g,''))||1);
   normalized.keyplcData={productId:source.product_id||product.id||'',motorRating:product.model||String(normalized.model||'').match(/KeyPLC\s+([^·]+)/i)?.[1]?.trim()||'',pumpQty,enclosure:normalizePanelType(source.panel_type),indoorUnitPrice:Math.max(0,Number(normalized.unitPrice||0)-Number(source.enclosure_surcharge||0)),shelteredSurcharge:1000,autoSized:!!source.auto_sized_panel};
 }
 if(normalized.keyplcData)normalized.keyplcData={shelteredSurcharge:1000,enclosure:'indoor',...normalized.keyplcData};
 return normalized;
}
function normalize(input){
 const original=input||{},assemblyType=original.assembly_type||type;
 const allowed=sections[assemblyType]||[],items=(original.items||[]).map(x=>normalizeItem(x,assemblyType)).filter(item=>allowed.includes(item.section));
 const meta=quoteMetaFromItems(items),d={...blank(assemblyType),...original,items,description_manual:original.description_manual==null?!!meta?.descriptionManual:!!original.description_manual,auto_suppressed:{manifold:false,tank:false,...(meta?.autoSuppressed||{}),...(original.auto_suppressed||{})}};
 d.quote_qty=Math.max(.01,Number(original.quote_qty??meta?.qty??1)||1);d.quote_price_manual=original.quote_price_manual==null?!!meta?.manual:!!original.quote_price_manual;
 const storedPrice=original.quote_unit_price??meta?.unitPrice;d.quote_unit_price=storedPrice==null?null:Math.max(0,Number(storedPrice)||0);d.quote_session_id=original.quote_session_id||`legacy:${d.id}`;return d
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
 return `c/w\t${clean(litres)} litres (${clean(pressure)} bar) non-jkkp approved tank @ ${clean(quantity)} ${quantity===1?'unit':'units'}`;
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
 const data=item?.keyplcData||{},qty=Math.max(1,Number(data.pumpQty)||1),numberWord=qty===1?'no':'nos',indent='\t\t';
 return `c/w\tKeyPLC Control Panel (${panelTypeLabel(data.enclosure)})
${indent}Pump Controller & HMI Touch Screen @ 1 Lot
${indent}${data.motorRating||''} VFD @ ${qty} ${numberWord} & Pressure Transmitter @ 1 no
${indent}Wiring for pumps & pressure transmitter within pump skid @ 1 Lot`;
}
function orderedItems(d=current){
 const order=sections[d?.assembly_type||type]||[];return order.flatMap(section=>(d?.items||[]).filter(item=>item.section===section));
}
function rebuildDescription(d=current){
 if(!d)return '';
 (d.items||[]).forEach(item=>{item.description=normalizeDescriptionIndentation(item.description)});
 d.description=orderedItems(d).map(item=>String(item.description||'').trimEnd()).filter(Boolean).join('\n');
 d.description=normalizeDescriptionIndentation(d.description);
 return d.description;
}
function highlightDescription(text){
 let html=esc(String(text||''));
 const patterns=[
  /(Model:\s*)([^\n]+)/gi,/(\b\d+(?:\.\d+)?\s*(?:HP|kW|Pole|Hz|V|Ph|bar|litres?|Lot|nos?|units?|Pumps?|Sets?)\b)/gi,
  /(DN\s*\d+(?:\s*x\s*DN\s*\d+)?)/gi,/(\d+(?:\.\d+)?&quot;\s+(?:inlet|outlet)(?:\s*&amp;\s*\d+(?:\.\d+)?&quot;\s+(?:inlet|outlet))?)/gi,
  /(Indoor Type|Sheltered|SS304 \(Cast Iron Connection\)|SS316|Mech Seal|Gland Packing|Viton|EPDM|NBR|Carbon Ceramic \(Ca Ce\)|Silicon Carbide \(Sic Sic\)|Tungsten \(Tuc Tuc\))/gi
 ];
 patterns.forEach((pattern,index)=>{html=html.replace(pattern,(match,prefix,value)=>index===0?`${prefix}<mark>${value}</mark>`:`<mark>${match}</mark>`)});
 return html.replace(/\n/g,'<br>');
}
function renderDescriptionPreview(){const preview=$('assemblyDescriptionPreview'),input=$('assemblyDescription'),text=normalizeDescriptionIndentation(input?.value||current?.description||'');if(input&&input.value!==text)input.value=text;if(current)current.description=text;if(preview)preview.innerHTML=highlightDescription(text)}
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
 const previous=panel?.description||'',existingEnclosure=normalizePanelType(panel?.keyplcData?.enclosure||sourceObject(panel).panel_type||'indoor');
 const found=window.KeySuitePricing?.findKeyplcPrice?.(product.id,priceQty,{enclosure:existingEnclosure,pricingMode:'assembly'});
 const indoorPrice=Number(found?.calc?.indoorPrice??Math.max(0,Number(panel?.unitPrice||0)-(existingEnclosure==='sheltered'?1000:0)));
 const surcharge=existingEnclosure==='sheltered'?1000:0;
 const data={productId:product.id,motorRating:product.model,pumpQty:qty,enclosure:existingEnclosure,indoorUnitPrice:indoorPrice,shelteredSurcharge:1000,autoSized:true};
 const model=`KeyPLC ${product.model} · ${qty} ${qty===1?'Pump':'Pumps'} · ${panelTypeLabel(existingEnclosure)}`;
 const pricingSource={...(panel?sourceObject(panel):{}),...(found?window.KeySuitePricing?.sourceSnapshot?.(found)||{}:{}),product_family:'KEYPLC',product_id:product.id,variant:`P${priceQty}`,material:`P${priceQty}`,pricing_mode:'assembly',panel_type:existingEnclosure,enclosure_surcharge:surcharge,calculated_price:Number(found?.calc?.finalPrice??indoorPrice+surcharge),auto_sized_panel:true};
 if(!panel){panel={id:uid(),section:'control_panel',model,bomDescription:model,description:'',qty:1,unitPrice:Number(found?.calc?.finalPrice??indoorPrice+surcharge),pricingSource,pumpData:null,keyplcData:data};d.items.push(panel)}
 else{panel.section='control_panel';panel.model=model;panel.bomDescription=model;panel.qty=1;panel.unitPrice=Number(found?.calc?.finalPrice??indoorPrice+surcharge);panel.pricingSource=pricingSource;panel.keyplcData=data}
 panel.description=keyplcDescription(panel);
 if(previous)d.description=replaceDescriptionBlock(d.description,previous,panel.description);else appendCompactDescription(d,panel.description);
 const duplicates=(d.items||[]).filter(item=>item!==panel&&(item.keyplcData?.autoSized||sourceObject(item).auto_sized_panel));
 duplicates.forEach(item=>{d.description=removeDescriptionBlock(d.description,item.description)});d.items=d.items.filter(item=>!duplicates.includes(item));
 syncQuoteUnitPrice(d);
}
function pumpSeriesNumber(item){
 const p=item?.pumpData||{},text=String(p.series||p.quotation_model||p.model||item?.model||'');return Number((text.match(/CHC\s+(\d+)/i)||[])[1]||0)
}
function pumpConnectionDn(item){
 const p=item?.pumpData||{},text=[p.connection,p.suction_dn,p.discharge_dn,p.suctionDischarge,item?.description,item?.model].filter(Boolean).join(' '),values=[...text.matchAll(/DN\s*(\d+)/gi)].map(match=>Number(match[1])||0).filter(Boolean);return values.length?Math.max(...values):0
}
function pumpShutoffHead(item){
 const p=item?.pumpData||{},direct=Number(p.shutoff_head_m??p.zero_flow_head_m??p.shutoffHead??p.zeroFlowHead);if(Number.isFinite(direct)&&direct>0)return direct;
 const model=p.export_state?.models?.[0]||p.exportState?.models?.[0]||{},fit=model.headFit||model.head_fit||p.headFit||p.head_fit||{};
 if(Array.isArray(fit.c)&&fit.c.length&&Number.isFinite(Number(fit.c[0]))&&Number(fit.c[0])>0)return Number(fit.c[0]);
 const points=Array.isArray(fit.pts)?fit.pts:[];if(points.length){const first=[...points].sort((a,b)=>Number(a.x||0)-Number(b.x||0))[0],head=Number(first?.y);if(Number.isFinite(head)&&head>0)return head}
 return null
}
function systemShutoffHead(d=current){const heads=pumpItems(d).map(pumpShutoffHead).filter(value=>Number.isFinite(value)&&value>0);return heads.length?Math.max(...heads):null}
function autoComponent(item,kind){const source=sourceObject(item);return kind==='manifold'?!!(item?.manifoldData?.autoSelected||source.auto_sized_manifold):kind==='tank'?!!(item?.tankData?.autoSelected||source.auto_sized_tank):false}
function removeAutoComponent(d,kind){const items=(d.items||[]).filter(item=>autoComponent(item,kind));items.forEach(item=>{d.description=removeDescriptionBlock(d.description,item.description)});d.items=(d.items||[]).filter(item=>!items.includes(item))}
function placeAutomaticDescription(d,previous,next){if(previous&&String(d.description||'').includes(previous))d.description=replaceDescriptionBlock(d.description,previous,next);else if(next&&!String(d.description||'').includes(next))appendCompactDescription(d,next)}
function syncAutomaticManifold(d=current){
 if(!d||d.assembly_type!=='system')return;if(d.auto_suppressed?.manifold){removeAutoComponent(d,'manifold');return}const pumps=pumpItems(d),qty=Math.round(totalPumpQty(d)),dn=Math.max(0,...pumps.map(pumpConnectionDn));
 if(!pumps.length||qty<1||dn<=0||!window.KeySuiteManifold?.buildConfiguredItem){removeAutoComponent(d,'manifold');return}
 const shutoffHead=systemShutoffHead(d),connectionChoice=window.KeySuiteManifold.connectionForShutoffHead?.(shutoffHead)||{connection:'FLANGE_16',fallback:true};
 if(!connectionChoice.connection){removeAutoComponent(d,'manifold');return}
 const config={material:'GI',connection:connectionChoice.connection,suctionDn:`DN${dn}`,dischargeDn:`DN${dn}`,pumpQty:Math.max(1,Math.min(6,qty)),tankSize:'',rarity:'common'};
 const built=window.KeySuiteManifold.buildConfiguredItem(config,{includeCw:true,auto:true,pricingMode:'assembly'});if(!built){removeAutoComponent(d,'manifold');return}
 let item=(d.items||[]).find(x=>autoComponent(x,'manifold')),previous=item?.description||'';
 const manifoldData={...(built.manifoldData||{}),autoSelected:true,shutoffHeadM:shutoffHead,shutoffPressureBar:connectionChoice.pressureBar,fallbackConnection:!!connectionChoice.fallback};
 if(!item){item={id:uid(),section:'manifold'};d.items.push(item)}
 Object.assign(item,normalizeItem({...item,...built,section:'manifold',qty:1,manifoldData,pricingSource:{...sourceObject(built),auto_sized_manifold:true}},'system'));
 placeAutomaticDescription(d,previous,item.description);const duplicates=(d.items||[]).filter(x=>x!==item&&autoComponent(x,'manifold'));duplicates.forEach(x=>{d.description=removeDescriptionBlock(d.description,x.description)});d.items=d.items.filter(x=>!duplicates.includes(x))
}
function tankLitresForSeries(series){const value=Number(series)||0;if(value>0&&value<=10)return 24;if(value>=12&&value<=16)return 35;if(value>=35&&value<=90)return 100;if(value>=120&&value<=150)return 200;if(value===200)return 300;return 0}
function syncAutomaticTank(d=current){
 if(!d||d.assembly_type!=='system')return;if(d.auto_suppressed?.tank){removeAutoComponent(d,'tank');return}const pumps=pumpItems(d),litres=Math.max(0,...pumps.map(item=>tankLitresForSeries(pumpSeriesNumber(item)))),head=systemShutoffHead(d),pressureBar=Number.isFinite(Number(head))?Number(head)*.0981:null;
 if(!pumps.length||!litres||!Number.isFinite(pressureBar)||!window.KeySuitePricing?.findAutoGwsTank){removeAutoComponent(d,'tank');return}
 const found=window.KeySuitePricing.findAutoGwsTank(litres,pressureBar,{pricingMode:'assembly'});if(!found){removeAutoComponent(d,'tank');return}
 const built=window.KeySuitePricing.buildGwsAssemblyItem?.(found.product.id,null,{pricingMode:'assembly'});if(!built){removeAutoComponent(d,'tank');return}
 let item=(d.items||[]).find(x=>autoComponent(x,'tank')),previous=item?.description||'';const tankData={...(built.tankData||{}),autoSelected:true,chcSeries:pumps.map(pumpSeriesNumber).filter(Boolean),shutoffHeadM:head,shutoffPressureBar:pressureBar};
 if(!item){item={id:uid(),section:'tank'};d.items.push(item)}
 Object.assign(item,normalizeItem({...item,...built,section:'tank',qty:1,bomDescription:built.model,tankData,pricingSource:{...sourceObject(built),auto_sized_tank:true}},'system'));item.description=tankDescription(item,1);
 placeAutomaticDescription(d,previous,item.description);const duplicates=(d.items||[]).filter(x=>x!==item&&autoComponent(x,'tank'));duplicates.forEach(x=>{d.description=removeDescriptionBlock(d.description,x.description)});d.items=d.items.filter(x=>!duplicates.includes(x))
}
function bomDescriptionState(d=current){return JSON.stringify((d?.items||[]).map(item=>[item.id,item.section,item.model,Number(item.qty||0),normalizeDescriptionIndentation(item.description)]))}
function syncAutomaticComponents(d=current){const before=bomDescriptionState(d);syncAutomaticControlPanel(d);syncAutomaticManifold(d);syncAutomaticTank(d);syncQuoteUnitPrice(d);const changed=before!==bomDescriptionState(d);if(changed&&d)d.description_manual=false;return changed}
function updateKeyplcItem(item,enclosure){
 if(!item?.keyplcData)return;
 const previous=item.description||'',data=item.keyplcData,qty=Math.max(1,Number(data.pumpQty)||1);data.enclosure=normalizePanelType(enclosure);
 item.model=`KeyPLC ${data.motorRating||''} · ${qty} ${qty===1?'Pump':'Pumps'} · ${panelTypeLabel(data.enclosure)}`;item.bomDescription=item.model;item.description=keyplcDescription(item);
 const priceQty=Math.max(1,Math.min(6,qty)),found=window.KeySuitePricing?.findKeyplcPrice?.(data.productId,priceQty,{enclosure:data.enclosure,pricingMode:'assembly'});
 const indoor=Number(found?.calc?.indoorPrice??data.indoorUnitPrice??item.unitPrice??0),surcharge=data.enclosure==='sheltered'?Number(data.shelteredSurcharge||1000):0;data.indoorUnitPrice=indoor;item.unitPrice=Number(found?.calc?.finalPrice??indoor+surcharge);
 item.pricingSource={...sourceObject(item),...(found?window.KeySuitePricing?.sourceSnapshot?.(found)||{}:{}),product_family:'KEYPLC',product_id:data.productId,variant:`P${priceQty}`,material:`P${priceQty}`,pricing_mode:'assembly',panel_type:data.enclosure,enclosure_surcharge:surcharge,calculated_price:item.unitPrice,...(data.autoSized?{auto_sized_panel:true}:{})};
 current.description=replaceDescriptionBlock(current.description,previous,item.description);syncQuoteUnitPrice(current);if($('assemblyDescription'))$('assemblyDescription').value=current.description||'';
}
async function load(){
 const localById=new Map(localLoad().map(d=>[d.id,d])),client=window.KeySuiteAuth?.getClient?.();
 if(client){
   try{
     let {data,error}=await client.rpc('keysuite_list_assemblies_v218');if(error){const fallback=await client.rpc('keysuite_list_assemblies_v201');data=fallback.data;error=fallback.error}if(error)throw error;
     drafts=(data||[]).map(remote=>{
       const local=localById.get(remote.id)||{};
       const items=(remote.items||[]).map(item=>{
         const localItem=(local.items||[]).find(x=>x.id===item.id)||{};
         return {...item,bomDescription:localItem.bomDescription??item.bomDescription,tankData:localItem.tankData??item.tankData,keyplcData:localItem.keyplcData??item.keyplcData,manifoldData:localItem.manifoldData??item.manifoldData};
       });
       const meta=quoteMetaFromItems(items);
       return normalize({...remote,quote_session_id:local.quote_session_id||remote.quote_session_id||`legacy:${remote.id}`,quote_qty:local.quote_qty??meta?.qty,quote_unit_price:local.quote_unit_price??meta?.unitPrice,quote_price_manual:local.quote_price_manual??meta?.manual,auto_suppressed:local.auto_suppressed||remote.auto_suppressed,items});
     });
     loaded=true;refreshPricing();localSave();return;
   }catch(e){console.warn('Assembly V2.01 Supabase fallback',e)}
 }
 drafts=localLoad();loaded=true;refreshPricing();
}
async function persist(d){
 const originalId=d.id,wasCurrent=current?.id===originalId,meta=quoteMeta(d),items=(d.items||[]).map((item,index)=>index===0?{...item,pricingSource:{...sourceObject(item),assembly_quote:meta}}:item),payload=JSON.parse(JSON.stringify({...d,items,updated_at:new Date().toISOString()}));let savedDraft=d;const client=window.KeySuiteAuth?.getClient?.();
 if(client){let {data,error}=await client.rpc('keysuite_save_assembly_v218',{p_assembly:payload});if(error){const fallback=await client.rpc('keysuite_save_assembly_v201',{p_assembly:payload});data=fallback.data;error=fallback.error}if(error)throw error;const saved=Array.isArray(data)?data[0]:data,latest=drafts.find(x=>x.id===originalId)||d;if(saved)savedDraft=normalize({...saved,...latest,id:saved.id||latest.id,created_at:saved.created_at||latest.created_at,updated_at:saved.updated_at||payload.updated_at,items:latest.items})}
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
async function remove(){if(!current||!confirm(`Delete ${current.name}?`))return;const client=window.KeySuiteAuth?.getClient?.();if(client){const {error}=await client.rpc('keysuite_delete_assembly_v200',{p_assembly_id:current.id});if(error)throw error}drafts=drafts.filter(x=>x.id!==current.id);localSave();current=currentSessionDrafts(type)[0]||blank(type);render()}
function read(){
 if(!current)return;current.model_item=$('assemblyModelItem')?.value.trim()||'';current.description=$('assemblyDescription')?.value||'';current.quote_qty=Math.max(.01,Number($('assemblyQuoteQty')?.value)||1);
 const priceInput=$('assemblyQuoteUnitPrice');if(priceInput){if(priceInput.value===''){current.quote_price_manual=false;current.quote_unit_price=total(current)}else{current.quote_unit_price=Math.max(0,Number(priceInput.value)||0)}}
 current.name=current.model_item||current.name||(`New ${type==='system'?'System':'Pumpset'}`);current.customer_id=quoteCustomerId()||current.customer_id||'';current.status=$('assemblyStatus')?.value||current.status||'draft';
 document.querySelectorAll('[data-assembly-item]').forEach(row=>{const item=current.items.find(x=>x.id===row.dataset.assemblyItem);if(item){const previousDescription=item.description||'',autoPanel=!!(item.keyplcData?.autoSized||sourceObject(item).auto_sized_panel),autoLocked=autoPanel||autoComponent(item,'manifold')||autoComponent(item,'tank');if(!autoLocked){item.qty=Math.max(0,Number(row.querySelector('.assembly-qty').value)||0);item.unitPrice=Math.max(0,Number(row.querySelector('.assembly-price').value)||0)}if(item.keyplcData&&!autoPanel){const currentSurcharge=normalizePanelType(item.keyplcData.enclosure)==='sheltered'?Number(item.keyplcData.shelteredSurcharge||1000):0;item.keyplcData.indoorUnitPrice=Math.max(0,item.unitPrice-currentSurcharge)}if(item.tankData&&!item.tankData.autoSelected){item.description=tankDescription(item,item.qty);current.description=replaceDescriptionBlock(current.description,previousDescription,item.description)}}});
 syncAutomaticComponents(current);if(!current.description_manual)rebuildDescription(current);current.description=normalizeDescriptionIndentation(current.description);if($('assemblyDescription'))$('assemblyDescription').value=current.description||'';renderDescriptionPreview()
}
function currentSessionDrafts(t=type){const session=quoteSessionId();return drafts.filter(x=>x.assembly_type===t&&x.quote_session_id===session&&((x.items||[]).length||String(x.model_item||'').trim()||String(x.description||'').trim()))}
function renderList(){const list=$('assemblyDraftList');if(!list)return;const rows=currentSessionDrafts(type);list.innerHTML=rows.map(d=>`<button type="button" class="${d.id===current?.id?'active':''}" data-draft="${esc(d.id)}"><b>${esc(d.model_item||d.name)}</b><br><small>${esc(d.status)} · ${money(quoteUnitPrice(d))}</small></button>`).join('')||'<div class="muted">No saved drafts.</div>';list.querySelectorAll('[data-draft]').forEach(b=>b.onclick=()=>{current=drafts.find(x=>x.id===b.dataset.draft);currentPinned=true;render()})}
function itemHtml(x){
 const autoPanel=!!(x.keyplcData?.autoSized||sourceObject(x).auto_sized_panel),autoGenerated=autoPanel||autoComponent(x,'manifold')||autoComponent(x,'tank'),autoLocked=autoGenerated;
 const locked=autoLocked?' readonly aria-readonly="true" class="assembly-qty assembly-auto-locked"':' class="assembly-qty"',priceLocked=autoLocked?' readonly aria-readonly="true" class="assembly-price assembly-auto-locked"':' class="assembly-price"';
 const panel=x.keyplcData?`<div class="assembly-item-option"><label>Panel Type</label><select class="assembly-keyplc-type"><option value="indoor" ${normalizePanelType(x.keyplcData.enclosure)==='indoor'?'selected':''}>Indoor</option><option value="sheltered" ${normalizePanelType(x.keyplcData.enclosure)==='sheltered'?'selected':''}>Sheltered (+ RM 1,000.00)</option></select></div>`:'';
 const badge=autoGenerated?'<span class="assembly-auto-badge">Auto</span>':'';
 return `<div class="assembly-item assembly-item-${esc(x.section||'pumpset')} ${autoGenerated?'auto-generated':''}" data-assembly-item="${esc(x.id)}"><div><b>${esc(x.bomDescription||x.model)}</b>${badge}${panel}</div><div><label>Qty</label><input${locked} type="number" min="0" step="1" value="${Number(x.qty||1)}"></div><div><label>Unit Price</label><input${priceLocked} type="number" min="0" step="0.01" value="${Number(x.unitPrice||0).toFixed(2)}"></div><div><label>Total Price</label><div class="assembly-line-total">${money(Number(x.qty||0)*Number(x.unitPrice||0))}</div></div><button class="btn danger assembly-delete" type="button">Delete</button></div>`
}
function renderItems(){
 const box=$('assemblyItems');if(!box)return;box.innerHTML=sections[type].map(section=>{const rows=(current?.items||[]).filter(x=>x.section===section);return `<section class="assembly-section assembly-section-${esc(section)}"><div class="assembly-section-head"><h2>${labels[section]}</h2><span>${rows.length} item${rows.length===1?'':'s'}</span></div><div class="assembly-section-body">${rows.map(itemHtml).join('')||'<p class="muted assembly-empty">Empty</p>'}</div></section>`}).join('');
 box.querySelectorAll('input').forEach(i=>i.oninput=()=>{if(i.classList.contains('assembly-qty'))current.description_manual=false;read();renderItems();renderQuoteFields();scheduleAutoSave()});
 box.querySelectorAll('.assembly-keyplc-type').forEach(select=>select.onchange=()=>{current.description_manual=false;read();const row=select.closest('[data-assembly-item]'),item=current.items.find(x=>x.id===row?.dataset.assemblyItem);updateKeyplcItem(item,select.value);if(!current.description_manual)rebuildDescription(current);current.description=normalizeDescriptionIndentation(current.description);if($('assemblyDescription'))$('assemblyDescription').value=current.description||'';renderDescriptionPreview();localSave();renderItems();renderQuoteFields();scheduleAutoSave(100)});
 box.querySelectorAll('.assembly-delete').forEach(b=>b.onclick=()=>{read();const row=b.closest('[data-assembly-item]'),item=current.items.find(x=>x.id===row?.dataset.assemblyItem);if(item){current.description_manual=false;current.description=removeDescriptionBlock(current.description,item.description);if(autoComponent(item,'manifold'))current.auto_suppressed={...(current.auto_suppressed||{}),manifold:true};if(autoComponent(item,'tank'))current.auto_suppressed={...(current.auto_suppressed||{}),tank:true}}current.items=current.items.filter(x=>x.id!==row.dataset.assemblyItem);syncAutomaticComponents(current);rebuildDescription(current);if($('assemblyDescription'))$('assemblyDescription').value=current.description||'';renderDescriptionPreview();localSave();renderItems();renderQuoteFields();scheduleAutoSave(100)});
 $('assemblyTotal').textContent=money(total())
}
function renderQuoteFields(){
 updateModelSuggestions();if($('assemblyModelItem'))$('assemblyModelItem').value=current.model_item||'';if($('assemblyQuoteQty'))$('assemblyQuoteQty').value=Number(current.quote_qty||1);if($('assemblyQuoteUnitPrice'))$('assemblyQuoteUnitPrice').value=Number(quoteUnitPrice(current)).toFixed(2)
}
function render(){
 if(!current||current.assembly_type!==type||current.quote_session_id!==quoteSessionId())current=currentSessionDrafts(type)[0]||blank(type);current=normalize(current);const qCustomer=quoteCustomerId();if(qCustomer)current.customer_id=qCustomer;syncAutomaticComponents(current);if(!current.description_manual)rebuildDescription(current);current.description=normalizeDescriptionIndentation(current.description);
 $('assemblyBuilderTitle').textContent=type==='system'?'System':'Pumpset';if($('newAssemblyDraft'))$('newAssemblyDraft').style.display=type==='system'?'none':'inline-flex';$('assemblyDescription').value=current.description||'';$('assemblyDescriptionLabel').textContent=type==='system'?'System Description':'Pumpset Description';$('assemblyCustomer').innerHTML='<option value="">No quotation customer selected</option>'+customers().map(c=>`<option value="${esc(c.id)}">${esc(c.company)}</option>`).join('');$('assemblyCustomer').value=current.customer_id||'';$('assemblyCustomer').disabled=true;if($('assemblyStatus'))$('assemblyStatus').value=current.status||'draft';$('assemblyNotice').textContent=qCustomer?'Customer is locked to the active Quotation selection. The KeyPLC panel, Manifold and Tank are selected automatically from the pump BOM, connection data and shut-off head.':'Select a customer in Dashboard or Quotation first. Assembly customer cannot be entered manually.';renderQuoteFields();renderList();renderItems();renderDescriptionPreview()
}
async function open(t){type=t;currentPinned=false;window.KeySuiteApp?.showPage?.('assemblyBuilder');if(!loaded)await load();if(!current||current.assembly_type!==type||current.quote_session_id!==quoteSessionId())current=currentSessionDrafts(type).find(x=>x.status==='draft')||currentSessionDrafts(type)[0]||blank(type);render()}
function routeItem(item={}){const level=String(item.assemblyLevel||item.assembly_level||'').toUpperCase();const section=String(item.assemblySection||item.assembly_section||'').toLowerCase();if(level==='COMPLETE_PUMPSET'||section==='pumpset')return {type:'system',section:'pumpset'};if(['pump','motor','coupling','baseplate'].includes(section))return {type:'pumpset',section};if(['control_panel','manifold','tank'].includes(section))return {type:'system',section};const model=String(item.model||'');if(/^CHC\b/i.test(model))return {type:'system',section:'pumpset'};if(/^ES\b/i.test(model))return {type:'pumpset',section:'pump'};if(/tank|gws/i.test(model+' '+(item.description||'')))return {type:'system',section:'tank'};return null}
async function addItem(item,explicitRoute){
 const route=explicitRoute||routeItem(item);if(!route){alert('This product has no supported System or Pumpset BOM destination.');return}const customerId=quoteCustomerId();if(!customerId){alert('Select the customer in Dashboard or Quotation first. Assembly follows the Quotation customer and cannot be filled manually.');window.KeySuiteApp?.showPage?.('dashboard');return}if(!loaded)await load();type=route.type;const session=quoteSessionId();
 let target=(current&&current.assembly_type===type&&current.customer_id===customerId&&current.quote_session_id===session)?current:null;
 if(!target)target=drafts.find(x=>x.assembly_type===type&&x.status==='draft'&&x.customer_id===customerId&&x.quote_session_id===session)||blank(type);
 if(type==='system'&&route.section==='pumpset'&&(target.items||[]).some(x=>x.section==='pumpset')&&!currentPinned){
   if(target===current){read();rebuildDescription(target);try{await persist(target)}catch(error){console.warn('Existing System draft saved locally only.',error)}}
   target=blank(type);drafts.unshift(target);
 }
 if(!drafts.some(x=>x.id===target.id))drafts.unshift(target);target.customer_id=customerId;target.quote_session_id=session;if(type==='system'&&route.section==='pumpset')target.auto_suppressed={manifold:false,tank:false};
 const rawDescription=item.keyplcData?keyplcDescription(item):String(item.description||'').trim(),description=String(rawDescription||'').trimEnd();if(type==='pumpset'&&route.section==='pump'&&!target.model_item)target.model_item=item.model||'';
 target.items.push(normalizeItem({id:uid(),section:route.section,model:item.model||'Product',bomDescription:item.bomDescription||item.model||'Product',description,qty:Number(item.qty||1),unitPrice:Number(item.unitPrice||0),pricingSource:item.pricingSource||null,pumpData:item.pumpData||null,tankData:item.tankData||null,keyplcData:item.keyplcData||null,manifoldData:item.manifoldData||null},type));
 current=target;current.description_manual=false;syncAutomaticComponents(current);rebuildDescription(current);localSave();window.KeySuiteApp?.showPage?.('assemblyBuilder');render();scheduleAutoSave(100);$('assemblyNotice').textContent=`${item.model||'Product'} routed to ${type==='system'?'System':'Pumpset'} → ${labels[route.section]}. Saving automatically…`;
}
async function toQuotation(){
 read();if(!current?.items?.length){alert('Add at least one component first.');return}if(!current.customer_id){alert('Select a customer for this assembly.');return}
 window.KeySuiteApp?.selectCustomerForQuotation?.(current.customer_id);
 const repriced=window.KeySuitePricing?.priceAssemblyForQuotation?.(current.items)||{error:'Quotation pricing is not available.'};if(repriced.error){alert(repriced.error);return}
 window.KeySuiteApp?.showPage?.('quotation');const description=normalizeDescriptionIndentation(String(current.description||'')).trim();
 current.quote_price_manual=false;current.quote_unit_price=Number(repriced.total||0);
 const row=window.KeySuiteApp?.addExternalQuoteItem?.({model:current.model_item||current.name||'',qty:Number(current.quote_qty||1),unitPrice:Number(repriced.total||0),description,unit:'set',sourceType:type,pricingSource:repriced.source});if(!row){alert('Unable to add the assembly to Quotation.');return}current.status='quoted';dirtyDraftIds.delete(current.id);try{await persist(current)}catch(e){alert(`Assembly quotation was created, but the assembly status could not be saved: ${e.message||e}`)}
}

function refreshPricing(){
 const pricing=window.KeySuitePricing;if(!pricing?.repriceSource)return;
 for(const draft of drafts){
   const customer=customers().find(row=>String(row.id)===String(draft.customer_id));if(!customer)continue;let changed=false;
   for(const item of draft.items||[]){
     const source=sourceObject(item);if(!source.product_family)continue;
     const found=pricing.repriceSource(source,'assembly',{customer});if(!found?.calc)continue;
     const nextPrice=Number(found.calc.finalPrice||0);if(Math.abs(nextPrice-Number(item.unitPrice||0))>.001||String(source.pricing_mode||'')!=='assembly')changed=true;
     item.unitPrice=nextPrice;item.pricingSource={...source,...(pricing.sourceSnapshot?.(found)||{}),pricing_mode:'assembly'};
   }
   if(changed){syncQuoteUnitPrice(draft);draft.updated_at=new Date().toISOString();dirtyDraftIds.add(draft.id);autoSaveRetries.set(draft.id,0)}
 }
 localSave();if(current)render();if(dirtyDraftIds.size){clearTimeout(autoSaveTimer);autoSaveTimer=setTimeout(()=>flushAutoSave(),100)}
}
function resetForNewQuotation(){clearTimeout(autoSaveTimer);autoSaveTimer=null;dirtyDraftIds.clear();autoSaveRetries.clear();current=blank(type);currentPinned=false;if(document.getElementById('assemblyBuilder')?.classList.contains('active'))render();else localSave()}
function pageShown(id){if(id==='assemblyBuilder'&&loaded)render()}
document.addEventListener('DOMContentLoaded',()=>{
 document.querySelectorAll('[data-assembly-open]').forEach(b=>b.onclick=()=>open(b.dataset.assemblyOpen));$('newAssemblyDraft')?.addEventListener('click',()=>{if(type==='system')return;current=blank(type);currentPinned=false;render()});$('deleteAssemblyDraft')?.addEventListener('click',()=>remove().catch(e=>alert(e.message||e)));$('assemblyToQuotation')?.addEventListener('click',()=>toQuotation());
 $('assemblyModelItem')?.addEventListener('input',()=>{current.model_item=$('assemblyModelItem').value.trim();current.name=current.model_item||current.name;scheduleAutoSave()});
 $('assemblyQuoteQty')?.addEventListener('input',()=>{current.quote_qty=Math.max(.01,Number($('assemblyQuoteQty').value)||1);scheduleAutoSave()});
 $('assemblyQuoteUnitPrice')?.addEventListener('input',()=>{const value=$('assemblyQuoteUnitPrice').value;if(value===''){current.quote_price_manual=false;syncQuoteUnitPrice(current);$('assemblyQuoteUnitPrice').value=Number(quoteUnitPrice(current)).toFixed(2)}else{current.quote_price_manual=true;current.quote_unit_price=Math.max(0,Number(value)||0)}scheduleAutoSave()});
 const main=$('assemblyDescription'),preview=$('assemblyDescriptionPreview'),dlg=$('assemblyDescriptionDialog'),popup=$('assemblyDescriptionPopup');
 const openDescriptionEditor=()=>{if(!dlg||!popup||!main)return;popup.value=main.value;dlg.showModal();setTimeout(()=>popup.focus(),0)};
 preview?.addEventListener('dblclick',openDescriptionEditor);preview?.addEventListener('keydown',event=>{if(event.key==='Enter'||event.key===' '){event.preventDefault();openDescriptionEditor()}});
 $('saveAssemblyDescriptionPopup')?.addEventListener('click',()=>{current.description_manual=true;current.description=normalizeDescriptionIndentation(popup.value);main.value=current.description;renderDescriptionPreview();scheduleAutoSave(100)})
});
window.KeySuiteAssembly={open,addItem,routeItem,pageShown,resetForNewQuotation,refreshPricing,refreshAutomaticPanel:()=>{if(current){syncAutomaticComponents(current);render();scheduleAutoSave(100)}}};
})();
