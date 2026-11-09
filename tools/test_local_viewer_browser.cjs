const fs=require('fs'),assert=require('assert'),{chromium}=require('playwright');
(async()=>{const browser=await chromium.launch({headless:true,args:['--no-sandbox']});try{
 const page=await browser.newPage();let phase='pending',requests=0,nonce;
 await page.route('http://3.3.3.3:8080/**',async route=>{
  const req=route.request(),url=new URL(req.url());
  if(url.pathname==='/')return route.fulfill({contentType:'text/html',body:fs.readFileSync('App/LocalViewer.html','utf8')});
  if(url.pathname==='/local-viewer/request'){
   requests++;assert.equal(req.method(),'POST');assert.equal(req.headers()['x-screenlink-viewer'],'request');assert.equal(req.headers().origin,'http://3.3.3.3:8080');const body=req.postDataJSON();assert(/^[0-9a-f]{32}$/.test(body.nonce));if(nonce)assert.equal(body.nonce,nonce);nonce=body.nonce;
   return route.fulfill({contentType:'application/json',body:JSON.stringify({phase,...(phase==='approved'?{token:'approved-session'}:{})})});
  }
  assert.equal(phase,'approved','No viewer or media request before approval');assert.equal(url.pathname,'/split');assert.equal(url.searchParams.get('token'),'approved-session');return route.fulfill({contentType:'text/html',body:'<p>Approved local viewer fixture</p>'});
 });
 await page.goto('http://3.3.3.3:8080/');assert.equal(requests,0);assert.equal(await page.evaluate(()=>isSecureContext),false);await page.click('#connect');await page.waitForFunction(()=>document.getElementById('status').textContent.includes('Approve local viewer'));assert.equal(requests,1);assert(!await page.locator('body').innerText().then(t=>t.includes('approved-session')));
 phase='approved';await page.waitForURL('**/split?token=approved-session');assert.equal(await page.locator('p').innerText(),'Approved local viewer fixture');
 phase='rejected';await page.goto('http://3.3.3.3:8080/');await page.click('#connect');await page.waitForFunction(()=>document.getElementById('status').textContent.includes('Rejected'));const before=requests;await page.waitForTimeout(1800);assert.equal(requests,before);assert(await page.locator('#connect').isEnabled());
 phase='busy';await page.click('#connect');await page.waitForFunction(()=>document.getElementById('status').textContent.includes('Another local viewer'));
 console.log('Local alias browser passed on insecure HTTP origin: explicit Connect, no media before approval, origin/header/nonce, same-origin redirect, rejected/busy states.');
 }finally{await browser.close();}})().catch(e=>{console.error(e);process.exit(1)});
