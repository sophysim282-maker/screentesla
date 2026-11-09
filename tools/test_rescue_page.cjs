// Build 97: a reload while the phone cannot be reached shows the saved car page (which then
// reconnects by itself) instead of the browser error page. Online, the phone's page always wins.
const fs=require('fs'),http=require('http'),assert=require('assert'),{chromium}=require('playwright');
const worker=fs.readFileSync('App/CanvasServiceWorker.js','utf8');
let offline=false,version='live-1',apiCalls=0;
const html=v=>'<!doctype html><html><body data-version="'+v+'"><script src="/app/pure.js"></script></body></html>';
const server=http.createServer((req,res)=>{const url=new URL(req.url,'http://localhost');res.setHeader('Cache-Control','no-store');
 if(offline){req.socket.destroy();return;}
 if(url.pathname==='/sw.js'){res.setHeader('Content-Type','application/javascript');return res.end(worker);}
 if(['/','/video'].includes(url.pathname)){res.setHeader('Content-Type','text/html');return res.end(html(version));}
 if(url.pathname==='/app/pure.js'){res.setHeader('Content-Type','application/javascript');return res.end("document.body.dataset.script='"+version+"';navigator.serviceWorker.register('/sw.js',{scope:'/'});");}
 if(url.pathname.startsWith('/media/')){apiCalls++;res.setHeader('Content-Type','application/json');return res.end('{"n":'+apiCalls+'}');}
 res.statusCode=404;res.end();
});
(async()=>{let browser;try{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://localhost:'+server.address().port;
 browser=await chromium.launch({headless:true,args:['--no-sandbox']});const page=await (await browser.newContext()).newPage();
 await page.goto(base+'/video');await page.waitForFunction(()=>navigator.serviceWorker.controller!==null,null,{timeout:15000}).catch(async()=>{await page.reload();await page.waitForFunction(()=>navigator.serviceWorker.controller!==null);});
 await page.reload();assert.equal(await page.locator('body').getAttribute('data-version'),'live-1');
 offline=true;await page.reload();
 assert.equal(await page.locator('body').getAttribute('data-version'),'live-1','Saved page shown while the phone is unreachable');
 assert.equal(await page.locator('body').getAttribute('data-script'),'live-1','Saved script runs, so the page can reconnect');
 assert(!(await page.evaluate(b=>fetch(b+'/media/state?token=x').then(()=>true,()=>false),base)),'API requests are never answered from the saved copy');
 offline=false;version='live-2';await page.reload();
 assert.equal(await page.locator('body').getAttribute('data-version'),'live-2','Online, the phone page always wins');
 assert.equal(await page.locator('body').getAttribute('data-script'),'live-2');
 offline=true;await page.reload();assert.equal(await page.locator('body').getAttribute('data-version'),'live-2','Saved copy follows the latest phone page');
 assert.deepEqual(await page.evaluate(()=>caches.keys()),['screenlink-rescue-v1']);
 console.log('RESCUE_PAGE_PASSED: unreachable reload shows the saved car page with its script; online always loads the phone page; API never cached.');
}finally{server.closeAllConnections?.();server.close();await browser?.close();}})().catch(e=>{console.error(e);process.exit(1);});
