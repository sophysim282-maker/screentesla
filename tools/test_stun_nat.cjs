// Real Chrome in a 192.168.93.0/24 network namespace, behind a router whose
// hotspot interface is 172.20.10.4. The production C STUN service runs on .1.
// This is a NAT interoperability test, not an exact Tesla-policy emulator.
const fs=require('fs'),path=require('path'),assert=require('assert'),cp=require('child_process'),{chromium}=require('playwright');
(async()=>{
 let host,car,server;let serverLog='';
 try{
  server=cp.spawn(path.resolve('build/stun-server'),['172.20.10.1','3478']);server.stderr.on('data',b=>serverLog+=b);await new Promise((resolve,reject)=>{server.once('error',reject);server.once('exit',code=>reject(Error('STUN server exited '+code)));server.stdout.once('data',b=>{assert.equal(b.toString().trim(),'3478');resolve();});});
  host=await chromium.launch({executablePath:process.env.SCREENLINK_REAL_CHROME,headless:true,args:['--no-sandbox','--disable-features=WebRtcHideLocalIpsWithMdns','--force-webrtc-ip-handling-policy=default']});
  car=await chromium.launch({executablePath:process.env.SCREENLINK_NAT_CHROME,headless:true,args:['--no-sandbox','--disable-features=WebRtcHideLocalIpsWithMdns','--force-webrtc-ip-handling-policy=default']});console.log('NAT browser version:',await car.version());
  const phone=await host.newPage();await phone.goto('about:blank');
  const offer=await phone.evaluate(async()=>{
   window.peer=new RTCPeerConnection({iceServers:[]});window.ping=peer.createDataChannel('ping');window.pongs=0;
   ping.onmessage=e=>{if(e.data==='ping')ping.send('pong');else if(e.data==='pong')pongs++;};ping.onopen=()=>{window.tick=setInterval(()=>{if(ping.readyState==='open')ping.send('ping');},500);};
   const canvas=document.createElement('canvas');canvas.width=640;canvas.height=360;const c=canvas.getContext('2d');let n=0;window.motion=setInterval(()=>{c.fillStyle='#135';c.fillRect(0,0,640,360);c.fillStyle='#fff';c.fillRect((n++*8)%600,100,40,40);},50);peer.addTrack(canvas.captureStream(20).getVideoTracks()[0]);
   await peer.setLocalDescription(await peer.createOffer());const end=performance.now()+10000;while(peer.iceGatheringState!=='complete'&&performance.now()<end)await new Promise(r=>setTimeout(r,30));
   let lines=peer.localDescription.sdp.split('\r\n').filter(l=>!l.startsWith('a=candidate:')||l.trim().split(/\s+/)[4]==='172.20.10.1');if(!lines.some(l=>l.startsWith('a=candidate:')))throw Error('Host lacks phone-side candidate: '+JSON.stringify(peer.localDescription.sdp.split('\r\n').filter(l=>l.startsWith('a=candidate:')).map(l=>{const f=l.trim().split(/\s+/);return {address:f[4],protocol:f[2]};})));const m=lines.findIndex(l=>l.startsWith('m='));lines.splice(m,0,'a=x-screenlink-stun:stun:172.20.10.1:3478');return lines.join('\r\n');
  });
  const viewer=await car.newPage();let approved=false,secret='',answer='',answerSeen=false;const errors=[];viewer.on('pageerror',e=>errors.push(e.message));
  await viewer.route('https://viewer.screenlink.test/**',r=>r.fulfill({contentType:'text/html',body:fs.readFileSync('docs/webrtc-ping-viewer.html')}));
  await viewer.route('https://tesla4khmer.com/api/public/screenlink/**',async route=>{
   const req=route.request(),suffix=new URL(req.url()).pathname.replace('/api/public/screenlink','');let code=200,body={};
   if(suffix==='/auto-join'){secret=req.postDataJSON().viewerSecret;code=202;body={joinId:'nat-viewer',viewerSecret:secret};}
   else{assert.equal(req.headers().authorization,'Viewer '+secret);
    if(req.method()==='DELETE')body={status:'closed'};
    else if(suffix.endsWith('/status'))body={status:approved?'approved':'pending_approval',negotiationRevision:approved?1:null};
    else if(suffix.endsWith('/offer')){assert(approved);body={sdpOffer:offer,negotiationRevision:1};}
    else if(suffix.endsWith('/answer')){answer=req.postDataJSON().sdpAnswer;assert(/a=candidate:.* 172\.20\.10\.4 \d+ typ srflx/.test(answer),'The actual NAT address must be gathered from the phone-local STUN response');await phone.evaluate(sdp=>peer.setRemoteDescription({type:'answer',sdp}),answer);answerSeen=true;body={status:'answer_submitted'};}
    else if(suffix.endsWith('/state'))body={status:'connected'};else throw Error('Unexpected endpoint');
   }await route.fulfill({status:code,contentType:'application/json',body:JSON.stringify(body)});
  });
  await viewer.goto('https://viewer.screenlink.test/');await viewer.click('#join');await viewer.waitForFunction(()=>document.getElementById('status').textContent.includes('Approve'));approved=true;
  await viewer.waitForFunction(()=>document.getElementById('status').textContent.includes('VIDEO ACTIVE'),null,{timeout:30000});await phone.waitForFunction(()=>pongs>2);assert(answerSeen);
  const remote=await phone.evaluate(async()=>{const r=await peer.getStats();let pair;r.forEach(v=>{if(v.type==='transport'&&v.selectedCandidatePairId)pair=r.get(v.selectedCandidatePairId);});const c=r.get(pair.remoteCandidateId);return {address:c.address||c.ip,bytes:pair.bytesReceived,dtls:[...r.values()].filter(v=>v.type==='transport').map(v=>v.dtlsState)};});
  assert.equal(remote.address,'172.20.10.4');assert(remote.bytes>0&&remote.dtls.includes('connected'));assert.deepEqual(errors,[]);
  await viewer.click('#stop');console.log('LOCAL_NAT_PASSED: browser host network 192.168.93.0/24, genuine srflx 172.20.10.4 from production phone-local STUN, encrypted WebRTC ping and moving Canvas frames. No external STUN/TURN or cloud media. Not a physical Tesla test.');
 }finally{
  if(car)await car.close();if(host)await host.close();if(server&&!server.killed){server.kill('SIGTERM');await new Promise(resolve=>server.once('exit',resolve));}if(serverLog)console.log(serverLog.trim());
 }
})().catch(e=>{console.error(e);process.exit(1);});
