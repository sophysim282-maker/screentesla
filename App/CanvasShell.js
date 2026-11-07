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
if(developerMode){const option=document.createElement('option');option.value='hd';option.textContent='Developer · source quality';$('quality').appendChild(option);$('quality').value='hd';}
let previousPlaybackProfile=null,performanceFrozen=false;
let stablePlaybackSince=0,stableMediaTime=0,stableDrawn=0;
let healthFailures=0,lastHealthyAt=Date.now(),transportWaiting=false,decoderFaults=0;
let previousToken='',joinGeneration=0,session=0,tickTimer=0,reportPending=false,reconnections=0,lastProgressAt=Date.now(),lastDrawn=0;
let connectionPhase='offline',approvalPhase='',lastRequestAt=0,lastSuccessAt=0;
const credentialKey='screenlink-approved-viewer-v1';
// The approved browser must retain both proofs across reloads and hotspot DHCP
// changes. Storage is origin-local; credentials never appear in URLs or reports.
function restoreCredential(){for(const storage of [()=>sessionStorage,()=>localStorage]){try{const saved=JSON.parse(storage().getItem(credentialKey)||'null');if(saved&&/^[0-9a-f]{32}$/.test(saved.nonce)&&typeof saved.token==='string'&&saved.token.length<=128&&saved.expires>Date.now()){nonce=saved.nonce;previousToken=saved.token;return true;}}catch{}}return false;}
function saveCredential(){if(!nonce||!previousToken)return;const saved=JSON.stringify({nonce,token:previousToken,expires:Date.now()+14400000});for(const storage of [()=>sessionStorage,()=>localStorage])try{storage().setItem(credentialKey,saved);}catch{}}
restoreCredential();
function connectionNotice(phase,message){connectionPhase=phase;status.textContent=message;document.body.dataset.connection=phase;}
let lockedView=false;
const inlineControls={};
function refreshInline(id){const control=inlineControls[id];if(!control)return;for(const button of control.buttons){button.disabled=control.select.disabled||(id==='viewMode'&&button.dataset.value==='split'&&lockedView);button.setAttribute('aria-pressed',String(control.select.value===button.dataset.value));}}
function makeInline(id){const select=$(id),group=document.createElement('span');group.className='inline-options';group.setAttribute('role','group');group.setAttribute('aria-label',select.getAttribute('aria-label')||'Viewer mode');const buttons=[];for(const option of select.options){const button=document.createElement('button');button.type='button';button.textContent=option.textContent;button.dataset.select=id;button.dataset.value=option.value;button.onclick=()=>{if(select.disabled||select.value===option.value)return;select.value=option.value;select.dispatchEvent(new Event('change',{bubbles:true}));refreshInline(id);};group.appendChild(button);buttons.push(button);}select.after(group);select.hidden=true;select.setAttribute('aria-hidden','true');select.tabIndex=-1;inlineControls[id]={select,buttons};new MutationObserver(()=>refreshInline(id)).observe(select,{attributes:true,attributeFilter:['disabled']});refreshInline(id);}
let screen=new ScreenLinkScreen.CanvasScreen($('mapCanvas'),{onstate:screenState,onerror:screenError});
function screenState(meta){if((Number(meta.privacyRevision)||0)<minRevision)return;minRevision=Math.max(minRevision,Number(meta.privacyRevision)||0);if(meta.hidden){mapCover.hidden=false;mapCover.textContent=meta.confirmed?'PHONE SCREEN HIDDEN — open Maps before showing.':'Phone screen hidden.';$('privacyState').textContent=meta.confirmed?'HIDDEN confirmed on phone.':'Screen hidden; phone confirmation pending.';}else if(meta.frameReady&&!privacyPending){mapCover.hidden=true;$('privacyState').textContent='Screen visible. Hide before leaving Maps.';}else if(meta.localHidden){mapCover.hidden=false;mapCover.textContent='Screen hidden locally. Press Show screen with Maps open.';}
 $('mapDetail').textContent='WebCodecs · '+(meta.framesDrawn||screen.framesDrawn)+' frames drawn · rotation '+(meta.orientation||1);}
function hideLocal(message){screen.hide();mapCover.hidden=false;mapCover.textContent=message;$('privacyState').textContent=message;}
function screenError(error){screenFault=true;hideLocal('Screen decoder stopped: '+error.message);$('mapDetail').textContent=error.message;ws?.close();}
async function raw(path,options={}){lastRequestAt=Date.now();const control=new AbortController(),timeout=setTimeout(()=>control.abort(),7000);try{const response=await fetch(path,{...options,cache:'no-store',signal:control.signal});if(!response.ok){const e=Error('HTTP '+response.status+' from '+path.split('?')[0]);e.status=response.status;throw e;}const result=await response.json();lastSuccessAt=Date.now();return result;}finally{clearTimeout(timeout);}}
async function api(path,options={}){if(!token)throw Error('Waiting for the phone connection.');const activeSession=session,credential=token;try{const result=await raw(path+'?token='+encodeURIComponent(credential),options);if(activeSession!==session)throw new DOMException('Session replaced','AbortError');return result;}catch(error){if(error.status===403&&activeSession===session)connectionLost('Viewer session expired. Reconnecting automatically.');throw error;}}
function mediaClear(){mediaGeneration++;if(player?.performanceProfile)previousPlaybackProfile=player.performanceProfile();player?.destroy();player=null;mediaEpoch='';command=-1;mediaCover.hidden=false;mediaCover.textContent='Waiting for YouTube AirPlay.';setIdleArtwork(true);}
function connectionLost(message){sourceState=null;if(player)resumeConnection={epoch:mediaEpoch,position:player.currentTime};connected=false;previousToken=token||previousToken;saveCredential();token='';session++;reconnections++;clearTimeout(tickTimer);const oldSocket=ws;ws=null;oldSocket?.close();clearTimeout(wsTimer);mediaClear();hideLocal('Connection lost. Hide is NOT confirmed on the phone.');connectionNotice('offline',message);}
async function connect(){if(joining||connected)return;joining=true;stopped=false;const attempt=++joinGeneration;try{
 if(!isSecureContext||typeof VideoDecoder!=='function')throw Error('This player needs HTTPS and browser WebCodecs support. Keep the HTTP fallback available.');
 if(!nonce)try{nonce=sessionStorage.getItem('screenlink-local-nonce')||'';}catch{}if(!/^[0-9a-f]{32}$/.test(nonce)){nonce=Array.from(crypto.getRandomValues(new Uint8Array(16)),x=>x.toString(16).padStart(2,'0')).join('');try{sessionStorage.setItem('screenlink-local-nonce',nonce);}catch{}}
 connectionNotice('connecting','Connecting to your phone…');
 const deadline=Date.now()+120000;
 while(!stopped&&Date.now()<deadline){const next=await raw('/local-viewer/request',{method:'POST',headers:{'Content-Type':'application/json','X-ScreenLink-Viewer':'request'},body:JSON.stringify({nonce,previousToken})});
  if(stopped||attempt!==joinGeneration)return;
  approvalPhase=next.phase||'unknown';
  if(next.phase==='approved'&&typeof next.token==='string'){token=next.token;previousToken=token;saveCredential();session++;polling=false;privacyPending=false;$('hide').disabled=false;$('show').disabled=youtubeOnly;connected=true;healthFailures=0;lastProgressAt=Date.now();lastDrawn=0;screen.destroy();screen=new ScreenLinkScreen.CanvasScreen($('mapCanvas'),{onstate:screenState,onerror:screenError});minRevision=0;screenFault=false;pendingPacket=null;wsAttempt=0;mediaFailed=false;connectionNotice('connected','Phone connected · local HTTPS');if(youtubeOnly)await privacy(true);else openSocket();tick();return;}
  if(next.phase==='busy'){connectionNotice('busy','Phone reached. Another browser session is approved. Tap Reconnect website in ScreenLink to switch to this page.');}
  else if(next.phase==='pending'){connectionNotice('pending','Phone reached. In ScreenLink → Developer, tap Approve local viewer, or tap Reconnect website on the home screen.');}
  else if(['rejected','invalid'].includes(next.phase)){const e=Error('Phone approval: '+next.phase+'. Tap Reconnect website on your phone to try again.');e.approval=next.phase;throw e;}
  await new Promise(r=>setTimeout(r,1200));}
 if(!stopped)throw Error('Approval timed out. Waiting for automatic reconnection.');
 }catch(error){if(stopped||attempt!==joinGeneration)return;lastConnectionError={message:error.message||String(error),time:Date.now(),httpStatus:error.status||0,approval:approvalPhase};if(error.approval)connectionNotice(error.approval,error.message);else if(!['busy','pending'].includes(connectionPhase))connectionNotice('offline','Phone not connected — saved page only. Retrying HTTPS automatically. Keep the hotspot and ScreenLink active.');}finally{if(attempt===joinGeneration)joining=false;}}
function openSocket(){if(!connected||stopped||youtubeOnly)return;clearTimeout(wsTimer);pendingPacket=null;wsWork=Promise.resolve();const socket=new WebSocket(location.origin.replace(/^http/,'ws')+'/stream?token='+encodeURIComponent(token));socket.binaryType='arraybuffer';ws=socket;
 socket.onopen=()=>{$('mapDetail').textContent='Local WSS connected; capture remains hidden until Show.';wsAttempt=0;};
 socket.onmessage=event=>{wsWork=wsWork.then(async()=>{if(ws!==socket||!connected)return;
  if(typeof event.data==='string'){if(event.data.length>4096)throw Error('Screen metadata too large');const meta=JSON.parse(event.data);if(!['state','init','data'].includes(meta.kind)||!Number.isInteger(meta.bytes)||meta.bytes<0||meta.bytes>2*1024*1024)throw Error('Invalid screen metadata');if(pendingPacket)throw Error('Screen packet incomplete');if(meta.bytes){pendingPacket=meta;screen.state(meta);}else{screen.state(meta);await new Promise(r=>setTimeout(r,200));if(socket.readyState===WebSocket.OPEN)socket.send('next');}}
  else{const meta=pendingPacket;pendingPacket=null;if(!meta||event.data.byteLength!==meta.bytes)throw Error('Screen payload size mismatch');await screen.packet(meta,event.data);if(socket.readyState===WebSocket.OPEN&&ws===socket)socket.send('next');}
 }).catch(error=>{if(ws===socket)screenError(error);});};
 socket.onerror=()=>{$('mapDetail').textContent='Secure screen connection interrupted.';};
 socket.onclose=()=>{if(ws!==socket)return;ws=null;pendingPacket=null;hideLocal('Screen connection lost. Hide is NOT confirmed on phone.');if(connected&&!stopped&&!screenFault)wsTimer=setTimeout(openSocket,Math.min(10000,500*Math.pow(2,Math.min(wsAttempt++,4))));};}
async function privacy(hidden){const activeSession=session;if(privacyPending||(!hidden&&youtubeOnly))return false;if(!hidden)screenFault=false;privacyPending=true;$('hide').disabled=true;$('show').disabled=true;if(hidden)hideLocal('Hiding… wait for phone confirmation.');try{const meta=await api('/screen/privacy',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({hidden,expectedRevision:minRevision})});minRevision=Math.max(minRevision,Number(meta.privacyRevision)||0);screen.privacy(meta,!hidden);if(hidden)screenState({...meta,confirmed:true});else{mapCover.hidden=false;mapCover.textContent='Waiting for a fresh screen frame…';if(!ws)openSocket();}return true;}catch(error){if(activeSession!==session)return false;hideLocal('Change NOT confirmed. Keep Maps open or stop broadcast.');$('mapDetail').textContent=error.message;return false;}finally{if(activeSession===session){privacyPending=false;$('hide').disabled=false;$('show').disabled=youtubeOnly;}}}
function playbackFault(error,direct){if(player!==direct)return;if(error?.name==='AbortError')return;if(error.kind==='transport'){transportWaiting=true;lastPlaybackError={message:error.message,kind:'transport',position:direct.currentTime,time:Date.now()};$('mediaDetail').textContent='Waiting for phone/media connection. Buffered playback is retained.';return;}stablePlaybackSince=0;decoderFaults++;retryPosition=direct.currentTime||retryPosition;lastPlaybackError={message:String(error.message||error),name:error.name||'Error',position:retryPosition,time:Date.now(),stats:{...direct.stats},profile:direct.performanceProfile?.()};mediaFailed=true;retryAt=Date.now()+Math.min(10000,2000*Math.pow(2,retryCount));direct.destroy();mediaCover.hidden=false;mediaCover.textContent=retryCount<3?'Recovering playback…':'Playback recovery stopped. Press Retry video.';$('mediaDetail').textContent=lastPlaybackError.message;}
async function startMedia(next,resume=0){transportWaiting=false;mediaClear();setIdleArtwork(false);mediaFailed=false;mediaEpoch=next.epoch;const generation=mediaGeneration;if(!ScreenLinkCanvas.CanvasPlayer.supported()){mediaFailed=true;mediaCover.textContent='YouTube requires supported VideoDecoder and AudioDecoder.';return;}
 const direct=new ScreenLinkCanvas.CanvasPlayer($('mediaCanvas'),{quality:$('quality').value,audioContext,bufferSeconds:1,onerror:error=>playbackFault(error,direct)});player=direct;
 try{await direct.load(next.url,resume||(next.start||0));if(generation!==mediaGeneration||!connected){direct.destroy();return;}if(next.fraction>0&&!resume&&!next.start)direct.currentTime=next.fraction*direct.duration;if(soundWanted&&audioContext?.state==='running'){await direct.enableAudio();direct.setEQ($('eq').value);}if(next.paused)direct.pause();else await direct.play();
 // Autoplay is attempted without blocking connection or video startup.
 if(!soundWanted){if(!audioContext)audioContext=new AudioContext({sampleRate:direct.lastAudioSampleRate||44100});audioContext.resume().then(async()=>{if(generation!==mediaGeneration||player!==direct||soundWanted||audioContext.state!=='running')return;soundWanted=true;await direct.enableAudio(audioContext);direct.setEQ($('eq').value);$('sound').textContent='Sound enabled';}).catch(()=>{});}
 }
 catch(error){if(player===direct)playbackFault(error,direct);}
}
async function tick(){if(polling)return;polling=true;const activeSession=session;try{if(!connected)return;const drawn=(player?.stats.drawn||0)+screen.framesDrawn;if(drawn!==lastDrawn){lastProgressAt=Date.now();lastDrawn=drawn;}const next=await api('/media/state');sourceState=next;lockedView=!!next.screenLocked;refreshInline('viewMode');if(lockedView&&!youtubeOnly)await setViewerMode('youtube');healthFailures=0;lastHealthyAt=Date.now();connectionNotice('connected','Phone connected · local HTTPS');
 if(!next.active){if(mediaEpoch)mediaClear();$('mediaDetail').textContent=next.error||'Select ScreenLink VPN Phone in YouTube AirPlay.';}
 else{if(transportWaiting&&player&&(!player.running||player.videoEnd-player.currentTime<.12)){retryPosition=player.currentTime;await startMedia(next,retryPosition);}if(next.epoch!==mediaEpoch){retryCount=0;await startMedia(next,resumeConnection?.epoch===next.epoch?resumeConnection.position:0);resumeConnection=null;}else if(mediaFailed&&retryCount<3&&Date.now()>=retryAt){retryCount++;await startMedia(next,retryPosition);}if(!connected)return;
  if(next.command!==command&&player){command=next.command;if(next.commandKind==='seek')player.currentTime=next.seek;if(next.paused)player.pause();else await player.play();}
  const p=player;if(p&&!mediaFailed){
   const progressing=p.running&&!p.paused&&p.currentTime>stableMediaTime+.1&&p.stats.drawn>stableDrawn;
   if(progressing){if(!stablePlaybackSince)stablePlaybackSince=Date.now();if(Date.now()-stablePlaybackSince>=20000)retryCount=0;}else stablePlaybackSince=0;
   stableMediaTime=p.currentTime;stableDrawn=p.stats.drawn;mediaCover.hidden=p.stats.drawn>0&&!mediaFailed;if(!mediaCover.hidden&&!mediaFailed)mediaCover.textContent='Loading original video…';$('mediaDetail').textContent=(mediaFailed?p.error?.message||'Decoder stopped':p.paused?'Paused':'WebCodecs + Web Audio')+' · '+$('mediaCanvas').width+' × '+$('mediaCanvas').height+' · '+p.stats.drawn+' frames';$('seek').value=p.duration?100*p.currentTime/p.duration:0;
   if(!reportPending){reportPending=true;api('/media/report',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({epoch:mediaEpoch,command,position:p.currentTime,duration:p.duration,paused:p.paused,ready:p.readyState>=2&&!p.error,ended:p.ended,error:retryCount>=3?(p.error?.message||''):''})}).catch(()=>{}).finally(()=>{reportPending=false;});}}
 }
 }catch(error){if(connected&&activeSession===session){healthFailures++;lastConnectionError={message:error.message,time:Date.now(),failures:healthFailures};if(healthFailures>=3){const drawn=(player?.stats.drawn||0)+screen.framesDrawn;if(drawn!==lastDrawn){lastProgressAt=Date.now();lastDrawn=drawn;}connectionNotice('recovering','Phone connection interrupted. Retaining buffered playback and retrying.');if(Date.now()-lastProgressAt>=8000)connectionLost('Phone receiver unavailable. Reconnecting automatically when it returns.');}}}finally{if(activeSession!==session)return;polling=false;renderPerformance();if(connected&&!stopped){clearTimeout(tickTimer);tickTimer=setTimeout(tick,1000);}}}
$('hide').onclick=()=>privacy(true);$('show').onclick=()=>privacy(false);
$('sound').onclick=async()=>{try{if(!audioContext)audioContext=new AudioContext({sampleRate:player?.lastAudioSampleRate||44100});await audioContext.resume();soundWanted=true;if(player){await player.enableAudio(audioContext);player.setEQ($('eq').value);}$('sound').textContent='Sound enabled';}catch(error){$('mediaDetail').textContent=error.message;}};
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
function viewLayout(){if($('modeHint'))$('modeHint').textContent=youtubeOnly?'YouTube · no screen recording':'Maps screen sharing + YouTube';document.body.classList.toggle('youtube-only',youtubeOnly);$('viewMode').value=youtubeOnly?'youtube':'split';$('show').disabled=youtubeOnly;refreshInline('viewMode');}
function closeScreenSocket(){clearTimeout(wsTimer);const socket=ws;ws=null;pendingPacket=null;socket?.close();screen.hide();}
async function setViewerMode(value){
 if(modeBusy||privacyPending){$('viewMode').value=youtubeOnly?'youtube':'split';return;}
 modeBusy=true;$('viewMode').disabled=true;youtubeOnly=value==='youtube';viewLayout();closeScreenSocket();hideLocal('Screen hidden locally; waiting for phone confirmation.');
 try{try{localStorage.setItem('screenlink-canvas-view',youtubeOnly?'youtube':'split');}catch{}try{history.replaceState(null,'',youtubeOnly?'/video':'/split');}catch{}
  if(connected){const hidden=await privacy(true);if(!hidden)status.textContent='Screen hide NOT confirmed. Press Hide screen again or stop sharing on the phone.';if(!youtubeOnly)openSocket();}
 }finally{modeBusy=false;$('viewMode').disabled=false;}
}
try{youtubeOnly=location.pathname==='/video'||(location.pathname!=='/split'&&localStorage.getItem('screenlink-canvas-view')==='youtube');}catch{youtubeOnly=location.pathname==='/video';}viewLayout();$('viewMode').onchange=()=>setViewerMode($('viewMode').value);
function move(e){const r=panels.getBoundingClientRect();split=100*(stacked?(e.clientY-r.top)/r.height:(e.clientX-r.left)/r.width);layout();}divider.onpointerdown=e=>{e.preventDefault();divider.setPointerCapture(e.pointerId);move(e);};divider.onpointermove=e=>{if(divider.hasPointerCapture(e.pointerId))move(e);};divider.onkeydown=e=>{if(['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','Home','End'].includes(e.key)){e.preventDefault();split=e.key==='Home'?20:e.key==='End'?80:split+(['ArrowLeft','ArrowUp'].includes(e.key)?-2:2);layout();}};$('reset').onclick=()=>{split=50;layout();};$('layout').onclick=()=>{stacked=!stacked;layout();};layout();
window.addEventListener('online',()=>{if(connected){tick();if(!ws)openSocket();}else connect();});window.addEventListener('pagehide',()=>{clearTimeout(reconnectTimer);clearTimeout(tickTimer);joinGeneration++;joining=false;previousToken=token||previousToken;saveCredential();token='';session++;stopped=true;connected=false;sourceState=null;polling=false;privacyPending=false;clearTimeout(wsTimer);const oldSocket=ws;ws=null;oldSocket?.close();screen.destroy();mediaClear();setIdleArtwork(false);audioContext?.close();audioContext=null;soundWanted=false;});
// Tesla can restore the page from its back/forward cache without running this script again.
// Resume discovery with a fresh decoder and credential handshake, never a dead socket.
window.addEventListener('pageshow',event=>{if(!event.persisted)return;setIdleArtwork(true);stopped=false;screen=new ScreenLinkScreen.CanvasScreen($('mapCanvas'),{onstate:screenState,onerror:screenError});minRevision=0;screenFault=false;pendingPacket=null;modeBusy=false;$('viewMode').disabled=false;$('hide').disabled=false;$('show').disabled=youtubeOnly;status.textContent='Reconnecting to ScreenLink…';clearTimeout(reconnectTimer);autoConnect();});
function renderPerformance(){
 if(performanceFrozen||$('performancePanel').hidden)return;
 const profile=player?.performanceProfile?.()||previousPlaybackProfile;
 const lines=['Build: 0.20.28 / 65','Playback: '+(player?.currentTime||0).toFixed(2)+' s','Page: '+(profile?.visibility||document.visibilityState||'unknown'),''];
 const names=[['demuxMs','Demux ms'],['decoderWaitMs','Decoder feed wait ms'],['renderCallbackGapMs','Drawing callback gap ms'],['canvasDrawMs','Canvas draw call ms'],['videoQueueDepth','Pending decode requests']];
 for(const [key,label] of names){const m=profile?.metrics[key];lines.push(label+': '+(m?'mean '+m.mean.toFixed(2)+' | max '+m.max.toFixed(2)+' | n '+m.count:'no samples'));if(m)lines.push('  max at '+(m.maxAtMs/1000).toFixed(2)+'s, media '+m.mediaTime.toFixed(2)+'s');}
 lines.push('','Decode queue now: '+(profile?.videoQueueDepth||0),'Decoded frames queued: '+(profile?.framesQueued||0),'Video recoveries: '+(player?.stats.videoRecoveries||0),'Audio buffer underruns: '+(player?.stats.audioUnderruns||0));
 $('performanceText').textContent=lines.join('\n');
}
$('showPerformance').onclick=()=>{$('performancePanel').hidden=false;performanceFrozen=false;$('freezePerformance').textContent='Freeze report';renderPerformance();};
$('freezePerformance').onclick=()=>{performanceFrozen=!performanceFrozen;$('freezePerformance').textContent=performanceFrozen?'Resume report':'Freeze report';if(!performanceFrozen)renderPerformance();};
$('closePerformance').onclick=()=>{$('performancePanel').hidden=true;};
$('copyPlayback').onclick=async()=>{const text=JSON.stringify(self.ScreenLinkCanvasStatus(),null,2);try{await navigator.clipboard.writeText(text);$('copyPlayback').textContent='Diagnostics copied';}catch{const box=$('playbackDiagnostics');box.hidden=false;box.value=text;box.focus();box.select();}};
if(isSecureContext&&'serviceWorker' in navigator)navigator.serviceWorker.register('/sw.js',{scope:'/'}).catch(error=>{lastConnectionError={message:'Offline UI unavailable: '+error.message,time:Date.now()};});
self.ScreenLinkCanvasStatus=()=>({build:'0.20.28-65',connectionPhase,approvalPhase,lastRequestAt,lastSuccessAt,healthFailures,lastHealthyAt,reconnections,quality:$('quality').value,transportWaiting,decoderFaults,transportError:player?.lastTransportError||null,lastPlaybackError,lastConnectionError,recoveryAttempts:retryCount,mediaRunning:player?.running||false,mediaDuration:player?.duration||0,videoFramesQueued:player?.frames.length||0,audioPacketsQueued:player?.audio.length||0,secureContext:isSecureContext,connected,connectionPending:joining,viewerMode:youtubeOnly?'youtube':'split',screenFrames:screen.framesDrawn,screenHidden:screen.hold,screenQueue:screen.decoder?.decodeQueueSize||0,mediaEpoch,mediaPosition:player?.currentTime||0,mediaPaused:player?.paused??true,mediaWidth:$('mediaCanvas').width,mediaHeight:$('mediaCanvas').height,youtubeBufferSeconds:player?.bufferSeconds||0,encodedVideoLead:player?Math.max(0,player.preparedVideoEnd-player.currentTime):0,mediaStats:player?{...player.stats}:null,performance:player?.performanceProfile?.()||null,previousPlaybackProfile,playbackEvents:player?(player.playbackEvents||[]).map(e=>({...e})):[],segmentCache:player?.segmentCache?.size||0,audioSampleRate:player?.audioContext?.sampleRate||0,decodedAudioRate:player?.lastAudioSampleRate||player?.audio[0]?.sampleRate||0,segments:player?(player.segmentDiagnostics||[]).map(s=>({...s})):[],audioLead:player?.audioContext&&player.audioTail!==null?Math.max(0,player.audioTail-player.audioContext.currentTime):0,videoLead:player?Math.max(0,player.videoEnd-player.currentTime):0,audioState:audioContext?.state||'locked',audioNodes:player?.nodes.size||0,mediaError:player?.error?.message||'',socketOpen:ws?.readyState===WebSocket.OPEN});
for(const id of ['viewMode','quality','eq'])makeInline(id);
function autoConnect(){if(!stopped&&!connected&&!joining)connect();if(!stopped)reconnectTimer=setTimeout(autoConnect,3000);}if(isSecureContext&&typeof VideoDecoder==='function')autoConnect();
if(!isSecureContext||typeof VideoDecoder!=='function')status.textContent='This viewer needs HTTPS and WebCodecs support.';
})();


