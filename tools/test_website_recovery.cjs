const fs=require('fs'),assert=require('assert'),{chromium}=require('playwright');
const app=process.argv[2]||'App',override=process.env.SCREENLINK_TEST_SHELL_OVERRIDE;
(async()=>{const browser=await chromium.launch({headless:true,args:['--no-sandbox']});try{
 const context=await browser.newContext({viewport:{width:1280,height:720}});let peer=1,approved=null,phase='automatic',counter=0,offline=false,requests=[];
 await context.route('https://car.tesla4khmer.com/**',async route=>{
  const req=route.request(),u=new URL(req.url());
  const assets={'/video':'CanvasShell.html','/':'CanvasShell.html','/split':'CanvasShell.html','/app/pure.js':'CanvasShell.js'};
  if(assets[u.pathname])return route.fulfill({contentType:u.pathname.endsWith('.js')?'application/javascript':'text/html',body:fs.readFileSync(u.pathname==='/app/pure.js'&&override?override:app+'/'+assets[u.pathname],'utf8')});
  if(u.pathname==='/app/screen.js')return route.fulfill({contentType:'application/javascript',body:'window.ScreenLinkScreen={CanvasScreen:class{constructor(){this.framesDrawn=0;}hide(){}destroy(){}privacy(){}state(){}}};'});
  if(['/app/canvas.js','/app/mp4box.js','/app/mux.js','/sw.js'].includes(u.pathname))return route.fulfill({contentType:'application/javascript',body:''});
  if(u.pathname.endsWith('.jpg')||u.pathname.endsWith('.webp'))return route.fulfill({contentType:u.pathname.endsWith('.webp')?'image/webp':'image/jpeg',body:fs.readFileSync(app+'/'+(u.pathname.endsWith('.webp')?'CarAmbient.webp':'CarPoster.jpg'))});
  if(u.pathname==='/local-viewer/request'){
   const body=req.postDataJSON();requests.push({...body,peer});assert(req.headers().origin==='https://car.tesla4khmer.com');
   if(offline)return route.fulfill({status:503,body:'temporarily unavailable'});
   if(phase==='pending')return route.fulfill({contentType:'application/json',body:JSON.stringify({phase:'pending'})});
   if(!approved){approved={nonce:body.nonce,peer,token:'private-proof-'+(++counter)};}
   else if(approved.peer!==peer&&approved.nonce===body.nonce&&approved.token===body.previousToken){approved={nonce:body.nonce,peer,token:'private-proof-'+(++counter)};}
   const ok=approved.nonce===body.nonce&&approved.peer===peer;
   return route.fulfill({contentType:'application/json',body:JSON.stringify(ok?{phase:'approved',token:approved.token}:{phase:'busy'})});
  }
  if(u.pathname==='/media/state'||u.pathname==='/screen/privacy'){
   if(!approved||u.searchParams.get('token')!==approved.token||peer!==approved.peer)return route.fulfill({status:403,body:'{}'});
   return route.fulfill({contentType:'application/json',body:JSON.stringify(u.pathname==='/media/state'?{active:false,screenLocked:true}:{hidden:true,privacyRevision:1})});
  }
  return route.fulfill({status:404,body:''});
 });
 let page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));await page.goto('https://car.tesla4khmer.com/video');await page.waitForFunction(()=>ScreenLinkCanvasStatus().connected);
 const firstProof=approved.token;const saved=await page.evaluate(()=>JSON.parse(localStorage.getItem('screenlink-approved-viewer-v1')||'null'));assert(saved&&saved.token===firstProof,'Approved credential must survive closing/reloading the tab');
 for(let i=0;i<7;i++){peer++;const previous=approved.token;await page.reload();await page.waitForFunction(()=>ScreenLinkCanvasStatus().connected,null,{timeout:10000});assert.equal(requests.at(-1).previousToken,previous);assert.notEqual(approved.token,previous);}
 await page.close();peer++;page=await context.newPage();await page.goto('https://car.tesla4khmer.com/video');await page.waitForFunction(()=>ScreenLinkCanvasStatus().connected);assert.equal(approved.peer,peer,'A reopened tab must prove its existing session after DHCP changes');
 offline=true;await page.reload();await page.waitForFunction(()=>document.getElementById('status').textContent.includes('saved page only'));assert.equal(await page.evaluate(()=>ScreenLinkCanvasStatus().connectionPhase),'offline');offline=false;await page.waitForFunction(()=>ScreenLinkCanvasStatus().connected,null,{timeout:15000});
 const diagnostic=await page.evaluate(()=>JSON.stringify(ScreenLinkCanvasStatus()));assert(!diagnostic.includes('private-proof-')&&!diagnostic.includes(approved.nonce),'No credentials in copied playback diagnostics');
 // A different browser still needs phone approval. Never auto-take over merely
 // because it uses the same hotspot; only the stored nonce+token can rebind.
 await page.evaluate(()=>{sessionStorage.clear();localStorage.removeItem('screenlink-approved-viewer-v1');});await page.close();page=await context.newPage();await page.goto('https://car.tesla4khmer.com/video');await page.waitForFunction(()=>document.getElementById('status').textContent.includes('Another browser session'));assert.equal(await page.evaluate(()=>ScreenLinkCanvasStatus().connected),false);
 phase='pending';await page.waitForFunction(()=>document.getElementById('status').textContent.includes('Approve local viewer'),null,{timeout:10000});approved=null;phase='automatic';await page.waitForFunction(()=>ScreenLinkCanvasStatus().connected,null,{timeout:10000});
 assert.deepEqual(errors,[]);console.log('WEBSITE_RECOVERY_PASSED: seven DHCP/reload cycles, reopened tab proof, token rotation, temporary HTTPS outage and automatic reconnect; busy/pending shown honestly; no takeover or diagnostic credential leak.');
 }finally{await browser.close();}})().catch(e=>{console.error(e);process.exit(1)});
