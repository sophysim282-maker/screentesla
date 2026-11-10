/* Parked local viewer. The active page creates no media elements. */
(()=>{'use strict';
const $=id=>document.getElementById(id),status=$('status'),mapCover=$('mapCover'),mediaCover=$('mediaCover');
// Decoration uses image decoding only: no HTML media player or sound session.
// Remove the animated source before handing hardware decoding to YouTube.
const artwork=$('idleArtwork'),reducedMotion=matchMedia('(prefers-reduced-motion: reduce)');let idleWanted=true;
function refreshArtwork(){if(!artwork)return;const animate=idleWanted&&!document.hidden&&!reducedMotion.matches;const path=animate?'/app/car-ambient.webp':'/app/car-poster.jpg';if(artwork.getAttribute('src')!==path)artwork.src=path;artwork.hidden=!idleWanted;}
function setIdleArtwork(wanted){idleWanted=wanted;refreshArtwork();}
document.addEventListener('visibilitychange',refreshArtwork);reducedMotion.addEventListener('change',refreshArtwork);
try{const theme=localStorage.getItem('screenlink-theme');if(['light','dark'].includes(theme))document.documentElement.dataset.theme=theme;}catch{}
if($('themeToggle'))$('themeToggle').onclick=()=>{const dark=(document.documentElement.dataset.theme||(matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light'))!=='dark';document.documentElement.dataset.theme=dark?'dark':'light';$('themeToggle').setAttribute('aria-label',dark?'Switch to light appearance':'Switch to dark appearance');try{localStorage.setItem('screenlink-theme',dark?'dark':'light');}catch{}};
refreshArtwork();
if(artwork)artwork.onerror=()=>{if(artwork.getAttribute('src')!=='/app/car-poster.jpg')artwork.src='/app/car-poster.jpg';};
document.querySelector('.tools')?.addEventListener('click',event=>{if(event.target.closest('button'))document.querySelector('.tools').open=false;});
let token='',nonce='',joining=false,connected=false,stopped=false,ws=null,wsTimer=0,wsAttempt=0,pendingPacket=null,wsWork=Promise.resolve(),polling=false,privacyPending=false,screenFault=false,minRevision=0,player=null,mediaEpoch='',command=-1,sourceState=null,audioContext=null,soundWanted=false,mediaGeneration=0,mediaFailed=false,youtubeOnly=false,modeBusy=false,reconnectTimer=0,retryCount=0,retryAt=0,retryPosition=0,lastPlaybackError=null,resumeConnection=null,lastConnectionError=null;
const developerMode=new URLSearchParams(location.search).get('developer')==='1';
// Build 73: WebCodecs is the default again, as in builds 64-70. ?engine=browser selects the build 71 browser video player for comparison.
const requestedDecoder=['software','hardware'].includes(new URLSearchParams(location.search).get('decoder'))?new URLSearchParams(location.search).get('decoder'):'auto';
const requestedEngine=new URLSearchParams(location.search).get('engine')==='browser'?'browser':'webcodecs';let activeEngine='';
if(developerMode){const option=document.createElement('option');option.value='hd';option.textContent='Developer · source quality';$('quality').appendChild(option);$('quality').value='hd';}
let previousPlaybackProfile=null,performanceFrozen=false;
let stablePlaybackSince=0,stableMediaTime=0,stableDrawn=0;
let healthFailures=0,lastHealthyAt=Date.now(),transportWaiting=false,decoderFaults=0;
let previousToken='',joinGeneration=0,session=0,tickTimer=0,reportPending=false,reconnections=0,lastProgressAt=Date.now(),lastDrawn=0;
let connectionPhase='connecting',approvalPhase='',lastRequestAt=0,lastSuccessAt=0;
const credentialKey='screenlink-approved-viewer-v1';
function restoreCredential(){for(const storage of [()=>sessionStorage,()=>localStorage])try{const saved=JSON.parse(storage().getItem(credentialKey)||'null');if(saved&&/^[0-9a-f]{32}$/.test(saved.nonce)&&typeof saved.token==='string'&&saved.token.length>0&&saved.token.length<=128&&saved.expires>Date.now()){nonce=saved.nonce;previousToken=saved.token;return true;}}catch{}return false;}
function saveCredential(){if(!nonce||!previousToken)return;const saved=JSON.stringify({nonce,token:previousToken,expires:Date.now()+14400000});for(const storage of [()=>sessionStorage,()=>localStorage])try{storage().setItem(credentialKey,saved);}catch{}}
restoreCredential();
function errorDetail(){if(!lastConnectionError)return '';const e=lastConnectionError,m=String(e.message||'').slice(0,120);return ' ['+(e.httpStatus?'HTTP '+e.httpStatus+' · ':'')+m+' · '+new Date(e.time).toLocaleTimeString()+']';}
// Build 75: car playback problems go to the phone log (CAR PLAYER lines), so no
// on-screen diagnostics are needed. Short text only; no tokens or URLs.
// Build 102: measure how long a video takes to show its first picture (measuring only).
let mediaStartAt=0,mediaStartLogged=true;
const sentCarEvents=new WeakSet();let carLogQueue=[],lastReportedPlaybackError=null,lastReportedConnectionError=null,lastCarSummaryAt=0,lastCarDecoder='';
function carLogLine(text){carLogQueue.push(String(text).replace(/[\u0000-\u001f]/g,' ').slice(0,220));if(carLogQueue.length>6)carLogQueue.splice(0,carLogQueue.length-6);}
function collectCarLog(p){
 if(!p)return;const at=t=>Number.isFinite(t)?t.toFixed(1)+'s':'?';let fresh=false;
 for(const e of p.playbackEvents||[]){if(sentCarEvents.has(e))continue;sentCarEvents.add(e);fresh=true;carLogLine(e.type+' at '+at(e.position)+(e.videoLead!==undefined?' · video ahead '+Number(e.videoLead).toFixed(2)+'s':'')+(e.audioLead!==undefined?' · sound ahead '+Number(e.audioLead).toFixed(2)+'s':'')+(e.detail?' · '+e.detail:''));}
 if(!mediaStartLogged&&mediaStartAt&&(p.stats?.drawn||0)>0){mediaStartLogged=true;fresh=true;const parts=(p.segmentDiagnostics||[]).slice(0,4).map(d=>(d.kind||'data')+' '+Math.round(d.fetchMs||0)+'ms download + '+Math.round(d.demuxMs||0)+'ms unpack');carLogLine('start took '+((Date.now()-mediaStartAt)/1000).toFixed(1)+'s to the first picture · '+$('mediaCanvas').width+'x'+$('mediaCanvas').height+(parts.length?' · first pieces: '+parts.join(', '):''));}
 const decoder=p.videoAcceleration||activeEngine||'';if(decoder&&decoder!==lastCarDecoder){if(lastCarDecoder)fresh=true;carLogLine('video decoder now '+decoder);lastCarDecoder=decoder;}
 if(lastPlaybackError&&lastPlaybackError!==lastReportedPlaybackError){lastReportedPlaybackError=lastPlaybackError;fresh=true;carLogLine('player error: '+String(lastPlaybackError.message||'').slice(0,120)+' at '+at(lastPlaybackError.position));}
 if(lastConnectionError&&lastConnectionError!==lastReportedConnectionError){lastReportedConnectionError=lastConnectionError;carLogLine('connection was interrupted: '+String(lastConnectionError.message||'').slice(0,100)+' at '+new Date(lastConnectionError.time).toLocaleTimeString()+(lastConnectionError.failures?' after '+lastConnectionError.failures+' failed checks':''));}
 if(fresh||Date.now()-lastCarSummaryAt>60000){lastCarSummaryAt=Date.now();const s=p.stats||{};carLogLine('summary: '+(activeEngine||'?')+' '+(p.videoAcceleration||'')+' · '+$('mediaCanvas').width+'x'+$('mediaCanvas').height+' · quality '+$('quality').value+' · at '+at(p.currentTime)+' · pictures '+(s.drawn||0)+' · decoder restarts '+(s.videoRecoveries||0)+' · picture holds '+(s.videoHiccups||0)+' · rebuffers '+(s.rebufferCount||0)+' · sound gaps '+(s.audioUnderruns||0)+(s.softwareDecoderFallback?' · SOFTWARE DECODER':''));}
}
// Build 92: "lost phone" report and backup button. When the page loses the phone, remember
// when and why; after reconnecting, send one CAR PLAYER line with the lost period. After 20 s
// lost, show a button that opens the backup address (the HTTP fallback player at 3.3.3.3:8080).
let lostSince=0,lostReason='',switchTimer=0;const backupURL='http://3.3.3.3:8080/';
function clockText(t){return new Date(t).toLocaleTimeString();}
function switchButton(){let b=$('backupSwitch');if(b)return b;b=document.createElement('a');b.id='backupSwitch';b.href=backupURL;b.textContent='Phone not reachable · Switch to 3.3.3.3';b.hidden=true;b.setAttribute('style','position:fixed;left:50%;bottom:28px;transform:translateX(-50%);z-index:9999;padding:18px 30px;border-radius:16px;background:#e8453c;color:#fff;font:600 22px system-ui,sans-serif;text-decoration:none;box-shadow:0 8px 30px rgba(0,0,0,.45)');b.addEventListener('click',()=>{try{carLogLine('backup button tapped after '+Math.round((Date.now()-lostSince)/1000)+' s lost');}catch{}});document.body.appendChild(b);return b;}
function trackConnection(phase,message){
 if(phase==='reconnecting'||phase==='offline'){if(!lostSince){lostSince=Date.now();lostReason=String(lastConnectionError?.message||message||'').slice(0,90);clearTimeout(switchTimer);switchTimer=setTimeout(()=>{if(lostSince)switchButton().hidden=false;},20000);}}
 else if(phase==='connected'&&lostSince){const from=lostSince,now=Date.now();lostSince=0;clearTimeout(switchTimer);const b=$('backupSwitch');if(b)b.hidden=true;carLogLine('lost phone '+clockText(from)+'–'+clockText(now)+' ('+Math.round((now-from)/1000)+' s) · '+lostReason);}
}
function connectionNotice(phase,message){trackConnection(phase,message);connectionPhase=phase;status.textContent=message+(phase==='reconnecting'||phase==='offline'?errorDetail():'');document.body.dataset.connection=phase;}
let phoneVolume=1,phoneEQ='normal',phoneSettingsRevision=0,phonePlaybackRevision=0;
function readPhoneControls(next){
 const control=next.viewerControls;if(!control)return false;
 const q=['auto','720','1080','1440','2160'].includes(control.quality)?control.quality:'auto';
 const changed=$('quality').value!==q;$('quality').value=q;refreshInline('quality');
 phoneVolume=Number.isFinite(control.volume)?Math.min(1,Math.max(0,control.volume)):1;
 phoneEQ=control.eq==='music'?'music':'normal';$('eq').value=phoneEQ;refreshInline('eq');
 phoneSettingsRevision=Number(control.revision)||0;return changed;
}
function applyPhoneAudio(){
 if(!player)return;player.setEQ(phoneEQ);
 if(player.gain&&audioContext?.state==='running')player.gain.gain.setTargetAtTime(phoneVolume,audioContext.currentTime,.02);
}
function refreshSoundPrompt(){
 const minimal=youtubeOnly&&!developerMode;
 $('sound').hidden=minimal&&(!connected||!player||(soundWanted&&audioContext?.state==='running'));
 if(minimal)$('sound').textContent='Tap for sound · fullscreen';
}
async function applyPhonePlayback(next){
 const control=next.viewerControls?.playback;
 if(!control||control.epoch!==mediaEpoch||control.sourceCommand!==next.command||!player||mediaFailed||control.revision<=phonePlaybackRevision)return;
 if(Number.isFinite(control.seek)&&control.seek>=0)player.currentTime=control.seek;
 if(typeof control.paused==='boolean'){if(control.paused)player.pause();else await player.play();}
 phonePlaybackRevision=control.revision;
}
let lockedView=false;
const inlineControls={};
function refreshInline(id){const control=inlineControls[id];if(!control)return;for(const button of control.buttons){button.disabled=control.select.disabled||(id==='viewMode'&&button.dataset.value==='split'&&lockedView);button.setAttribute('aria-pressed',String(control.select.value===button.dataset.value));}}
function makeInline(id){const select=$(id),group=document.createElement('span');group.className='inline-options';group.setAttribute('role','group');group.setAttribute('aria-label',select.getAttribute('aria-label')||'Viewer mode');const buttons=[];for(const option of select.options){const button=document.createElement('button');button.type='button';button.textContent=option.textContent;button.dataset.select=id;button.dataset.value=option.value;button.onclick=()=>{if(select.disabled||select.value===option.value)return;select.value=option.value;select.dispatchEvent(new Event('change',{bubbles:true}));refreshInline(id);};group.appendChild(button);buttons.push(button);}select.after(group);select.hidden=true;select.setAttribute('aria-hidden','true');select.tabIndex=-1;inlineControls[id]={select,buttons};new MutationObserver(()=>refreshInline(id)).observe(select,{attributes:true,attributeFilter:['disabled']});refreshInline(id);}
let screen=new ScreenLinkScreen.CanvasScreen($('mapCanvas'),{onstate:screenState,onerror:screenError});
function screenState(meta){if((Number(meta.privacyRevision)||0)<minRevision)return;minRevision=Math.max(minRevision,Number(meta.privacyRevision)||0);if(meta.hidden){mapCover.hidden=false;mapCover.textContent=meta.confirmed?'PHONE SCREEN HIDDEN — open Maps before showing.':'Phone screen hidden.';$('privacyState').textContent=meta.confirmed?'HIDDEN confirmed on phone.':'Screen hidden; phone confirmation pending.';}else if(meta.frameReady&&!privacyPending){mapCover.hidden=true;$('privacyState').textContent='Screen visible. Hide before leaving Maps.';}else if(meta.localHidden){mapCover.hidden=false;mapCover.textContent='Screen hidden locally. Press Show screen with Maps open.';}
 $('mapDetail').textContent='WebCodecs · '+(meta.framesDrawn||screen.framesDrawn)+' frames drawn · rotation '+(meta.orientation||1);}
function hideLocal(message){screen.hide();mapCover.hidden=false;mapCover.textContent=message;$('privacyState').textContent=message;}
function screenError(error){screenFault=true;hideLocal('Screen decoder stopped: '+error.message);$('mapDetail').textContent=error.message;ws?.close();}
async function raw(path,options={}){const control=new AbortController(),timeout=setTimeout(()=>control.abort(),7000);lastRequestAt=Date.now();try{
 // Build 83: a reused connection can be closed by the phone just as it is used
 // ("Failed to fetch"); retry such a network error once at once, as browsers do for GETs.
 let response;try{response=await fetch(path,{...options,cache:'no-store',signal:control.signal});}catch(error){if(!(error instanceof TypeError)||control.signal.aborted)throw error;response=await fetch(path,{...options,cache:'no-store',signal:control.signal});}if(!response.ok){const e=Error('HTTP '+response.status+' from '+path.split('?')[0]);e.status=response.status;throw e;}const result=await response.json();lastSuccessAt=Date.now();return result;}finally{clearTimeout(timeout);}}
async function api(path,options={}){if(!token)throw Error('Waiting for the phone connection.');const activeSession=session,credential=token;try{const result=await raw(path+'?token='+encodeURIComponent(credential),options);if(activeSession!==session)throw new DOMException('Session replaced','AbortError');return result;}catch(error){if(error.status===403&&activeSession===session){mediaClear();connectionLost('Phone authorization changed. Reconnecting automatically.');}throw error;}}
function mediaClear(){mediaGeneration++;if(player?.performanceProfile)previousPlaybackProfile=player.performanceProfile();player?.destroy();const canvas=$('mediaCanvas');canvas.getContext?.('2d')?.clearRect(0,0,canvas.width,canvas.height);player=null;mediaEpoch='';command=-1;mediaCover.hidden=false;mediaCover.textContent='Waiting for YouTube AirPlay.';setIdleArtwork(true);}
function connectionLost(message){sourceState=null;if(player)resumeConnection={epoch:mediaEpoch,position:player.currentTime};connected=false;previousToken=token||previousToken;saveCredential();token='';session++;reconnections++;clearTimeout(tickTimer);const oldSocket=ws;ws=null;oldSocket?.close();clearTimeout(wsTimer);hideLocal('Connection lost. Hide is NOT confirmed on the phone.');connectionNotice('reconnecting',message);}
async function connect(){if(joining||connected)return;joining=true;stopped=false;const attempt=++joinGeneration;try{
 if(!isSecureContext||typeof VideoDecoder!=='function')throw Error('This player needs HTTPS and browser WebCodecs support. Keep the HTTP fallback available.');
 if(!nonce)try{nonce=sessionStorage.getItem('screenlink-local-nonce')||'';}catch{}if(!/^[0-9a-f]{32}$/.test(nonce)){nonce=Array.from(crypto.getRandomValues(new Uint8Array(16)),x=>x.toString(16).padStart(2,'0')).join('');try{sessionStorage.setItem('screenlink-local-nonce',nonce);}catch{}}
 connectionNotice('connecting','Connecting to your phone over HTTPS…');
 const deadline=Date.now()+120000;
 while(!stopped&&Date.now()<deadline){const next=await raw('/local-viewer/request',{method:'POST',headers:{'Content-Type':'application/json','X-ScreenLink-Viewer':'request'},body:JSON.stringify({nonce,previousToken})});
  if(stopped||attempt!==joinGeneration)return;
  approvalPhase=next.phase||'unknown';
  if(next.phase==='approved'&&typeof next.token==='string'&&next.token.length){const changed=previousToken!==next.token;if(player&&(changed||player.closed))mediaClear();token=next.token;previousToken=token;saveCredential();session++;polling=false;privacyPending=false;$('hide').disabled=false;$('show').disabled=youtubeOnly;connected=true;healthFailures=0;lastProgressAt=Date.now();lastDrawn=0;screen.destroy();screen=new ScreenLinkScreen.CanvasScreen($('mapCanvas'),{onstate:screenState,onerror:screenError});minRevision=0;screenFault=false;pendingPacket=null;wsAttempt=0;if(!player)mediaFailed=false;connectionNotice('connected','Phone connected · local HTTPS');if(youtubeOnly)await privacy(true);else openSocket();tick();return;}
  // An explicit authorization result differs from a transient network outage.
  // Do not keep displaying private buffered media after approval is withdrawn.
  if(player)mediaClear();
  if(next.phase==='busy')connectionNotice('busy','Phone reached. Another browser is approved. In ScreenLink → Developer, disconnect local viewer, then approve this viewer.');
  else if(next.phase==='pending')connectionNotice('pending','Phone reached. In ScreenLink → Developer, tap Approve local viewer. No screen recording is needed.');
  else if(['rejected','invalid'].includes(next.phase)){const error=Error('Phone approval: '+next.phase);error.approval=next.phase;throw error;}
  await new Promise(r=>setTimeout(r,1200));}
 if(!stopped)throw Error('Approval timed out. Waiting for automatic reconnection.');
 }catch(error){if(stopped||attempt!==joinGeneration)return;lastConnectionError={message:error.message||String(error),time:Date.now(),httpStatus:error.status||0,approval:approvalPhase};connectionNotice(error.approval||'offline',error.approval?'Phone declined approval. Approve this viewer in ScreenLink.':'HTTPS connection unavailable. Retrying automatically; buffered video is retained.');}finally{if(attempt===joinGeneration)joining=false;}}
function openSocket(){if(!connected||stopped||youtubeOnly)return;clearTimeout(wsTimer);pendingPacket=null;wsWork=Promise.resolve();const socket=new WebSocket(location.origin.replace(/^http/,'ws')+'/stream?token='+encodeURIComponent(token));socket.binaryType='arraybuffer';ws=socket;
 socket.onopen=()=>{$('mapDetail').textContent='Local WSS connected; capture remains hidden until Show.';wsAttempt=0;};
 socket.onmessage=event=>{wsWork=wsWork.then(async()=>{if(ws!==socket||!connected)return;
  if(typeof event.data==='string'){if(event.data.length>4096)throw Error('Screen metadata too large');const meta=JSON.parse(event.data);if(!['state','init','data'].includes(meta.kind)||!Number.isInteger(meta.bytes)||meta.bytes<0||meta.bytes>2*1024*1024)throw Error('Invalid screen metadata');if(pendingPacket)throw Error('Screen packet incomplete');if(meta.bytes){pendingPacket=meta;screen.state(meta);}else{screen.state(meta);await new Promise(r=>setTimeout(r,200));if(socket.readyState===WebSocket.OPEN)socket.send('next');}}
  else{const meta=pendingPacket;pendingPacket=null;if(!meta||event.data.byteLength!==meta.bytes)throw Error('Screen payload size mismatch');await screen.packet(meta,event.data);if(socket.readyState===WebSocket.OPEN&&ws===socket)socket.send('next');}
 }).catch(error=>{if(ws===socket)screenError(error);});};
 socket.onerror=()=>{$('mapDetail').textContent='Secure screen connection interrupted.';};
 socket.onclose=()=>{if(ws!==socket)return;ws=null;pendingPacket=null;hideLocal('Screen connection lost. Hide is NOT confirmed on phone.');if(connected&&!stopped&&!screenFault)wsTimer=setTimeout(openSocket,Math.min(10000,500*Math.pow(2,Math.min(wsAttempt++,4))));};}
async function privacy(hidden){const activeSession=session;if(privacyPending||(!hidden&&youtubeOnly))return false;if(!hidden)screenFault=false;privacyPending=true;$('hide').disabled=true;$('show').disabled=true;if(hidden)hideLocal('Hiding… wait for phone confirmation.');try{const meta=await api('/screen/privacy',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({hidden,expectedRevision:minRevision})});minRevision=Math.max(minRevision,Number(meta.privacyRevision)||0);screen.privacy(meta,!hidden);if(hidden)screenState({...meta,confirmed:true});else{mapCover.hidden=false;mapCover.textContent='Waiting for a fresh screen frame…';if(!ws)openSocket();}return true;}catch(error){if(activeSession!==session)return false;hideLocal('Change NOT confirmed. Keep Maps open or stop broadcast.');$('mapDetail').textContent=error.message;return false;}finally{if(activeSession===session){privacyPending=false;$('hide').disabled=false;$('show').disabled=youtubeOnly;}}}
function playbackFault(error,direct){if(player!==direct)return;if(error?.name==='AbortError')return;if(error.kind==='transport'){transportWaiting=true;lastPlaybackError={message:error.message,kind:'transport',position:direct.currentTime,time:Date.now()};$('mediaDetail').textContent='Waiting for phone/media connection. Buffered playback is retained.';return;}stablePlaybackSince=0;decoderFaults++;retryPosition=direct.currentTime||retryPosition;lastPlaybackError={message:String(error.message||error),name:error.name||'Error',position:retryPosition,time:Date.now(),stats:{...direct.stats},profile:direct.performanceProfile?.()};mediaFailed=true;retryAt=Date.now()+Math.min(10000,2000*Math.pow(2,retryCount));direct.destroy();mediaCover.hidden=false;mediaCover.textContent='Recovering playback…';$('mediaDetail').textContent=lastPlaybackError.message;}
async function startMedia(next,resume=0){mediaStartAt=Date.now();mediaStartLogged=false;transportWaiting=false;mediaClear();setIdleArtwork(false);mediaFailed=false;mediaEpoch=next.epoch;const generation=mediaGeneration;const browserReady=!!self.ScreenLinkBrowserVideo?.BrowserVideoPlayer.supported(),codecReady=ScreenLinkCanvas.CanvasPlayer.supported();
 activeEngine=requestedEngine==='browser'&&browserReady?'browser':codecReady?'webcodecs':browserReady?'browser':'';
 if(!activeEngine){mediaFailed=true;mediaCover.textContent='This browser cannot play the YouTube video.';return;}
 const Engine=activeEngine==='browser'?ScreenLinkBrowserVideo.BrowserVideoPlayer:ScreenLinkCanvas.CanvasPlayer;
 const direct=new Engine($('mediaCanvas'),{quality:$('quality').value,audioContext,bufferSeconds:1,decoderPreference:requestedDecoder,onerror:error=>playbackFault(error,direct)});player=direct;
 try{await direct.load(next.url,resume||(next.start||0));if(generation!==mediaGeneration||!connected){direct.destroy();return;}if(next.fraction>0&&!resume&&!next.start)direct.currentTime=next.fraction*direct.duration;if(soundWanted&&audioContext?.state==='running'){await direct.enableAudio();applyPhoneAudio();}if(next.paused)direct.pause();else await direct.play();
 // Autoplay is attempted without blocking connection or video startup.
 if(!soundWanted){if(!audioContext)audioContext=new AudioContext({sampleRate:direct.lastAudioSampleRate||44100});audioContext.resume().then(async()=>{if(generation!==mediaGeneration||player!==direct||soundWanted||audioContext.state!=='running')return;soundWanted=true;await direct.enableAudio(audioContext);applyPhoneAudio();$('sound').textContent='Sound enabled';refreshSoundPrompt();}).catch(()=>{});}
 }
 catch(error){if(player===direct)playbackFault(error,direct);}
}
async function tick(){if(polling)return;polling=true;const activeSession=session;try{if(!connected)return;const drawn=(player?.stats.drawn||0)+screen.framesDrawn;if(drawn!==lastDrawn){lastProgressAt=Date.now();lastDrawn=drawn;}const next=await api('/media/state');sourceState=next;const phoneQualityChanged=readPhoneControls(next);lockedView=!!next.screenLocked;refreshInline('viewMode');if(lockedView&&!youtubeOnly)await setViewerMode('youtube');healthFailures=0;lastHealthyAt=Date.now();connectionNotice('connected','Phone connected · local HTTPS');
 if(!next.active){if(mediaEpoch)mediaClear();$('mediaDetail').textContent=next.error||'Select ScreenLink VPN Phone in YouTube AirPlay.';}
 else{if(phoneQualityChanged&&player&&next.epoch===mediaEpoch)await startMedia(next,player.currentTime);if(transportWaiting&&player&&(!player.running||player.videoEnd-player.currentTime<.12)){retryPosition=player.currentTime;await startMedia(next,retryPosition);}if(next.epoch!==mediaEpoch){retryCount=0;await startMedia(next,resumeConnection?.epoch===next.epoch?resumeConnection.position:0);resumeConnection=null;}else if(mediaFailed&&Date.now()>=retryAt){retryCount++;await startMedia(next,retryPosition);}if(!connected)return;
  if(next.command!==command&&player){command=next.command;if(next.commandKind==='seek')player.currentTime=next.seek;if(next.paused)player.pause();else await player.play();}
  await applyPhonePlayback(next);applyPhoneAudio();refreshSoundPrompt();
  const p=player;if(p&&!mediaFailed){
   const progressing=p.running&&!p.paused&&p.currentTime>stableMediaTime+.1&&p.stats.drawn>stableDrawn;
   if(progressing){if(!stablePlaybackSince)stablePlaybackSince=Date.now();if(Date.now()-stablePlaybackSince>=20000)retryCount=0;}else stablePlaybackSince=0;
   stableMediaTime=p.currentTime;stableDrawn=p.stats.drawn;mediaCover.hidden=p.stats.drawn>0&&!mediaFailed;if(!mediaCover.hidden&&!mediaFailed)mediaCover.textContent='Loading original video…';$('mediaDetail').textContent=(mediaFailed?p.error?.message||'Decoder stopped':p.paused?'Paused':(activeEngine==='browser'?'Browser video + Web Audio':'WebCodecs + Web Audio'))+' · '+$('mediaCanvas').width+' × '+$('mediaCanvas').height+' · '+p.stats.drawn+' frames';$('seek').value=p.duration?100*p.currentTime/p.duration:0;
   collectCarLog(p);if(!reportPending){reportPending=true;const carLog=carLogQueue;carLogQueue=[];api('/media/report',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({carLog,epoch:mediaEpoch,command,viewerPlaybackRevision:phonePlaybackRevision,viewerControlRevision:phoneSettingsRevision,position:p.currentTime,duration:p.duration,paused:p.paused,ready:p.readyState>=2&&!p.error,ended:p.ended,error:retryCount>=3?(p.error?.message||''):''})}).catch(()=>{carLogQueue=carLog.concat(carLogQueue).slice(-6);}).finally(()=>{reportPending=false;});}}
 }
 }catch(error){if(connected&&activeSession===session){healthFailures++;lastConnectionError={message:error.message,time:Date.now(),failures:healthFailures};if(healthFailures>=3){const drawn=(player?.stats.drawn||0)+screen.framesDrawn;if(drawn!==lastDrawn){lastProgressAt=Date.now();lastDrawn=drawn;}/* Build 97: stay quiet while the picture keeps moving from saved video; warn only when it stops. */if(Date.now()-lastProgressAt>=4000)connectionNotice('reconnecting','HTTPS interrupted. Buffered playback is retained; retrying the phone.');if(Date.now()-lastProgressAt>=8000)connectionLost('Phone receiver unavailable. Reconnecting automatically when it returns.');}}}finally{if(activeSession!==session)return;polling=false;refreshSoundPrompt();renderPerformance();if(connected&&!stopped){clearTimeout(tickTimer);tickTimer=setTimeout(tick,1000);}}}
$('hide').onclick=()=>privacy(true);$('show').onclick=()=>privacy(false);
$('sound').onclick=async()=>{if(youtubeOnly&&!developerMode)document.documentElement.requestFullscreen?.().catch(()=>{});try{if(!audioContext)audioContext=new AudioContext({sampleRate:player?.lastAudioSampleRate||44100});await audioContext.resume();soundWanted=true;if(player){await player.enableAudio(audioContext);applyPhoneAudio();}$('sound').textContent='Sound enabled';refreshSoundPrompt();}catch(error){$('mediaDetail').textContent=error.message;}};
$('pause').onclick=()=>{if(player)player.paused?player.play():player.pause();};$('seek').onchange=e=>{if(player?.duration)player.currentTime=Number(e.target.value)*player.duration/100;};
$('mediaRetry').onclick=()=>{retryCount=0;if(connected&&sourceState?.active)startMedia(sourceState,player?.currentTime||0);};$('quality').onchange=$('mediaRetry').onclick;$('eq').onchange=()=>player?.setEQ($('eq').value);
$('full').onclick=()=>document.documentElement.requestFullscreen?.().catch(()=>{});
const videoStage=$('mediaStage'),exitVideo=$('exitVideoFull');let fullControlsTimer=0;
function showVideoControls(){
 videoStage.classList.remove('full-controls-hidden');clearTimeout(fullControlsTimer);
 if(videoStage.classList.contains('video-fullscreen'))fullControlsTimer=setTimeout(()=>videoStage.classList.add('full-controls-hidden'),2500);
}
async function exitVideoFullscreen(){
 clearTimeout(fullControlsTimer);videoStage.classList.remove('video-fullscreen','full-controls-hidden');exitVideo.hidden=true;
 if(document.fullscreenElement===videoStage)try{await document.exitFullscreen();}catch{}
}
$('videoFull').onclick=async()=>{
 videoStage.classList.add('video-fullscreen');exitVideo.hidden=false;showVideoControls();
 // Keep the CSS fallback when this browser does not expose the Fullscreen API.
 try{await videoStage.requestFullscreen?.();}catch{}
};
exitVideo.onclick=event=>{event.stopPropagation();exitVideoFullscreen();};
videoStage.addEventListener('pointerdown',showVideoControls);
document.addEventListener('keydown',event=>{if(event.key==='Escape')exitVideoFullscreen();});
document.addEventListener('fullscreenchange',()=>{if(!document.fullscreenElement)exitVideoFullscreen();});

const panels=$('panels'),divider=$('divider');let split=50,stacked=matchMedia('(orientation:portrait)').matches;try{const saved=JSON.parse(localStorage.getItem('screenlink-canvas-layout'));if(saved){split=saved.split||50;stacked=!!saved.stacked;}}catch{}
function layout(){split=Math.min(80,Math.max(20,split));panels.style.setProperty('--split',split+'%');panels.classList.toggle('stacked',stacked);divider.setAttribute('aria-valuenow',Math.round(split));divider.setAttribute('aria-orientation',stacked?'horizontal':'vertical');$('layout').textContent=stacked?'Side by side':'Stack panels';try{localStorage.setItem('screenlink-canvas-layout',JSON.stringify({split,stacked}));}catch{}}
function viewLayout(){document.body.classList.toggle('minimal-viewer',youtubeOnly&&!developerMode);if($('modeHint'))$('modeHint').textContent=youtubeOnly?'YouTube · no screen recording':'Maps screen sharing + YouTube';document.body.classList.toggle('youtube-only',youtubeOnly);$('viewMode').value=youtubeOnly?'youtube':'split';$('show').disabled=youtubeOnly;refreshInline('viewMode');}
function closeScreenSocket(){clearTimeout(wsTimer);const socket=ws;ws=null;pendingPacket=null;socket?.close();screen.hide();}
async function setViewerMode(value){
 if(modeBusy||privacyPending){$('viewMode').value=youtubeOnly?'youtube':'split';return;}
 modeBusy=true;$('viewMode').disabled=true;youtubeOnly=value==='youtube';viewLayout();closeScreenSocket();hideLocal('Screen hidden locally; waiting for phone confirmation.');
 try{try{localStorage.setItem('screenlink-canvas-view',youtubeOnly?'youtube':'split');}catch{}try{history.replaceState(null,'',youtubeOnly?'/video':'/split');}catch{}
  if(connected){const hidden=await privacy(true);if(!hidden)status.textContent='Screen hide NOT confirmed. Press Hide screen again or stop sharing on the phone.';if(!youtubeOnly)openSocket();}
 }finally{modeBusy=false;$('viewMode').disabled=false;}
}
try{youtubeOnly=location.pathname==='/video'||(!developerMode&&!['/split','/map'].includes(location.pathname))||(location.pathname!=='/split'&&localStorage.getItem('screenlink-canvas-view')==='youtube');}catch{youtubeOnly=location.pathname==='/video';}viewLayout();$('viewMode').onchange=()=>setViewerMode($('viewMode').value);
function move(e){const r=panels.getBoundingClientRect();split=100*(stacked?(e.clientY-r.top)/r.height:(e.clientX-r.left)/r.width);layout();}divider.onpointerdown=e=>{e.preventDefault();divider.setPointerCapture(e.pointerId);move(e);};divider.onpointermove=e=>{if(divider.hasPointerCapture(e.pointerId))move(e);};divider.onkeydown=e=>{if(['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','Home','End'].includes(e.key)){e.preventDefault();split=e.key==='Home'?20:e.key==='End'?80:split+(['ArrowLeft','ArrowUp'].includes(e.key)?-2:2);layout();}};$('reset').onclick=()=>{split=50;layout();};$('layout').onclick=()=>{stacked=!stacked;layout();};layout();
window.addEventListener('online',()=>{if(connected){tick();if(!ws)openSocket();}else connect();});window.addEventListener('pagehide',()=>{clearTimeout(reconnectTimer);clearTimeout(tickTimer);joinGeneration++;joining=false;previousToken=token||previousToken;saveCredential();token='';session++;stopped=true;connected=false;sourceState=null;polling=false;privacyPending=false;clearTimeout(wsTimer);const oldSocket=ws;ws=null;oldSocket?.close();screen.destroy();mediaClear();setIdleArtwork(false);audioContext?.close();audioContext=null;soundWanted=false;});
// Tesla can restore the page from its back/forward cache without running this script again.
// Resume discovery with a fresh decoder and credential handshake, never a dead socket.
window.addEventListener('pageshow',event=>{if(!event.persisted)return;setIdleArtwork(true);stopped=false;screen=new ScreenLinkScreen.CanvasScreen($('mapCanvas'),{onstate:screenState,onerror:screenError});minRevision=0;screenFault=false;pendingPacket=null;modeBusy=false;$('viewMode').disabled=false;$('hide').disabled=false;$('show').disabled=youtubeOnly;status.textContent='Reconnecting to ScreenLink…';clearTimeout(reconnectTimer);autoConnect();});
function renderPerformance(){
 if(performanceFrozen||$('performancePanel').hidden)return;
 const profile=player?.performanceProfile?.()||previousPlaybackProfile;
 const lines=['Build: 0.20.65 / 102 · '+(activeEngine||requestedEngine)+' · '+(player?.videoAcceleration||requestedDecoder),'Playback: '+(player?.currentTime||0).toFixed(2)+' s','Page: '+(profile?.visibility||document.visibilityState||'unknown'),''];
 const names=[['demuxMs','Demux ms'],['decoderWaitMs','Decoder feed wait ms'],['renderCallbackGapMs','Drawing callback gap ms'],['canvasDrawMs','Canvas draw call ms'],['videoQueueDepth','Pending decode requests']];
 for(const [key,label] of names){const m=profile?.metrics[key];lines.push(label+': '+(m?'mean '+m.mean.toFixed(2)+' | max '+m.max.toFixed(2)+' | n '+m.count:'no samples'));if(m)lines.push('  max at '+(m.maxAtMs/1000).toFixed(2)+'s, media '+m.mediaTime.toFixed(2)+'s');}
 lines.push('','Decode queue now: '+(profile?.videoQueueDepth||0),'Decoded frames queued: '+(profile?.framesQueued||0),'Video recoveries: '+(player?.stats.videoRecoveries||0),'Audio buffer underruns: '+(player?.stats.audioUnderruns||0));
 $('performanceText').textContent=lines.join('\n');
}
$('showPerformance').onclick=()=>{$('performancePanel').hidden=false;performanceFrozen=false;$('freezePerformance').textContent='Freeze report';renderPerformance();};
$('freezePerformance').onclick=()=>{performanceFrozen=!performanceFrozen;$('freezePerformance').textContent=performanceFrozen?'Resume report':'Freeze report';if(!performanceFrozen)renderPerformance();};
$('closePerformance').onclick=()=>{$('performancePanel').hidden=true;};
$('copyPlayback').onclick=async()=>{const text=JSON.stringify(self.ScreenLinkCanvasStatus(),null,2);try{await navigator.clipboard.writeText(text);$('copyPlayback').textContent='Diagnostics copied';}catch{const box=$('playbackDiagnostics');box.hidden=false;box.value=text;box.focus();box.select();}};
// Build 97: keep a rescue copy of this page (App/CanvasServiceWorker.js, network first), so a
// reload during a failed name lookup shows this page and reconnects instead of the browser's
// "server IP address could not be found" page. Also removes the old build 64 offline cache.
async function retireOfflineUI(){
 if(!isSecureContext||!('serviceWorker' in navigator))return;
 try{
  for(const name of await caches.keys())if(name.startsWith('screenlink-canvas-ui-'))await caches.delete(name);
  await navigator.serviceWorker.register('/sw.js',{scope:'/'});
 }catch(error){lastConnectionError={message:'Rescue page setup: '+error.message,time:Date.now()};}
}
retireOfflineUI();
self.ScreenLinkCanvasStatus=()=>({build:'0.20.65-102',engine:activeEngine||requestedEngine,videoDecoder:player?.videoAcceleration||null,connectionPhase,approvalPhase,phoneVolume,phoneEQ,phoneSettingsRevision,phonePlaybackRevision,volumeGain:player?.gain?.gain.value??null,eqLowGain:player?.low?.gain.value??null,minimalViewer:youtubeOnly&&!developerMode,lastRequestAt,lastSuccessAt,offlineUI:false,healthFailures,lastHealthyAt,reconnections,quality:$('quality').value,transportWaiting,decoderFaults,transportError:player?.lastTransportError||null,lastPlaybackError,lastConnectionError,recoveryAttempts:retryCount,mediaRunning:player?.running||false,mediaDuration:player?.duration||0,videoFramesQueued:player?.frames.length||0,audioPacketsQueued:player?.audio.length||0,secureContext:isSecureContext,connected,connectionPending:joining,viewerMode:youtubeOnly?'youtube':'split',screenFrames:screen.framesDrawn,screenHidden:screen.hold,screenQueue:screen.decoder?.decodeQueueSize||0,mediaEpoch,mediaPosition:player?.currentTime||0,mediaPaused:player?.paused??true,mediaWidth:$('mediaCanvas').width,mediaHeight:$('mediaCanvas').height,youtubeBufferSeconds:player?.bufferSeconds||0,encodedVideoLead:player?Math.max(0,player.preparedVideoEnd-player.currentTime):0,mediaStats:player?{...player.stats}:null,performance:player?.performanceProfile?.()||null,previousPlaybackProfile,playbackEvents:player?(player.playbackEvents||[]).map(e=>({...e})):[],segmentCache:player?.segmentCache?.size||0,audioSampleRate:player?.audioContext?.sampleRate||0,decodedAudioRate:player?.lastAudioSampleRate||player?.audio[0]?.sampleRate||0,segments:player?(player.segmentDiagnostics||[]).map(s=>({...s})):[],audioLead:player?.audioContext&&player.audioTail!==null?Math.max(0,player.audioTail-player.audioContext.currentTime):0,videoLead:player?Math.max(0,player.videoEnd-player.currentTime):0,audioState:audioContext?.state||'locked',audioNodes:player?.nodes.size||0,mediaError:player?.error?.message||'',socketOpen:ws?.readyState===WebSocket.OPEN});
for(const id of ['viewMode','quality','eq'])makeInline(id);
function autoConnect(){if(!stopped&&!connected&&!joining)connect();if(!stopped)reconnectTimer=setTimeout(autoConnect,3000);}if(isSecureContext&&typeof VideoDecoder==='function')autoConnect();
if(!isSecureContext||typeof VideoDecoder!=='function')status.textContent='This viewer needs HTTPS and WebCodecs support.';
// Build 87: small navigation map (ScreenLink Maps) beside the video for the rear-seat screen.
// Pictures and directions come from the phone at /map/* with the same approval token as the video.
// Only page layout changes; the video player itself is untouched.
let mapLive=false,mapStateTimer=0,mapFrameTimer=0,mapBgState=null,mapBgShown=-1,mapBgMeta=null,mapHeading=null;
// Car Maps' web-mercator placement, scaled to the small map window.
function mapWorld(lat,lng,z){const s=512*Math.pow(2,z),si=Math.sin(lat*Math.PI/180);return [(lng+180)/360*s,(0.5-Math.log((1+si)/(1-si))/(4*Math.PI))*s];}
function placeMapBg(s){
 if(s.bgId!==mapBgShown){mapBgShown=s.bgId;const meta={lat:s.bgLat,lng:s.bgLng,z:s.bgZoom},im=new Image();
  im.onload=()=>{const img=$('mapBgImg');img.style.transition='none';img.src=im.src;mapBgMeta=meta;placeMapBg(mapBgState||s);void img.offsetWidth;img.style.transition='';};
  im.src='/map/bg.jpg?token='+encodeURIComponent(token)+'&id='+s.bgId;}
 if(!mapBgMeta||!s.lat)return;
 const box=$('mapMini').getBoundingClientRect(),drive=s.screen==='drive',k=(drive?2.2:1.5)*Math.max(.3,Math.min(1,box.width/1600));
 const c=mapWorld(s.lat,s.lng,mapBgMeta.z),o=mapWorld(mapBgMeta.lat,mapBgMeta.lng,mapBgMeta.z),px=640+(c[0]-o[0]),py=640+(c[1]-o[1]);
 const ax=box.width/2,ay=drive?box.height*.72:box.height/2,h=s.heading||0;
 if(mapHeading===null)mapHeading=h;else mapHeading+=((h-(mapHeading%360)+540)%360)-180;
 const img=$('mapBgImg');img.style.width=1280*k+'px';img.style.height=1280*k+'px';img.style.left=(ax-px*k)+'px';img.style.top=(ay-py*k)+'px';
 img.style.transformOrigin=(px*k)+'px '+(py*k)+'px';img.style.transform=drive?'rotateX(55deg) rotate('+(-mapHeading)+'deg)':'none';
 $('mapBg').style.perspectiveOrigin=ax+'px '+ay+'px';const car=$('mapBgCar');car.style.left=ax+'px';car.style.top=ay+'px';
}
window.addEventListener('resize',()=>{if(mapBgState&&!$('mapBg').hidden)placeMapBg(mapBgState);});
// Build 98: the car draws the map itself (Google Maps JavaScript) from the phone's GPS and route.
// The phone only sends small data, so the map keeps working when ScreenLink is in the background
// or the iPhone is locked. If Google refuses the key, the old picture modes are used instead.
let jsMap=null,jsMapState='off',jsMapKey='',jsMarker=null,jsHalo=null,jsRoute=null,jsRouteEdge=null,jsDest=null,jsTraffic=null,jsRouteId='',jsReportAt=0,jsFailReason='',jsNight=null,jsType='',jsPose=null,jsGoal=null,jsGlide=0,jsIconKey='',jsArrow='';
function decodePolyline(text){const out=[];let i=0,lat=0,lng=0;while(i<text.length){for(const axis of [0,1]){let shift=0,result=0,b;do{b=text.charCodeAt(i++)-63;result|=(b&31)<<shift;shift+=5;}while(b>=32&&i<=text.length);const d=result&1?~(result>>1):result>>1;if(axis)lng+=d;else lat+=d;}out.push({lat:lat/1e5,lng:lng/1e5});}return out;}
function reportCarMap(ok,why){if(!connected||!token)return;jsReportAt=Date.now();raw('/map/cmd?token='+encodeURIComponent(token)+'&a=carmap&ok='+(ok?1:0)+(why?'&why='+encodeURIComponent(String(why).slice(0,60)):'')).catch(()=>{});}
// Build 99: the car map looks like Google Maps navigation. Real Google day/night colours, live
// traffic, a 3D view that turns with the car (vector map), the car in the lower part of the map,
// a blue route with a dark edge, a red destination pin and a smooth glide between GPS points.
// Google's night colours can only be chosen when a map is created, so the map is rebuilt on day/night.
function buildCarMap(){
 const g=google.maps,s=mapBgState||{},night=!!s.night,box=$('mapJs');
 for(const old of [jsMarker,jsHalo,jsRoute,jsRouteEdge,jsDest,jsTraffic])old?.setMap?.(null);clearInterval(jsGlide);jsGlide=0;box.textContent='';
 const options={center:{lat:s.lat||11.56,lng:s.lng||104.92},zoom:16,disableDefaultUI:true,gestureHandling:'none',keyboardShortcuts:false,clickableIcons:false,isFractionalZoomEnabled:true,backgroundColor:night?'#1d2430':'#e5e3df'};
 if(g.RenderingType)options.renderingType=g.RenderingType.VECTOR;
 if(g.ColorScheme)options.colorScheme=night?g.ColorScheme.DARK:g.ColorScheme.LIGHT;
 else if(night)options.styles=[{elementType:'geometry',stylers:[{color:'#1d2430'}]},{elementType:'labels.text.fill',stylers:[{color:'#9aa6b8'}]},{elementType:'labels.text.stroke',stylers:[{color:'#11161e'}]},{featureType:'road',elementType:'geometry',stylers:[{color:'#323c4c'}]},{featureType:'water',elementType:'geometry',stylers:[{color:'#0e1a2b'}]}];
 jsMap=new g.Map(box,options);jsNight=night;jsType='';jsRouteId='';jsIconKey='';
 if(g.TrafficLayer){jsTraffic=new g.TrafficLayer();jsTraffic.setMap(jsMap);}
 jsRouteEdge=new g.Polyline({map:jsMap,path:[],strokeColor:night?'#0b3d91':'#1557b0',strokeOpacity:1,strokeWeight:11,clickable:false,zIndex:1});
 jsRoute=new g.Polyline({map:jsMap,path:[],strokeColor:night?'#669df6':'#1a73e8',strokeOpacity:1,strokeWeight:7,clickable:false,zIndex:2});
 jsDest=new g.Marker({position:jsMap.getCenter(),clickable:false,zIndex:3});
 jsHalo=new g.Marker({map:jsMap,position:jsMap.getCenter(),clickable:false,zIndex:4,icon:{path:g.SymbolPath.CIRCLE,scale:22,fillColor:'#1a73e8',fillOpacity:.18,strokeOpacity:0,strokeWeight:0}});
 jsMarker=new g.Marker({map:jsMap,position:jsMap.getCenter(),clickable:false,zIndex:5});
 $('mapMini').classList.toggle('map-night',night);
 jsPath=[];jsPlaceKey='';jsFitKey='';
 jsMap.addListener?.('dragstart',carMapFree);
 // Tap a place name or icon on the map: open that place on the phone by its Google id.
 jsMap.addListener?.('click',event=>{if(event?.placeId){event.stop?.();mapSearchOpen=false;mapCmd('poi',{id:event.placeId});}else if(mapSearchOpen){mapSearchOpen=false;$('mapQuery').blur();renderMapUi(mapBgState,jsLive());}});
 applyCarMapMode();
}
function loadCarMap(key){
 if(jsMapState!=='off'&&key===jsMapKey)return;jsMapKey=key;jsMapState='loading';
 window.gm_authFailure=()=>{jsMapState='failed';jsFailReason='Google refused the key for this website';clearInterval(jsGlide);jsGlide=0;$('mapJs').hidden=true;reportCarMap(false,jsFailReason);};
 window.__slCarMapReady=()=>{try{
  buildCarMap();jsMapState='ready';reportCarMap(true);if(mapBgState)updateCarMap(mapBgState);
 }catch(error){jsMapState='failed';jsFailReason='map start failed: '+error.message;reportCarMap(false,jsFailReason);}};
 const script=document.createElement('script');script.async=true;
 script.src='https://maps.googleapis.com/maps/api/js?key='+encodeURIComponent(key)+'&v=weekly&loading=async&callback=__slCarMapReady';
 script.onerror=()=>{jsMapState='failed';jsFailReason='Google Maps could not load (car internet)';reportCarMap(false,jsFailReason);};
 document.head.appendChild(script);
}
// One picture of the map for a car position. While driving on a vector map: tilted, travel
// direction up, and the car below the middle so more of the road ahead is seen (like Google).
function carMapFrame(p){
 if(jsMapState!=='ready'||!jsMap)return;
 const g=google.maps,s=mapBgState||{},drive=s.screen==='drive'||!!s.navigating;
 const vector=!!g.RenderingType&&jsMap.getRenderingType?.()===g.RenderingType.VECTOR;
 const mapHeading=vector&&drive&&s.headingUp!==false?p.heading:0,tilt=vector&&drive?55:0,zoom=drive?(vector?17.5:17):15;
 const here={lat:p.lat,lng:p.lng};let center=here;
 if(drive){
  const cos=Math.max(.01,Math.cos(p.lat*Math.PI/180)),ahead=($('mapJs').clientHeight||300)*(tilt?.26:.2)*156543.03392*cos/Math.pow(2,zoom),a=p.heading*Math.PI/180;
  center={lat:p.lat+ahead*Math.cos(a)/111320,lng:p.lng+ahead*Math.sin(a)/(111320*cos)};
 }
 if(jsFollow){if(jsMap.moveCamera)jsMap.moveCamera({center,zoom,heading:mapHeading,tilt});else{if(jsMap.getZoom()!==zoom)jsMap.setZoom(zoom);jsMap.setCenter(center);}}
 const shown=jsFollow?mapHeading:Number(jsMap.getHeading?.())||0;
 jsMarker.setPosition(here);jsHalo.setPosition(here);
 const big=document.body.classList.contains('map-big'),turn=Math.round(((p.heading-shown)%360+360)%360),key=turn+(big?'b':'s');
 if(key!==jsIconKey){jsIconKey=key;jsMarker.setIcon({path:'M0,-13 L10,11 L0,6 L-10,11 Z',scale:big?1.7:1.15,rotation:turn,fillColor:'#1a73e8',fillOpacity:1,strokeColor:'#ffffff',strokeWeight:big?3.5:2.5});}
}
function updateCarMap(s){
 if(jsMapState!=='ready'||!jsMap||!s.lat)return;
 // Google can also show its own grey error box instead of a map (key not allowed, API off).
 if($('mapJs').querySelector('.gm-err-container')){window.gm_authFailure();return;}
 if(!!s.night!==jsNight){try{buildCarMap();}catch(error){jsMapState='failed';jsFailReason='map start failed: '+error.message;reportCarMap(false,jsFailReason);return;}}
 const type=s.mapType==='satellite'?'hybrid':'roadmap';if(type!==jsType){jsType=type;jsMap.setMapTypeId?.(type);}
 const id=String(s.routeId??'')+':'+String(s.routeLine||'').length;
 const g=google.maps,drive=s.screen==='drive'||!!s.navigating,place=s.place&&Number(s.place.lat)?s.place:null,placeKey=place?place.lat+','+place.lng+'|'+place.name:'',routeNew=id!==jsRouteId;
 if(routeNew){jsRouteId=id;jsPath=s.routeLine?decodePolyline(s.routeLine):[];jsRoute.setPath(jsPath);jsRouteEdge.setPath(jsPath);}
 // The chosen place shows its name on the map (red dot + name). A route without a place keeps Google's red pin.
 if(routeNew||placeKey!==jsPlaceKey){jsPlaceKey=placeKey;const end=place?{lat:Number(place.lat),lng:Number(place.lng)}:jsPath.length>1?jsPath[jsPath.length-1]:null;
  if(end){jsDest.setPosition(end);
   if(place){jsDest.setIcon?.({path:g.SymbolPath.CIRCLE,scale:9,fillColor:'#ea4335',fillOpacity:1,strokeColor:'#ffffff',strokeWeight:3,labelOrigin:g.Point?new g.Point(0,2.7):undefined});jsDest.setLabel?.({text:String(place.name||'').slice(0,40),color:jsNight?'#f6aea9':'#c5221f',fontWeight:'700',fontSize:'15px',className:'map-place-label'});}
   else{jsDest.setIcon?.(null);jsDest.setLabel?.(null);}
   jsDest.setMap(jsMap);}else jsDest.setMap(null);}
 // A newly opened place (or its new route) is shown whole; driving or closing it follows the car again.
 if(!drive&&place){const fit=placeKey+'|'+id;if(fit!==jsFitKey){jsFitKey=fit;jsFollow=false;$('mapRecentre').hidden=false;showPlace({lat:Number(place.lat),lng:Number(place.lng)},jsPath);}}
 else if(jsFitKey){jsFitKey='';jsFollow=true;$('mapRecentre').hidden=true;}
 const goal={lat:s.lat,lng:s.lng,heading:Number(s.heading)||0},from=jsPose,moved=from?Math.abs(goal.lat-from.lat)+Math.abs(goal.lng-from.lng):1;
 // The same target as the running glide (a faster poll while searching): let the glide finish.
 if(jsGlide&&jsGoal&&jsGoal.lat===goal.lat&&jsGoal.lng===goal.lng&&jsGoal.heading===goal.heading){if(Date.now()-jsReportAt>10000)reportCarMap(true);return;}
 jsGoal=goal;clearInterval(jsGlide);jsGlide=0;
 // Glide between GPS points (about 14 pictures a second, only while the car moves). Jumps and a
 // hidden page are drawn once, so a parked car costs nothing next to the video.
 if(!from||moved>.003||document.hidden||(moved<1e-7&&Math.abs(goal.heading-from.heading)<.5)){jsPose=goal;carMapFrame(goal);}
 else{const swing=((goal.heading-from.heading+540)%360)-180,start=performance.now();
  jsGlide=setInterval(()=>{const t=Math.min(1,(performance.now()-start)/800);jsPose={lat:from.lat+(goal.lat-from.lat)*t,lng:from.lng+(goal.lng-from.lng)*t,heading:((from.heading+swing*t)%360+360)%360};carMapFrame(jsPose);if(t>=1){clearInterval(jsGlide);jsGlide=0;}},70);}
 if(Date.now()-jsReportAt>10000)reportCarMap(true);
}
// Google-style turn arrows for the green banner (drawn here, no pictures to download).
const MAP_ARROWS={up:'<path d="M12 3 5 10h4.5v11h5V10H19z"/>',right:'<path d="M5 21v-8.5A4.5 4.5 0 0 1 9.5 8H14V4l7 6.5-7 6.5v-4H10v8z"/>',uturn:'<path d="M4 21V10a6.5 6.5 0 0 1 13 0v3h3.5L14.5 20 8.5 13H12v-3a1.5 1.5 0 0 0-3 0v11z"/>',round:'<path d="M12 6a6 6 0 1 0 6 6h-3.5a2.5 2.5 0 1 1-2.5-2.5z"/><path d="M12 1.5 18 7.8l-6 6.2z"/>',pin:'<path d="M12 2a7 7 0 0 0-7 7c0 5 7 13 7 13s7-8 7-13a7 7 0 0 0-7-7zm0 9.5a2.5 2.5 0 1 1 0-5 2.5 2.5 0 0 1 0 5z"/>'};
function mapArrow(maneuver){
 const m=String(maneuver||'');let shape='up',turn='';
 if(m==='ARRIVE')shape='pin';else if(m.startsWith('UTURN'))shape='uturn';else if(m.startsWith('ROUNDABOUT'))shape='round';
 else if(/SLIGHT_LEFT|RAMP_LEFT|FORK_LEFT/.test(m))turn='rotate(-45 12 12)';else if(/SLIGHT_RIGHT|RAMP_RIGHT|FORK_RIGHT/.test(m))turn='rotate(45 12 12)';
 else if(/LEFT/.test(m)){shape='right';turn='translate(24 0) scale(-1 1)';}else if(/RIGHT/.test(m))shape='right';
 return '<svg viewBox="0 0 24 24" aria-hidden="true"><g fill="currentColor" transform="'+turn+'">'+MAP_ARROWS[shape]+'</g></svg>';
}
// Build 100: on the big map the car screen works like the phone: drag, pinch, turn and tilt the
// map, search with suggestions, tap a place name on the map to open that place (its real name,
// not a dropped pin), pick a route and press Start. The phone does the Google searches; the car
// only sends small commands to /map/cmd and reads the answers from /map/state.
let jsReloading=false,jsFollow=true,jsBig=null,jsPath=[],jsPlaceKey='',jsFitKey='',mapFast=0,mapLoopRun=0,mapSearchOpen=false,mapListKey='',mapCardKey='',mapTypeTimer=0,mapQueryPlace='';
function mapCmd(a,params={}){
 if(!connected||!token)return;let url='/map/cmd?token='+encodeURIComponent(token)+'&a='+encodeURIComponent(a);
 for(const [k,v] of Object.entries(params))url+='&'+k+'='+encodeURIComponent(v);
 raw(url).catch(()=>{});mapFast=Date.now()+6000;setTimeout(mapStateLoop,220);
}
const jsLive=()=>jsMapState==='ready'&&!$('mapJs').hidden;
function carMapFree(){if(!document.body.classList.contains('map-big'))return;jsFollow=false;$('mapRecentre').hidden=false;}
function applyCarMapMode(){const big=document.body.classList.contains('map-big');try{jsMap?.setOptions?.({gestureHandling:big?'greedy':'none',clickableIcons:big});}catch{}}
function showPlace(place,path){
 const g=google.maps,box=$('mapJs'),big=document.body.classList.contains('map-big'),at={lat:place.lat,lng:place.lng};
 if(path.length>1&&g.LatLngBounds&&jsMap.fitBounds){
  jsMap.moveCamera?.({heading:0,tilt:0});const b=new g.LatLngBounds();for(const p of path)b.extend(p);b.extend(at);
  jsMap.fitBounds(b,big?{top:100,bottom:70,left:Math.min(640,box.clientWidth*.5),right:Math.min(480,box.clientWidth*.38)}:24);
 }else if(jsMap.moveCamera)jsMap.moveCamera({center:at,zoom:16,heading:0,tilt:0});else{jsMap.setZoom(16);jsMap.setCenter(at);}
}
const MAP_ICONS={search:'M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z',pin:'M12 2a7 7 0 0 0-7 7c0 5 7 13 7 13s7-8 7-13a7 7 0 0 0-7-7zm0 9.5a2.5 2.5 0 1 1 0-5 2.5 2.5 0 0 1 0 5z',clock:'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 5v5.2l4 2.4-1 1.6-5-3V7z',home:'M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z',work:'M20 7h-4V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2H4a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2zm-6 0h-4V5h4z'};
const mapIcon=name=>'<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="'+MAP_ICONS[name]+'"/></svg>';
function mapNode(tag,cls,text){const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;}
function renderMapUi(s,on){
 const big=document.body.classList.contains('map-big'),ui=$('mapUi');
 if(big!==jsBig){jsBig=big;applyCarMapMode();if(!big){jsFollow=true;$('mapRecentre').hidden=true;mapSearchOpen=false;}if(jsPose)carMapFrame(jsPose);}
 ui.hidden=!(on&&big);if(ui.hidden||!s)return;
 const drive=s.screen==='drive'||!!s.navigating,q=$('mapQuery'),text=q.value.trim(),place=!drive&&s.place?s.place:null;
 $('mapMini').classList.toggle('map-drive',drive);$('mapSearch').classList.toggle('open',mapSearchOpen);$('mapExit').hidden=!drive;
 const placeName=place?String(place.name||''):'';
 if(placeName!==mapQueryPlace){mapQueryPlace=placeName;if(document.activeElement!==q)q.value=placeName;}
 $('mapClear').hidden=!q.value&&!(s.results||[]).length;
 // Search list: saved places first, then Google's suggestions while typing, or the search results.
 const rows=[];
 if(!place&&(s.results||[]).length)(s.results||[]).forEach((r,i)=>rows.push({a:'result',i,t:r.name,d:r.address,k:'pin'}));
 else if(mapSearchOpen&&text.length>=2&&text!==placeName)(s.suggestions||[]).forEach(g=>rows.push({a:'suggest',id:g.id,t:g.main,d:g.secondary,k:'pin'}));
 else if(mapSearchOpen&&text.length<2){
  if(s.home)rows.push({a:'home',t:'Home',d:s.home,k:'home'});if(s.work)rows.push({a:'work',t:'Work',d:s.work,k:'work'});
  (s.recents||[]).forEach((r,i)=>rows.push({a:'recent',i,t:r.name,d:r.address,k:'clock'}));
 }
 if(mapSearchOpen&&s.status&&!rows.length)rows.push({t:s.status,d:'',k:'search'});
 const list=$('mapList'),listKey=JSON.stringify(rows);list.hidden=!rows.length;
 if(listKey!==mapListKey){mapListKey=listKey;list.textContent='';
  for(const r of rows){const b=mapNode('button','map-row');b.type='button';if(!r.a)b.disabled=true;b.dataset.a=r.a||'';if(r.i!==undefined)b.dataset.i=r.i;if(r.id)b.dataset.id=r.id;b.dataset.t=r.t||'';
   const ico=mapNode('span','map-row-ico');ico.innerHTML=mapIcon(r.k);const words=mapNode('span','map-row-text');words.append(mapNode('b','',r.t||''),mapNode('span','',r.d||''));b.append(ico,words);list.append(b);}
 }
 // Place card: the real place name, rating, address, routes and one Start button.
 const card=$('mapPlace'),cardKey=place?JSON.stringify([place,s.routes,s.status]):'';card.hidden=!place;
 if(cardKey!==mapCardKey){mapCardKey=cardKey;card.textContent='';
  if(place){
   const head=mapNode('div','map-card-head');head.append(mapNode('b','',place.name||'Place'));const x=mapNode('button','map-card-x','✕');x.type='button';x.dataset.a='close';x.setAttribute('aria-label','Close place');head.append(x);card.append(head);
   const facts=[];if(place.rating)facts.push(Number(place.rating).toFixed(1)+' ★'+(place.count?' ('+place.count+')':''));if(place.type)facts.push(place.type);
   if(facts.length)card.append(mapNode('div','map-card-facts',facts.join(' · ')));
   if(place.open!==undefined||place.hours){const h=mapNode('div','map-card-hours');h.append(mapNode('b',place.open?'open':'closed',place.open?'Open':'Closed'));if(place.hours)h.append(' · '+place.hours);card.append(h);}
   if(place.address)card.append(mapNode('div','map-card-address',place.address));
   const routes=mapNode('div','map-card-routes');(s.routes||[]).forEach((r,i)=>{const c=mapNode('button','map-route'+(r.sel?' sel':''));c.type='button';c.dataset.a='route';c.dataset.i=i;c.append(mapNode('b','',r.time||''),mapNode('span','',[r.dist,r.arrive].filter(Boolean).join(' · ')));routes.append(c);});
   if((s.routes||[]).length)card.append(routes);else card.append(mapNode('div','map-card-facts',s.status||'Finding the route…'));
   const go=mapNode('button','map-start');go.type='button';go.dataset.a='gostart';go.innerHTML=mapArrow('STRAIGHT');go.append(mapNode('span','','Start'+(place.drive?' · '+place.drive:'')));card.append(go);
  }
 }
}
function mapUiTap(event){
 const b=event.target.closest?.('[data-a]');if(!b||b.disabled)return;const a=b.dataset.a,q=$('mapQuery');if(!a)return;
 if(a==='recentre'){jsFollow=true;$('mapRecentre').hidden=true;if(jsPose)carMapFrame(jsPose);return;}
 if(a==='clear'){q.value='';mapSearchOpen=true;mapCmd('type',{q:''});if(mapBgState&&(mapBgState.results||[]).length||mapBgState?.place&&!mapBgState.navigating)mapCmd('close');q.focus();return;}
 const params={};if(b.dataset.i!==undefined)params.i=b.dataset.i;if(b.dataset.id)params.id=b.dataset.id;
 if(['suggest','result','recent','home','work'].includes(a)){mapSearchOpen=false;q.value=b.dataset.t||'';q.blur();}
 if(a==='close'){q.value='';mapSearchOpen=false;}
 mapCmd(a,params);renderMapUi(mapBgState,jsLive());
}
function mapUiSetup(){
 const ui=$('mapUi'),q=$('mapQuery');
 ui.addEventListener('click',mapUiTap);
 for(const type of ['click','keydown','keyup','keypress'])ui.addEventListener(type,e=>e.stopPropagation());
 $('mapSearch').addEventListener('click',()=>{if(document.activeElement!==q)q.focus();});
 q.addEventListener('focus',()=>{mapSearchOpen=true;mapFast=Date.now()+60000;q.select?.();renderMapUi(mapBgState,jsLive());});
 q.addEventListener('input',()=>{mapSearchOpen=true;mapFast=Date.now()+60000;clearTimeout(mapTypeTimer);mapTypeTimer=setTimeout(()=>mapCmd('type',{q:q.value}),250);renderMapUi(mapBgState,jsLive());});
 q.addEventListener('keydown',e=>{if(e.key==='Enter'&&q.value.trim()){e.preventDefault();clearTimeout(mapTypeTimer);mapSearchOpen=true;mapCmd('search',{q:q.value.trim()});q.blur();}else if(e.key==='Escape'){mapSearchOpen=false;q.blur();renderMapUi(mapBgState,jsLive());}});
 // Two fingers or the wheel move the map by hand: stop following the car until Re-centre.
 $('mapJs').addEventListener('touchstart',e=>{if(e.touches.length>1)carMapFree();},{capture:true,passive:true});
 $('mapJs').addEventListener('wheel',()=>carMapFree(),{capture:true,passive:true});
}
mapUiSetup();
async function mapStateLoop(){
 clearTimeout(mapStateTimer);let next=2000;const run=++mapLoopRun;
 try{
  if(connected&&token){
   const s=await api('/map/state');const drive=s.screen==='drive';
   const mapOn=s.mapOn!==false,useJs=mapOn&&!!s.mapKey&&!!s.lat&&jsMapState!=='failed';
   // Build 101: a new key from the phone after a refusal: load the page again so Google starts clean.
   if(jsMapState==='failed'&&mapOn&&s.mapKey&&s.mapKey!==jsMapKey&&!jsReloading){jsReloading=true;location.reload();return;}
   if(jsMapState==='failed'&&Date.now()-jsReportAt>10000)reportCarMap(false,jsFailReason);
   if(mapOn&&s.mapKey&&jsMapState!=='failed')loadCarMap(s.mapKey);
   mapLive=!!s.mapLive&&!useJs&&mapOn;
   // Build 88: when the phone is not drawing the live map, show its GPS-moved map picture.
   const bgMode=mapOn&&!useJs&&!mapLive&&!!s.bg&&s.bgId!==undefined&&!!s.lat;mapBgState=s;
   $('mapJs').hidden=!useJs||jsMapState!=='ready';if(useJs)updateCarMap(s);
   // No map of any kind after a refusal (phone left the app): say why instead of just closing.
   const note=mapOn&&jsMapState==='failed'&&!mapLive&&!bgMode;$('mapNote').hidden=!note;
   $('mapMini').hidden=!(useJs||mapLive||bgMode||note);if(!useJs&&!mapLive&&!bgMode)document.body.classList.remove('map-big');
   $('mapMiniImg').style.visibility=mapLive?'visible':'hidden';$('mapBg').hidden=!bgMode;$('mapBgCar').hidden=!bgMode;
   if(bgMode)placeMapBg(s);
   $('mapTurn').hidden=!drive;$('mapEta').hidden=!drive;
   if(drive){$('mapDist').textContent=s.distance||'';$('mapText').textContent=s.instruction||'';$('mapEtaTime').textContent=s.eta||'';$('mapEtaMore').textContent=[s.remaining,s.arrival].filter(Boolean).join(' · ');
    const arrow=String(s.maneuver||'')+'|'+String(s.then||'');if(arrow!==jsArrow){jsArrow=arrow;$('mapArrow').innerHTML=mapArrow(s.maneuver);$('mapThen').hidden=!s.then;$('mapThenArrow').innerHTML=s.then?mapArrow(s.then):'';}}
   renderMapUi(s,useJs&&jsMapState==='ready');
   next=(useJs||mapLive||bgMode)?(Date.now()<mapFast?300:800):2500;
  }else{mapLive=false;$('mapMini').hidden=true;}
 }catch(e){next=3000;}
 if(run!==mapLoopRun)return;
 mapStateTimer=setTimeout(mapStateLoop,next);
}
function mapFrameLoop(){
 clearTimeout(mapFrameTimer);
 if(!mapLive||!connected||!token){mapFrameTimer=setTimeout(mapFrameLoop,1000);return;}
 const img=$('mapMiniImg'),done=()=>{mapFrameTimer=setTimeout(mapFrameLoop,120);};
 img.onload=done;img.onerror=()=>{mapFrameTimer=setTimeout(mapFrameLoop,1000);};
 img.src='/map/frame.jpg?token='+encodeURIComponent(token)+'&t='+Date.now();
}
const mapReplace=()=>setTimeout(()=>{if(mapBgState&&!$('mapBg').hidden)placeMapBg(mapBgState);},560);
// On the big Google map a tap belongs to the map (drag, place names). Tap the small video to go back.
$('mapMini').addEventListener('click',()=>{if(document.body.classList.contains('map-big')&&jsLive())return;document.body.classList.toggle('map-big');mapReplace();renderMapUi(mapBgState,jsLive());setTimeout(()=>{if(jsPose)carMapFrame(jsPose);},560);});
$('mapMini').addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){if(document.body.classList.contains('map-big')&&jsLive())return;e.preventDefault();document.body.classList.toggle('map-big');renderMapUi(mapBgState,jsLive());}});
$('mediaCanvas').addEventListener('click',e=>{if(document.body.classList.contains('map-big')){document.body.classList.remove('map-big');e.stopPropagation();renderMapUi(mapBgState,jsLive());}},true);
mapStateLoop();mapFrameLoop();
})();

