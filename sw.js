const CACHE='keysuite-v381-keycore';
const SHELL=['./','./index.html','./permissions.js','./applications.js','./app.js','./assembly.js','./motor.js','./coupling.js','./quotation-templates.js','./pricing.js','./quotation-references.js','./categories.js','./pricelist.js','./product.js','./manifold.js','./roles.js','./company-settings.js','./keyai.js','./auth.js','./manifest.json','./keylargo-logo.png','./universe.js','./selector-es/index.html','./selector-es/es-core.js','./selector-es/es-data.js','./selector-es/bgreich-logo.png','./selector-es/favicon.svg'];
self.addEventListener('install',event=>{self.skipWaiting();event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(SHELL)));});
self.addEventListener('activate',event=>{event.waitUntil(Promise.all([caches.keys().then(keys=>Promise.all(keys.filter(key=>key!==CACHE).map(key=>caches.delete(key)))),self.clients.claim()]));});
function isKeySuiteShell(request,url,response){
  if(request.mode!=='navigate')return false;
  if(!response||!response.ok)return false;
  const scopePath=new URL(self.registration.scope).pathname.replace(/\/+$/,'/');
  const path=url.pathname;
  return path===scopePath||path===scopePath+'index.html';
}
async function injectKeyCore(response){
  const type=response.headers.get('content-type')||'';
  if(type&&!type.includes('text/html'))return response;
  let html=await response.text();
  if(!html.includes('universe.js'))html=html.replace(/<\/body>/i,'<script src="universe.js?v=381"></script></body>');
  const headers=new Headers(response.headers);headers.delete('content-length');headers.delete('content-encoding');headers.set('content-type','text/html; charset=utf-8');
  return new Response(html,{status:response.status,statusText:response.statusText,headers});
}
self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET')return;
  const url=new URL(event.request.url);if(url.origin!==location.origin)return;
  event.respondWith((async()=>{
    try{
      const network=await fetch(event.request,{cache:'no-store'});
      let output=network;
      if(isKeySuiteShell(event.request,url,network))output=await injectKeyCore(network.clone());
      const copy=output.clone();caches.open(CACHE).then(cache=>cache.put(event.request,copy));return output;
    }catch(_){
      const cached=await caches.match(event.request);if(!cached)throw _;
      if(isKeySuiteShell(event.request,url,cached))return injectKeyCore(cached.clone());
      return cached;
    }
  })());
});
