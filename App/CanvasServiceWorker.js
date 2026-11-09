/* Build 97: rescue copy of the car page.
 * The car sometimes reloads the page while it cannot look up car.tesla4khmer.com, and then shows
 * "server IP address could not be found". This worker keeps the last page the phone served.
 * It always asks the phone first (network first). Only when the page cannot be fetched at all
 * (name lookup or Wi-Fi failure) it shows the saved copy, whose own code then reconnects by itself.
 * Phone API, media and map requests are never cached or answered by this worker.
 * The old build 64 offline cache (screenlink-canvas-ui-*) is still deleted. */
'use strict';
const RESCUE='screenlink-rescue-v1';
const PAGES=['/','/video','/split','/map'];
self.addEventListener('install',event=>event.waitUntil(self.skipWaiting()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
 for(const name of await caches.keys())if(name.startsWith('screenlink-canvas-ui-'))await caches.delete(name);
 await self.clients.claim();
})()));
function rescuable(request){
 if(request.method!=='GET')return false;
 const url=new URL(request.url);
 if(url.origin!==self.location.origin||url.searchParams.has('token'))return false;
 return PAGES.includes(url.pathname)||url.pathname.startsWith('/app/');
}
self.addEventListener('fetch',event=>{
 const request=event.request;if(!rescuable(request))return;
 const url=new URL(request.url),key=url.origin+url.pathname;
 event.respondWith((async()=>{
  try{
   const response=await fetch(request,{cache:'no-store'});
   if(response.ok&&response.type==='basic'){const copy=response.clone();caches.open(RESCUE).then(cache=>cache.put(key,copy)).catch(()=>{});}
   return response;
  }catch(error){
   const saved=await caches.match(key,{cacheName:RESCUE});
   if(saved)return saved;
   throw error;
  }
 })());
});
