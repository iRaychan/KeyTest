/* KeySuite V3.8.2 R2 service worker — network first + safe extension injection */
const CACHE='keysuite-v382-r2';
const EXTENSION='./v382-dashboard-keycore.js';
self.addEventListener('install',event=>{self.skipWaiting();event.waitUntil(caches.open(CACHE).then(cache=>cache.add(EXTENSION).catch(()=>{})));});
self.addEventListener('activate',event=>{event.waitUntil(Promise.all([
 caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('keysuite-')&&k!==CACHE).map(k=>caches.delete(k)))),
 self.clients.claim()
]));});
async function injectExtension(response){
 if(!response||!response.ok)return response;
 const ct=response.headers.get('content-type')||'';if(!/text\/html/i.test(ct))return response;
 let text=await response.text();const extUrl=new URL('v382-dashboard-keycore.js?v=3822',self.registration.scope).href;if(!/v382-dashboard-keycore\.js/i.test(text))text=text.replace(/<\/body>/i,'<script src="'+extUrl+'"></script></body>');
 const headers=new Headers(response.headers);headers.delete('content-length');headers.delete('content-encoding');headers.delete('transfer-encoding');headers.set('cache-control','no-store');
 return new Response(text,{status:response.status,statusText:response.statusText,headers});
}
self.addEventListener('fetch',event=>{
 if(event.request.method!=='GET')return;const url=new URL(event.request.url);if(url.origin!==location.origin)return;
 if(event.request.mode==='navigate'){
  event.respondWith((async()=>{try{const r=await fetch(event.request,{cache:'no-store'});const c=r.clone();caches.open(CACHE).then(cache=>cache.put(event.request,c)).catch(()=>{});return await injectExtension(r)}catch(e){const cached=await caches.match(event.request);return cached?injectExtension(cached):Response.error()}})());return;
 }
 event.respondWith(fetch(event.request,{cache:'no-store'}).then(r=>{const c=r.clone();caches.open(CACHE).then(cache=>cache.put(event.request,c)).catch(()=>{});return r}).catch(()=>caches.match(event.request)));
});
