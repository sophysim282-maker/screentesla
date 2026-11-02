// Real browser DTLS/SCTP peers; signaling is a controlled in-memory fixture.
// This does not test the production service or an iPhone/Tesla connection.
const fs=require('fs'),assert=require('assert'),path=require('path'),{chromium}=require('playwright');
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 try {
  const phone=await browser.newPage();await phone.goto('about:blank');
  const offer=await phone.evaluate(async()=>{
   window.peer=new RTCPeerConnection({iceServers:[]});window.channel=peer.createDataChannel('ping');window.pongs=0;
   channel.onmessage=e=>{if(e.data==='ping')channel.send('pong');else if(e.data==='pong')pongs++;};
   channel.onopen=()=>{window.pinger=setInterval(()=>{if(channel.readyState==='open')channel.send('ping');},1000);};
   await peer.setLocalDescription(await peer.createOffer());
   const until=performance.now()+3000;while(peer.iceGatheringState!=='complete'&&performance.now()<until)await new Promise(r=>setTimeout(r,30));
   return peer.localDescription.sdp;
  });assert(offer.includes('a=candidate:'));
  let approved=false,answerSubmitted=false,expired=false,deleted=false;const reports=[];
  const viewer=await browser.newPage();const errors=[];viewer.on('pageerror',e=>errors.push(e.message));
  await viewer.route('https://viewer.screenlink.test/**',route=>route.fulfill({contentType:'text/html',body:fs.readFileSync(path.join(__dirname,'../docs/webrtc-ping-viewer.html'))}));
  await viewer.route('https://tesla4khmer.com/api/public/screenlink/**',async route=>{
   const request=route.request(),suffix=new URL(request.url()).pathname.replace('/api/public/screenlink','');
   const auth=request.headers().authorization;let status=200,body={};
   if(suffix==='/join'){assert(!auth);assert.equal(request.postDataJSON().pairingCode,'123456');status=202;body={joinId:'fixture-join',viewerSecret:'b'.repeat(64),status:'pending_approval'};}
   else {assert.equal(auth,'Viewer '+'b'.repeat(64));
    if(request.method()==='DELETE'){deleted=true;body={status:'closed'};}
    else if(expired){status=410;body={error:'expired'};}
    else if(suffix.endsWith('/status'))body={status:approved?'approved':'pending_approval',negotiationRevision:approved?1:null};
    else if(suffix.endsWith('/offer')){assert(approved,'Offer must not be fetched before approval');body={sdpOffer:offer,negotiationRevision:1,iceGathering:'complete'};}
    else if(suffix.endsWith('/answer')){assert(approved);const data=request.postDataJSON();assert.equal(data.negotiationRevision,1);assert(data.sdpAnswer.includes('a=candidate:'));await phone.evaluate(sdp=>peer.setRemoteDescription({type:'answer',sdp}),data.sdpAnswer);answerSubmitted=true;body={status:'answer_submitted'};}
    else if(suffix.endsWith('/state')){reports.push(request.postDataJSON());body={status:'connected',negotiationRevision:1};}
    else throw Error('Unexpected fixture endpoint');
   }await route.fulfill({status,contentType:'application/json',body:JSON.stringify(body)});
  });
  await viewer.goto('https://viewer.screenlink.test/');await viewer.fill('#code','123456');await viewer.click('#join');
  await viewer.waitForFunction(()=>document.getElementById('status').textContent.includes('Approve'));assert(!answerSubmitted);
  approved=true;await viewer.waitForFunction(()=>document.getElementById('status').textContent.includes('WebRTC ping verified'),null,{timeout:20000});
  await phone.waitForFunction(()=>pongs>0);assert(answerSubmitted);
  await viewer.waitForFunction(()=>document.getElementById('events').textContent.includes('Real bidirectional ping verified'));
  const until=Date.now()+13000;while(!reports.some(r=>r.state==='connected')&&Date.now()<until)await new Promise(r=>setTimeout(r,100));
  assert(reports.some(r=>r.state==='connected'&&r.bytesReceived>0&&r.bytesSent>0&&r.dataChannelPingOk));
  expired=true;await viewer.waitForFunction(()=>document.getElementById('events').textContent.includes('Signaling expired'),null,{timeout:4000});
  await viewer.waitForFunction(()=>document.getElementById('status').textContent.includes('Local ping verified · signaling expired'));
  await phone.evaluate(()=>{clearInterval(pinger);channel.onmessage=null;});
  await viewer.waitForFunction(()=>document.getElementById('status').textContent.includes('Local ping unavailable'),null,{timeout:18000});
  await viewer.click('#stop');assert(deleted);assert.equal(await viewer.locator('#status').textContent(),'Stopped');assert.deepEqual(errors,[]);
  console.log('Browser pairing fixture passed: explicit approval, actual bidirectional data-channel traffic, verified state report, retained peer after signaling expiry, stale-ping detection and Stop. No production or physical-device test.');
 } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exit(1);});
