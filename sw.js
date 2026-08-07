const CACHE='keysuite-v360';
const SHELL=['./','./index.html','./permissions.js','./applications.js','./app.js','./assembly.js','./motor.js','./coupling.js','./quotation-templates.js','./pricing.js','./quotation-references.js','./categories.js','./pricelist.js','./product.js','./manifold.js','./roles.js','./company-settings.js','./keyai.js','./auth.js','./manifest.json','./keylargo-logo.png','./selector-es/index.html','./selector-es/es-core.js','./selector-es/es-data.js','./selector-es/bgreich-logo.png','./selector-es/favicon.svg'];
self.addEventListener('install',event=>{self.skipWaiting();event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(SHELL)));});
self.addEventListener('activate',event=>{event.waitUntil(Promise.all([caches.keys().then(keys=>Promise.all(keys.filter(key=>key!==CACHE).map(key=>caches.delete(key)))),self.clients.claim()]));});
self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET')return;
  const url=new URL(event.request.url);if(url.origin!==location.origin)return;
  event.respondWith(fetch(event.request,{cache:'no-store'}).then(response=>{const copy=response.clone();caches.open(CACHE).then(cache=>cache.put(event.request,copy));return response;}).catch(()=>caches.match(event.request)));
});
