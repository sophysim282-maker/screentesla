// Real browser H.264 RTP plus DTLS/SCTP peers; signaling is an in-memory fixture.
// This does not test the production service or an iPhone/Tesla connection.
const fs=require('fs'),assert=require('assert'),path=require('path'),{chromium}=require('playwright');
(async()=>{
 const codec=process.argv.includes('--vp8')?'video/VP8':'video/H264';
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 try {
  const phone=await browser.newPage();await phone.goto('about:blank');
  const offer=await phone.evaluate(async codec=>{
   window.peer=new RTCPeerConnection({iceServers:[]});window.channel=peer.createDataChannel('ping');window.pongs=0;window.renderedByViewer=0;
   const image=document.createElement('canvas');image.width=640;image.height=360;document.body.appendChild(image);const ctx=image.getContext('2d');let n=0;
   function draw(){ctx.fillStyle='#305090';ctx.fillRect(0,0,640,360);ctx.fillStyle=n%2?'#ff9933':'#22ff99';ctx.fillRect((n*9)%500,40,120,240);n++;}draw();window.drawing=setInterval(draw,33);
   const transceiver=peer.addTransceiver(image.captureStream(30).getVideoTracks()[0],{direction:'sendonly'});const codecs=RTCRtpSender.getCapabilities('video').codecs.filter(c=>c.mimeType===codec);if(!codecs.length)throw Error('Requested codec unavailable');transceiver.setCodecPreferences(codecs);
   channel.onmessage=e=>{if(e.data==='ping')channel.send('pong');else if(e.data==='pong')pongs++;else {try{const report=JSON.parse(e.data);if(report.type==='video-report')renderedByViewer=report.framesRendered;}catch{}}};
   channel.onopen=()=>{window.pinger=setInterval(()=>{if(channel.readyState==='open')channel.send('ping');},1000);};
   await peer.setLocalDescription(await peer.createOffer());
   const until=performance.now()+3000;while(peer.iceGatheringState!=='complete'&&performance.now()<until)await new Promise(r=>setTimeout(r,30));
   return peer.localDescription.sdp;
  },codec);assert(offer.includes('a=candidate:'));
  let approved=false,answerSubmitted=false,expired=false,deleted=false;const reports=[];
  const viewer=await browser.newPage();await viewer.addInitScript(()=>{const Native=window.RTCPeerConnection;window.RTCPeerConnection=class extends Native{constructor(...args){super(...args);window.testPeer=this;}};});const errors=[];viewer.on('pageerror',e=>errors.push(e.message));
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
  approved=true;await viewer.waitForFunction(()=>document.getElementById('status').textContent.includes('VIDEO ACTIVE'),null,{timeout:20000});
  await phone.waitForFunction(()=>pongs>0);assert(answerSubmitted);
  await viewer.waitForFunction(()=>document.getElementById('decoder').getVideoPlaybackQuality().totalVideoFrames>20);
  const stats=await viewer.evaluate(async()=>{const report=await testPeer.getStats();let result={};report.forEach(s=>{if(s.type==='inbound-rtp'&&s.kind==='video')result={frames:s.framesDecoded,bytes:s.bytesReceived,codec:report.get(s.codecId).mimeType};});return result;});assert(stats.frames>20&&stats.bytes>0&&stats.codec===codec);
  const hash=()=>viewer.locator('#picture').evaluate(c=>{const p=c.getContext('2d').getImageData(0,0,c.width,c.height).data;let h=0;for(let i=0;i<p.length;i+=100)h=(h+p[i]*(i+1))>>>0;return h;});const first=await hash();await viewer.waitForTimeout(450);assert.notEqual(await hash(),first,'Canvas must show changing received video pixels');
  await phone.waitForFunction(()=>renderedByViewer>20);
  const until=Date.now()+13000;while(!reports.some(r=>r.state==='connected'&&r.framesRendered>20)&&Date.now()<until)await new Promise(r=>setTimeout(r,100));
  assert(reports.some(r=>r.state==='connected'&&r.bytesReceived>0&&r.framesRendered>20&&r.dataChannelPingOk));
  expired=true;await viewer.waitForFunction(()=>document.getElementById('events').textContent.includes('Signaling expired'),null,{timeout:4000});
  await viewer.waitForFunction(()=>document.getElementById('status').textContent.includes('VIDEO ACTIVE')&&document.getElementById('status').textContent.includes('signaling expired'));
  await phone.evaluate(()=>{clearInterval(drawing);});
  await viewer.waitForFunction(()=>!document.getElementById('status').textContent.includes('VIDEO ACTIVE'),null,{timeout:6000});
  assert(await viewer.locator('#picture').evaluate(c=>{const p=c.getContext('2d').getImageData(0,0,c.width,c.height).data;return !p.some((v,i)=>i%4!==3&&v>0);}),'Stale video must be blanked');
  await phone.evaluate(()=>{clearInterval(pinger);channel.onmessage=null;});
  await viewer.waitForFunction(()=>document.getElementById('status').textContent.includes('Waiting for WebRTC'),null,{timeout:18000});
  await viewer.click('#stop');assert(deleted);assert.equal(await viewer.locator('#status').textContent(),'Stopped');assert.equal(await viewer.locator('#decoder').evaluate(v=>v.srcObject),null);assert.deepEqual(errors,[]);
  console.log(codec+' browser video fixture passed: decoded/changed Canvas frames, frame telemetry, stale-video blanking, explicit approval, actual bidirectional data-channel traffic, verified state report, retained peer after signaling expiry, stale-ping detection and Stop. No production or physical-device test.');
 } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exit(1);});
