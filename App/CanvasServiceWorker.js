/* Static UI only. Never cache tokens, state, screen frames, HLS or media data. */
'use strict';
const CACHE='screenlink-canvas-ui-46',ASSETS=['/','/app/mp4box.js','/app/mux.js','/app/canvas.js','/app/screen.js','/app/pure.js'];
self.addEventListener('install',event=>event.waitUntil((async()=>{const cache=await caches.open(CACHE);for(const path of ASSETS){const response=await fetch(new Request(path,{cache:'reload',credentials:'same-origin'}));if(!response.ok)throw Error('UI asset unavailable');await cache.put(path,response);}await self.skipWaiting();})()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{for(const name of await caches.keys())if(name.startsWith('screenlink-canvas-ui-')&&name!==CACHE)await caches.delete(name);await self.clients.claim();})()));
self.addEventListener('fetch',event=>{const url=new URL(event.request.url);if(url.origin!==self.location.origin||event.request.method!=='GET')return;
 if(event.request.mode==='navigate'&&['/','/split','/map','/video'].includes(url.pathname)){event.respondWith((async()=>{const cached=await caches.match('/');if(cached)return cached;try{return await fetch(event.request);}catch{return new Response('Start ScreenLink and reload.',{status:503});}})());}
 else if(!url.search&&ASSETS.includes(url.pathname)){event.respondWith((async()=>{const cached=await caches.match(url.pathname);return cached||fetch(event.request);})());}
});
