const http=require('http'),fs=require('fs'),path=require('path'),assert=require('assert'),{chromium}=require('playwright');
const actual=fs.readFileSync(path.join(process.argv[2],'CanvasServiceWorker.js'),'utf8');let old=true;
const requests=[];const server=http.createServer((req,res)=>{requests.push({url:req.url,old});res.setHeader('Cache-Control','no-store');
 if(req.url==='/sw.js'){res.setHeader('Content-Type','application/javascript');return res.end(old?actual.replace('screenlink-canvas-ui-59','screenlink-canvas-ui-57'):actual);}
 if(req.url.startsWith('/app/')){res.setHeader('Content-Type','application/javascript');return res.end(old?'/* build57 cached script */':'/* build59 refreshed script */');}
 res.setHeader('Content-Type','text/html');res.end('<h1>'+ (old?'BUILD57':'BUILD59')+'</h1>');
});
(async()=>{let browser;try{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));browser=await chromium.launch({headless:true,args:['--no-sandbox']});const page=await browser.newPage();
 await page.goto('http://127.0.0.1:'+server.address().port);
 await page.evaluate(async()=>{await navigator.serviceWorker.register('/sw.js');await navigator.serviceWorker.ready;});await page.waitForFunction(()=>!!navigator.serviceWorker.controller);
 assert((await page.evaluate(()=>caches.keys())).includes('screenlink-canvas-ui-57'));
 await page.evaluate(async()=>{window.oldWorker=(await navigator.serviceWorker.getRegistration()).active;});
 old=false;
 await page.evaluate(async()=>{const r=await navigator.serviceWorker.getRegistration();await r.update();});
 const deadline=Date.now()+15000;let activated=false;
 while(Date.now()<deadline){
  activated=await page.evaluate(async()=>{const keys=await caches.keys(),r=await navigator.serviceWorker.getRegistration();return r.active!==window.oldWorker&&r.active?.state==='activated'&&keys.includes('screenlink-canvas-ui-59')&&!keys.includes('screenlink-canvas-ui-57');});
  if(activated)break;await page.waitForTimeout(100);
 }
 assert(activated,'New worker did not finish activation/cache migration');
 console.log('CACHE_UPGRADE_STATE',await page.evaluate(async()=>{const data={};for(const name of await caches.keys()){const cache=await caches.open(name);data[name]=[];for(const request of await cache.keys())data[name].push({url:request.url,body:(await(await cache.match(request)).text()).slice(0,70)});}return data;}));
 await page.reload();console.log('CACHE_REQUESTS',requests);assert.equal(await page.locator('h1').textContent(),'BUILD59');
 assert((await page.evaluate(async()=>await(await fetch('/app/canvas.js')).text())).includes('build59'));
 console.log('BUILD59_CACHE_MIGRATION_PASSED: existing build57 service worker/cache upgrades to build59 UI and decoder assets, without media/token caching.');
}finally{await browser?.close();server.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
