/* Cache static viewer assets only. Cached UI is never proof of a live phone. */
'use strict';
const CACHE='screenlink-canvas-ui-66-httpshealth1',ASSETS=['/','/app/mp4box.js','/app/mux.js','/app/canvas.js','/app/screen.js','/app/pure.js','/app/car-poster.jpg','/app/car-ambient.webp'];
async function validShell(response){if(!response.ok)return false;const html=await response.clone().text();return html.includes('id="mediaCanvas"')&&html.includes('id="viewMode"')&&html.includes('/app/pure.js');}
self.addEventListener('install',event=>event.waitUntil((async()=>{const cache=await caches.open(CACHE);for(const path of ASSETS){const response=await fetch(new Request(path+'?screenlink-ui=66-httpshealth1',{cache:'reload',credentials:'same-origin'}));if(!response.ok||(path==='/'&&!await validShell(response)))throw Error('Correct viewer UI unavailable');await cache.put(path,response);}await self.skipWaiting();})()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{for(const name of await caches.keys())if(name.startsWith('screenlink-canvas-ui-')&&name!==CACHE)await caches.delete(name);await self.clients.claim();})()));
self.addEventListener('fetch',event=>{const url=new URL(event.request.url);if(url.origin!==self.location.origin||event.request.method!=='GET')return;
 if(event.request.mode==='navigate'&&['/','/split','/map','/video'].includes(url.pathname)){event.respondWith((async()=>{const cache=await caches.open(CACHE),cached=await cache.match('/');const control=new AbortController(),timeout=setTimeout(()=>control.abort(),3000);try{const response=await fetch(new Request(event.request,{cache:'no-store',signal:control.signal}));if(!await validShell(response))throw Error('Response is not the secure viewer');return response;}catch{return cached||new Response('Phone not connected. Start ScreenLink, keep the hotspot connected and reload.',{status:503});}finally{clearTimeout(timeout);}})());}
 else if(!url.search&&ASSETS.includes(url.pathname)){event.respondWith((async()=>{const cache=await caches.open(CACHE);return await cache.match(url.pathname)||fetch(event.request);})());}
});



