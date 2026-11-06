const fs=require('fs'),path=require('path'),assert=require('assert'),{chromium}=require('playwright');
(async()=>{const browser=await chromium.launch({headless:true,args:['--no-sandbox']});try{
 for(const [file,connect,disconnect] of [['webrtc-youtube-viewer.html','pair','stop'],['webrtc-ping-viewer.html','join','stop']]){
  const page=await browser.newPage();let mode='wait',attempts=[],lookups=0,offers=0,deletes=0,secret='',lateResolve=null,lateReady=false;
  await page.route('https://viewer.screenlink.test/**',route=>route.fulfill({contentType:'text/html',body:fs.readFileSync(path.join(__dirname,'../docs',file))}));
  await page.route('https://tesla4khmer.com/api/public/screenlink/**',async route=>{
   const req=route.request(),suffix=new URL(req.url()).pathname.replace('/api/public/screenlink','');let status=200,body={};
   if(suffix==='/auto-join'){
    const b=req.postDataJSON();assert(!req.headers().authorization);assert(/^[a-f0-9]{64}$/.test(b.viewerSecret));assert(!('pairingCode' in b));attempts.push(b.viewerSecret);lookups++;
    if(mode==='wait'&&lookups===1){status=404;body={error:'no_receiver'};}
    else if(mode==='ambiguous'){status=409;body={error:'ambiguous_receiver'};}
    else if(mode==='unavailable'){status=503;body={error:'discovery_unavailable'};}
    else if(mode==='cancel'){status=404;body={error:'no_receiver'};}
    else{if(mode==='late'){lateReady=true;await new Promise(resolve=>lateResolve=resolve);}secret=b.viewerSecret;status=202;body={joinId:'fixture-join',viewerSecret:secret,status:'pending_approval'};}
   }else{
    assert.equal(req.headers().authorization,'Viewer '+secret);
    if(req.method()==='DELETE'){deletes++;body={status:'closed'};}
    else if(suffix.endsWith('/status'))body={status:'pending_approval',negotiationRevision:null};
    else{offers++;throw Error('Offer/media must not be requested before phone approval');}
   }
   await route.fulfill({status,contentType:'application/json',body:JSON.stringify(body)});
  });
  await page.goto('https://viewer.screenlink.test/');assert.equal(await page.locator('#code').count(),0);assert((await page.locator('#'+connect).textContent()).includes('Connect phone'));
  await page.click('#'+connect);await page.waitForFunction(()=>document.getElementById('status').textContent.includes('Looking for ScreenLink'),null,{timeout:2000});await page.waitForFunction(()=>document.getElementById('status').textContent.includes('Approve'),null,{timeout:7000});
  assert.equal(lookups,2);assert.equal(attempts[0],attempts[1]);assert.equal(offers,0);assert(!(await page.locator('body').innerText()).includes(secret));
  await page.click('#'+disconnect);assert.equal(deletes,1);mode='ambiguous';await page.click('#'+connect);await page.waitForFunction(()=>document.getElementById('status').textContent.includes('More than one'),null,{timeout:4000});assert(await page.locator('#'+connect).isEnabled());assert.notEqual(attempts[2],attempts[0]);
  mode='cancel';const previousLookups=lookups;await page.click('#'+connect);await page.waitForFunction(()=>document.getElementById('status').textContent.includes('Looking for ScreenLink'),null,{timeout:4000});const lookupDeadline=Date.now()+2000;while(lookups===previousLookups&&Date.now()<lookupDeadline)await new Promise(r=>setTimeout(r,20));assert(lookups>previousLookups);const before=lookups;await page.click('#'+disconnect);await page.waitForTimeout(3300);assert.equal(lookups,before);assert(!/Looking|Approve/.test(await page.locator('#status').textContent()));
  mode='late';await page.click('#'+connect);const lateDeadline=Date.now()+2000;while(!lateReady&&Date.now()<lateDeadline)await new Promise(r=>setTimeout(r,20));assert(lateReady);const beforeLate=deletes;await page.click('#'+disconnect);lateResolve();const cleanupDeadline=Date.now()+3000;while(deletes===beforeLate&&Date.now()<cleanupDeadline)await new Promise(r=>setTimeout(r,20));assert.equal(deletes,beforeLate+1,'A cancelled late successful claim must be released');assert(!/Looking|Approve/.test(await page.locator('#status').textContent()));
  mode='unavailable';await page.click('#'+connect);await page.waitForFunction(()=>document.getElementById('status').textContent.includes('discovery is unavailable'),null,{timeout:4000});assert(await page.locator('#'+connect).isEnabled());assert.equal(offers,0);
  console.log(file+': code-free lookup passed: no numeric field/body, stable opaque retries, phone approval required, ambiguous/unavailable errors, cancellation, late-claim cleanup and clean disconnect. Fixture service, not physical hotspot.');await page.close();
 }
}finally{await browser.close();}})().catch(error=>{console.error(error);process.exit(1);});
