// Real native-library interoperability. SDP/credentials stay in private temporary files.
const fs=require('fs'),path=require('path'),assert=require('assert'),{chromium}=require('playwright');
(async()=>{const folder=process.argv[2],input=JSON.parse(fs.readFileSync(path.join(folder,'offer.json'),'utf8')),browser=await chromium.launch({headless:true,args:['--no-sandbox']});try{
 console.log('Native TCP interoperability browser: '+await browser.version());
 const page=await browser.newPage();await page.goto('about:blank');
 const answer=await page.evaluate(async offer=>{window.peer=new RTCPeerConnection({iceServers:[]});window.echoes={media:false,screen:false};window.pingOk=false;
  const payload=label=>Uint8Array.from({length:8192},(_,i)=>(i*17+(label==='media'?29:47))&255);
  peer.ondatachannel=event=>{const ch=event.channel;ch.binaryType='arraybuffer';if(ch.label==='ping'){ch.onmessage=event=>{if(event.data==='ping'){ch.send('pong');pingOk=true;}};return;}
   ch.onmessage=event=>{if(typeof event.data==='string'&&event.data==='hello-'+ch.label){ch.send(payload(ch.label));return;}if(event.data instanceof ArrayBuffer){const got=new Uint8Array(event.data),expected=payload(ch.label);echoes[ch.label]=got.length===expected.length&&got.every((v,i)=>v===expected[i]);}};
  };
  await peer.setRemoteDescription({type:'offer',sdp:offer});await peer.setLocalDescription(await peer.createAnswer());const end=performance.now()+10000;while(peer.iceGatheringState!=='complete'&&performance.now()<end)await new Promise(r=>setTimeout(r,25));
  const lines=peer.localDescription.sdp.split('\r\n').filter(line=>!line.startsWith('a=candidate:')||line.split(/\s+/)[2]?.toLowerCase()==='tcp');// Chromium may initiate TCP using a peer-reflexive candidate without advertising a TCP listener.
  return lines.join('\r\n');
 },input.offer);
 const answerFile=path.join(folder,'answer.json'),temp=answerFile+'.tmp';fs.writeFileSync(temp,JSON.stringify({sdpAnswer:answer}),{mode:0o600});fs.renameSync(temp,answerFile);
 await page.waitForFunction(()=>echoes.media&&echoes.screen&&pingOk&&peer.connectionState==='connected',null,{timeout:45000});
 const report=await page.evaluate(async()=>{const stats=await peer.getStats();let pair;stats.forEach(item=>{if(item.type==='transport'&&item.selectedCandidatePairId)pair=stats.get(item.selectedCandidatePairId);});if(!pair)stats.forEach(item=>{if(item.type==='candidate-pair'&&item.nominated&&item.state==='succeeded')pair=item;});const local=stats.get(pair?.localCandidateId)||{};return {mediaEchoOk:echoes.media,screenEchoOk:echoes.screen,pingOk,protocol:local.protocol,bytesSent:pair?.bytesSent||0,bytesReceived:pair?.bytesReceived||0};});
 assert.equal(report.protocol,'tcp');assert(report.bytesSent>0&&report.bytesReceived>0);const result=path.join(folder,'result.json');fs.writeFileSync(result+'.tmp',JSON.stringify(report),{mode:0o600});fs.renameSync(result+'.tmp',result);
 const end=Date.now()+12000;while(!fs.existsSync(path.join(folder,'native-checked'))&&Date.now()<end)await new Promise(r=>setTimeout(r,25));assert(fs.existsSync(path.join(folder,'native-checked')));console.log('Chromium TCP-only echo and selected transport checks passed.');
 }finally{await browser.close();}})().catch(error=>{console.error(error.message);process.exit(1);});

