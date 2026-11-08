// Real browser upgrade: an installed old worker must not keep serving its shell.
const fs=require('fs'),http=require('http'),assert=require('assert'),{chromium}=require('playwright');
const oldWorker=fs.readFileSync(process.argv[2],'utf8'),newWorker=fs.readFileSync('App/CanvasServiceWorker.js','utf8');
let upgraded=false,offline=false,navigations=0;
const html=version=>'<!doctype html><html><body data-version="'+version+'"><select id="viewMode"></select><canvas id="mapCanvas"></canvas><canvas id="mediaCanvas"></canvas><script src="/app/pure.js"></script></body></html>';
const server=http.createServer((req,res)=>{const url=new URL(req.url,'http://localhost');res.setHeader('Cache-Control','no-store');
 if(offline){req.socket.destroy();return;}
 if(url.pathname==='/sw.js'){res.setHeader('Content-Type','application/javascript');res.end(upgraded?newWorker:oldWorker);return;}
 if(['/','/video','/split','/map'].includes(url.pathname)){navigations++;res.setHeader('Content-Type','text/html');res.end(html(upgraded?'live-67':'saved-64'));return;}
 if(url.pathname.endsWith('.js')){res.setHeader('Content-Type','application/javascript');res.end('/* test static asset */');return;}
 res.end('image fixture');
});
(async()=>{let browser;try{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port;
 browser=await chromium.launch({headless:true,args:['--no-sandbox']});const context=await browser.newContext(),page=await context.newPage();
 await page.goto(base+'/video');await page.evaluate(async()=>{await navigator.serviceWorker.register('/sw.js',{scope:'/'});await navigator.serviceWorker.ready;});await page.waitForFunction(()=>navigator.serviceWorker.controller!==null);
 assert((await page.evaluate(()=>caches.keys())).some(n=>n.startsWith('screenlink-canvas-ui-')),'Install real old cache');
 offline=true;await page.reload();assert.equal(await page.locator('body').getAttribute('data-version'),'saved-64','Old worker does show saved UI without phone');
 offline=false;upgraded=true;
 // This is the update check made by an existing registration, not new page code.
 await page.evaluate(async()=>{const registration=await navigator.serviceWorker.getRegistration('/');await registration.update();}).catch(error=>{if(!error.message.includes('Execution context was destroyed'))throw error;});
 await page.waitForFunction(()=>document.body.dataset.version==='live-67',null,{timeout:15000});
 await page.waitForFunction(async()=>!(await navigator.serviceWorker.getRegistration('/'))&&navigator.serviceWorker.controller===null);
 assert.deepEqual(await page.evaluate(()=>caches.keys()),[],'Only the live phone copy remains');
 const before=navigations;await page.reload();assert(navigations>before,'Reload requests phone HTML');
 offline=true;await page.reload().then(()=>assert.fail('Offline saved page must no longer load'),()=>{});
 console.log('OFFLINE_RETIREMENT_PASSED: old cached UI reproduced; real worker update removes cache/registration and reloads live shell once; subsequent offline navigation fails instead of showing a saved viewer.');
 }finally{server.closeAllConnections?.();server.close();await browser?.close();}
})().catch(e=>{console.error(e);process.exit(1)});
