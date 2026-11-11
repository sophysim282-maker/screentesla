// Build 71: the car website's default YouTube player.
// Same decoding path as the HTTP fallback at 240.3.3.3 (MediaPlayer.html), which
// played without stopping on the Tesla: HLS.js feeds the browser's own <video>
// decoder, each new picture is copied onto the canvas, and sound goes through
// Web Audio for phone volume and Normal/Music. The WebCodecs CanvasPlayer is
// unchanged and stays available with ?engine=webcodecs.
(()=>{'use strict';
const height=level=>Number(level?.height)||0;

// Same rule as CanvasPlayer's chooseVariant: highest source at or below the
// requested height, never above 1080p; Auto means the highest up to 1080p.
function chooseLevel(levels,quality='auto'){
 let candidates=levels.map((level,index)=>({level,index})).filter(c=>!height(c.level)||height(c.level)<=1080);
 if(!candidates.length)return -1;
 const wanted=Number(quality);
 if(wanted>0){const preferred=candidates.filter(c=>height(c.level)>0&&height(c.level)<=Math.min(1080,wanted));if(preferred.length)candidates=preferred;}
 const known=candidates.filter(c=>height(c.level)>0);if(known.length)candidates=known;
 return candidates.sort((a,b)=>height(b.level)-height(a.level)||(Number(b.level.bitrate)||0)-(Number(a.level.bitrate)||0))[0].index;
}

class BrowserVideoPlayer{
 static supported(){return !!(self.Hls&&self.Hls.isSupported());}
 constructor(canvas,{onerror=()=>{},quality='auto',audioContext=null,file=false}={}){
  this.file=!!file;this.canvas=canvas;this.ctx=canvas.getContext('2d',{alpha:false});this.onerror=onerror;this.quality=quality;this.audioContext=audioContext;
  this.engine='browser';this.closed=false;this.error=null;this.lastTransportError=null;this.hls=null;this.recoveries=0;this.selectedHeight=0;this.offeredHeights=[];
  this.stats={drawn:0,videoRecoveries:0,audioUnderruns:0,stalls:0,hlsErrors:0,dropped:0};
  // Fields the website status report reads from the WebCodecs player.
  this.frames=[];this.audio=[];this.nodes=new Set();this.playbackEvents=[];this.segmentDiagnostics=[];this.segmentCache=new Map();this.lastAudioSampleRate=0;
  const video=this.video=document.createElement('video');
  video.muted=true;video.playsInline=true;video.setAttribute('playsinline','');video.disableRemotePlayback=true;video.preload='auto';video.style.display='none';
  document.body.appendChild(video);
  video.addEventListener('waiting',()=>{if(!this.closed&&!video.paused){this.stats.stalls++;this.record('waiting');}});
  video.addEventListener('playing',()=>this.record('playing'));
  this.lastDrawn=-1;
  const draw=()=>{if(this.closed)return;
   if(video.readyState>=2&&video.videoWidth&&video.currentTime!==this.lastDrawn){
    if(this.canvas.width!==video.videoWidth||this.canvas.height!==video.videoHeight){this.canvas.width=video.videoWidth;this.canvas.height=video.videoHeight;}
    this.ctx?.drawImage(video,0,0,this.canvas.width,this.canvas.height);this.lastDrawn=video.currentTime;this.stats.drawn++;
   }
   this.animation=requestAnimationFrame(draw);};
  this.animation=requestAnimationFrame(draw);
 }
 record(type,detail=''){this.playbackEvents.push({type,position:this.currentTime,at:Date.now(),detail});if(this.playbackEvents.length>60)this.playbackEvents.shift();}
 load(url,start=0){
  return new Promise((resolve,reject)=>{
   if(this.closed)return reject(new DOMException('Playback replaced','AbortError'));
   const Hls=self.Hls,video=this.video;let settled=false;
   const finish=error=>{if(settled)return;settled=true;clearTimeout(timer);video.removeEventListener('loadeddata',ready);error?reject(error):resolve();};
   const ready=()=>finish();
   const timer=setTimeout(()=>finish(Object.assign(Error('Video did not start within 20 seconds'),{kind:'transport'})),20000);
   // Build 111 (TikTok test): one plain video file instead of a playlist. The browser plays it by itself.
   if(this.file){video.addEventListener('loadeddata',ready);video.addEventListener('error',()=>{if(this.closed)return;const error=Error('Video file could not be played (media error '+(video.error?.code||0)+')');this.error=error;if(settled)this.onerror(error);else finish(error);});
    video.addEventListener('loadedmetadata',()=>{this.selectedHeight=video.videoHeight||0;this.offeredHeights=this.selectedHeight?[this.selectedHeight]:[];if(start>0){try{video.currentTime=start;}catch{}}},{once:true});video.src=url;video.load();return;}
   const hls=this.hls=new Hls({maxBufferLength:20,maxMaxBufferLength:40,backBufferLength:15,capLevelToPlayerSize:false,autoStartLoad:false,startPosition:start>0?start:-1});
   hls.on(Hls.Events.MANIFEST_PARSED,()=>{if(this.hls!==hls)return;
    this.offeredHeights=hls.levels.map(height).filter(Boolean);
    const index=chooseLevel(hls.levels,this.quality);
    if(index>=0){hls.startLevel=index;hls.loadLevel=index;this.selectedHeight=height(hls.levels[index]);}
    hls.startLoad(start>0?start:-1);});
   hls.on(Hls.Events.ERROR,(_event,data)=>{if(this.hls!==hls||this.closed)return;
    this.stats.hlsErrors++;const message=(data.type||'HLS')+'/'+(data.details||'unknown')+(data.response?.code?' HTTP '+data.response.code:'');this.record(data.fatal?'fatal':'error',message);
    if(!data.fatal)return;
    if(data.type===Hls.ErrorTypes.NETWORK_ERROR&&this.recoveries++<3){this.stats.videoRecoveries++;hls.startLoad();return;}
    if(data.type===Hls.ErrorTypes.MEDIA_ERROR&&this.recoveries++<3){this.stats.videoRecoveries++;hls.recoverMediaError();return;}
    const error=Error(message);if(data.type===Hls.ErrorTypes.NETWORK_ERROR){error.kind='transport';this.lastTransportError={message,time:Date.now()};}
    this.error=error;if(settled)this.onerror(error);else finish(error);});
   hls.on(Hls.Events.FRAG_BUFFERED,()=>{if(this.hls===hls)this.recoveries=0;});
   video.addEventListener('loadeddata',ready);
   hls.loadSource(url);hls.attachMedia(video);
  });
 }
 get currentTime(){const t=this.video.currentTime;return Number.isFinite(t)?t:0;}
 set currentTime(value){if(Number.isFinite(value)&&value>=0){try{this.video.currentTime=value;this.record('seek');}catch{}}}
 get duration(){const d=this.video.duration;return Number.isFinite(d)?d:0;}
 get paused(){return this.video.paused;}
 get readyState(){return this.video.readyState;}
 get ended(){return this.video.ended;}
 get running(){return !this.closed&&!this.video.paused&&this.video.readyState>=2;}
 get videoEnd(){const b=this.video.buffered,t=this.video.currentTime;for(let i=0;i<b.length;i++)if(b.start(i)<=t+.1&&b.end(i)>=t)return b.end(i);return t;}
 get preparedVideoEnd(){return this.videoEnd;}
 get bufferSeconds(){return Math.max(0,this.videoEnd-this.currentTime);}
 async play(){if(this.closed)return;try{await this.video.play();}catch(error){
  // Browsers allow muted autoplay; sound is enabled later by the tap prompt.
  if(error?.name==='NotAllowedError'&&!this.video.muted){this.video.muted=true;await this.video.play().catch(()=>{});}}}
 pause(){this.video.pause();}
 async enableAudio(sharedContext=null){
  if(this.closed)return;
  if(sharedContext&&!this.audioContext)this.audioContext=sharedContext;
  if(!this.audioContext)this.audioContext=new AudioContext();
  const context=this.audioContext;
  if(!this.gain){
   this.source=context.createMediaElementSource(this.video);this.gain=context.createGain();
   this.low=context.createBiquadFilter();this.low.type='lowshelf';this.low.frequency.value=180;
   this.high=context.createBiquadFilter();this.high.type='highshelf';this.high.frequency.value=3500;
   this.source.connect(this.gain).connect(this.low).connect(this.high).connect(context.destination);
  }
  await context.resume();this.lastAudioSampleRate=context.sampleRate;this.video.muted=false;this.gain.gain.value=1;await this.play();
 }
 setEQ(mode){if(this.low){this.low.gain.value=mode==='music'?3:0;this.high.gain.value=mode==='music'?2:0;}}
 performanceProfile(){return {engine:'browser video (HLS.js)',visibility:document.visibilityState,metrics:{},videoQueueDepth:0,framesQueued:0,stalls:this.stats.stalls,hlsErrors:this.stats.hlsErrors,selectedHeight:this.selectedHeight,droppedFrames:this.video.getVideoPlaybackQuality?.().droppedVideoFrames??null};}
 destroy(){if(this.closed)return;this.closed=true;cancelAnimationFrame(this.animation);
  try{this.hls?.destroy();}catch{}this.hls=null;
  try{this.source?.disconnect();this.gain?.disconnect();this.low?.disconnect();this.high?.disconnect();}catch{}
  this.video.pause();this.video.removeAttribute('src');try{this.video.load();}catch{}this.video.remove();}
}
self.ScreenLinkBrowserVideo={BrowserVideoPlayer,chooseLevel};
})();
