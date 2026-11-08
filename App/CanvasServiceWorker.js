/* Retire the old offline viewer. The phone is the only source of this website.
 * Keep this file at /sw.js so previously installed workers can update themselves.
 * There is intentionally no fetch handler and no offline fallback. */
'use strict';
self.addEventListener('install',event=>event.waitUntil(self.skipWaiting()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
 for(const name of await caches.keys())if(name.startsWith('screenlink-canvas-ui-'))await caches.delete(name);
 await self.clients.claim();
 await self.registration.unregister();
 // Existing pages may still be running the cached build64 script. A single
 // navigation after unregistering moves them to the live phone version.
 for(const client of await self.clients.matchAll({type:'window'})){
  const url=new URL(client.url);
  if(url.origin===self.location.origin&&['/','/video','/split','/map'].includes(url.pathname)){
   try{await client.navigate(client.url);}catch{}
  }
 }
})()));
