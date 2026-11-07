const fs=require('fs'),vm=require('vm'),assert=require('assert');
const code=fs.readFileSync('App/CanvasServiceWorker.js','utf8'),html=fs.readFileSync('App/CanvasShell.html','utf8'),handlers={};
const cache=new Map(),calls=[];let mode='online';
const sandbox={Response,Request,URL,AbortController,setTimeout,clearTimeout,Error,self:{location:{origin:'https://car.tesla4khmer.com'},addEventListener:(name,fn)=>handlers[name]=fn,skipWaiting:async()=>{},clients:{claim:async()=>{}}},caches:{open:async()=>({match:async k=>cache.get(k)?.clone(),put:async(k,r)=>cache.set(k,r.clone())}),keys:async()=>[]},fetch:async request=>{const path=typeof request==='string'?request:new URL(request.url).pathname;calls.push(path);if(mode==='offline')throw Error('phone absent');if(mode==='wrong')return new Response('<h1>Experimental local HTTP connection</h1>');return new Response(html,{headers:{'Content-Type':'text/html'}})}};
// Request URLs inside install() are relative in service workers.
sandbox.Request=class extends Request{constructor(url,opt){super(typeof url==='string'&&url.startsWith('/')?'https://car.tesla4khmer.com'+url:url,opt);}};
vm.runInNewContext(code,sandbox);
(async()=>{let installed;handlers.install({waitUntil:p=>installed=p});await installed;assert(cache.has('/'));
 async function navigate(path='/video'){let promise;handlers.fetch({request:{url:'https://car.tesla4khmer.com'+path,mode:'navigate',method:'GET'},respondWith:p=>promise=p});return promise;}
 // Native Request objects cannot carry navigate mode in Node fixtures.
 sandbox.Request=class extends Request{constructor(input,opt){const url=typeof input==='string'?input:input.url;super(url.startsWith('/')?'https://car.tesla4khmer.com'+url:url,opt);}};
 const online=await navigate();assert((await online.text()).includes('id="mediaCanvas"'));assert(calls.includes('/video'),'Navigation must check the current phone before returning cached UI');
 mode='offline';assert((await(await navigate()).text()).includes('id="mediaCanvas"'),'Offline static shell survives with honest disconnected initial status');
 mode='wrong';assert((await(await navigate()).text()).includes('id="mediaCanvas"'),'Never replace secure viewer with an HTTP approval page');
 let intercepted=false;handlers.fetch({request:{url:'https://car.tesla4khmer.com/media/state?token=secret',method:'GET',mode:'cors'},respondWith:()=>intercepted=true});assert(!intercepted,'Never cache media or authentication');
 mode='wrong';let rejected;handlers.install({waitUntil:p=>rejected=p});await assert.rejects(rejected,/Correct viewer UI unavailable/);
 console.log('OFFLINE_SHELL_PASSED: live network-first navigation, safe static fallback, wrong-page cache poisoning rejected, media/auth excluded.');
})().catch(e=>{console.error(e);process.exit(1)});
