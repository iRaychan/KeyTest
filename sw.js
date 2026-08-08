/* KeySuite V3.8.7 service worker — full repository build, network first */
const CACHE='keysuite-v387';
const SHELL=[
 './','./index.html','./app.js','./permissions.js','./applications.js','./assembly.js','./motor.js','./coupling.js',
 './quotation-templates.js','./pricing.js','./quotation-references.js','./categories.js','./pricelist.js','./product.js',
 './manifold.js','./roles.js','./company-settings.js','./keyai.js','./auth.js','./manifest.json','./keylargo-logo.png',
 './universe.js','./v387-dashboard-keycore.js','./selector/index.html','./selector-es/index.html','./selector-es/es-core.js',
 './selector-es/es-data.js','./selector-es/motor-data.js','./selector-es/bgreich-logo.png','./selector-es/favicon.svg'
];
self.addEventListener('install',event=>{self.skipWaiting();event.waitUntil(caches.open(CACHE).then(cache=>Promise.allSettled(SHELL.map(x=>cache.add(x)))));});
self.addEventListener('activate',event=>{event.waitUntil(Promise.all([
 caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('keysuite-')&&k!==CACHE).map(k=>caches.delete(k)))),
 self.clients.claim()
]));});
self.addEventListener('fetch',event=>{
 if(event.request.method!=='GET')return;
 const url=new URL(event.request.url);if(url.origin!==location.origin)return;
 event.respondWith((async()=>{
  try{
   const r=await fetch(event.request,{cache:'no-store'});
   if(r&&r.ok){const c=r.clone();caches.open(CACHE).then(cache=>cache.put(event.request,c)).catch(()=>{});}
   return r;
  }catch(e){
   const cached=await caches.match(event.request);
   if(cached)return cached;
   if(event.request.mode==='navigate')return (await caches.match('./index.html'))||Response.error();
   return Response.error();
  }
 })());
});
