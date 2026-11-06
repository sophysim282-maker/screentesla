/* ScreenLink: HLS -> TS/fMP4 demux -> WebCodecs -> Canvas + Web Audio.
   Direct decoding is deliberately capability-gated; the caller retains HLS fallback. */
(()=>{
'use strict';
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const attrs=line=>Object.fromEntries([...line.matchAll(/([A-Z0-9-]+)=(?:"([^"]*)"|([^,]*))/g)].map(m=>[m[1],m[2]??m[3]]));
const join=arrays=>{const out=new Uint8Array(arrays.reduce((n,a)=>n+a.byteLength,0));let i=0;for(const a of arrays){out.set(new Uint8Array(a.buffer||a,a.byteOffset||0,a.byteLength),i);i+=a.byteLength;}return out;};
function playlist(text,url){
 const lines=text.trim().split(/\r?\n/).map(s=>s.trim()),out={variants:[],audio:[],segments:[],duration:0,end:false};
 if(lines[0]!=='#EXTM3U')throw Error('Invalid HLS playlist');
 let variant=null,duration=0,map=null,range=null,offset=0,lastURI='',discontinuity=false;
 const byteRange=value=>{const [size,start]=value.split('@').map(Number);if(!Number.isFinite(size)||size<=0)throw Error('Invalid HLS byte range');const at=Number.isFinite(start)?start:offset;offset=at+size;return {start:at,end:at+size-1};};
 for(const line of lines){
  if(line.startsWith('#EXT-X-STREAM-INF:'))variant=attrs(line);
  else if(line.startsWith('#EXT-X-MEDIA:')){const a=attrs(line);if(a.TYPE==='AUDIO'&&a.URI)out.audio.push({...a,url:new URL(a.URI,url).href});}
  else if(line.startsWith('#EXT-X-KEY:')&&attrs(line).METHOD!=='NONE')throw Error('Encrypted HLS needs the compatibility player');
  else if(line.startsWith('#EXT-X-MAP:')){const a=attrs(line);map={url:new URL(a.URI,url).href,range:a.BYTERANGE?byteRange(a.BYTERANGE):null};offset=0;}
  else if(line.startsWith('#EXTINF:'))duration=parseFloat(line.slice(8));
  else if(line.startsWith('#EXT-X-BYTERANGE:'))range=line.slice(17);
  else if(line==='#EXT-X-DISCONTINUITY')discontinuity=true;
  else if(line==='#EXT-X-ENDLIST')out.end=true;
  else if(line&&!line.startsWith('#')){
   const uri=new URL(line,url).href;
   if(variant){out.variants.push({...variant,url:uri});variant=null;}
   else {if(!Number.isFinite(duration)||duration<=0)throw Error('Missing HLS segment duration');if(uri!==lastURI&&!String(range).includes('@'))offset=0;
    out.segments.push({url:uri,map,range:range?byteRange(range):null,start:out.duration,duration,discontinuity});out.duration+=duration;duration=0;range=null;lastURI=uri;discontinuity=false;}
  }
 }
 return out;
}
// Prefer actual source resolution. A 6 Mbps ceiling can otherwise select 240p
// when the source's 720p/1080p variants use a higher bitrate.
function chooseVariant(levels,quality='hd'){
 const height=level=>Number((level.RESOLUTION||'').split('x')[1])||0;
 let candidates=levels.filter(level=>!height(level)||height(level)<=1080),wanted=Number(quality);
 if(!candidates.length)throw Error('YouTube offered no source at or below 1080p.');
 if(wanted>0){const preferred=candidates.filter(level=>height(level)>0&&height(level)<=Math.min(1080,wanted));if(preferred.length)candidates=preferred;}
 const known=candidates.filter(level=>height(level)>0);if(known.length)candidates=known;
 return candidates.sort((a,b)=>height(b)-height(a)||(Number(b.BANDWIDTH)||0)-(Number(a.BANDWIDTH)||0))[0];
}
function description(entry){
 const box=entry.avcC||entry.hvcC||entry.vpcC||entry.av1C||entry.dOps;
 if(box){const stream=new DataStream(undefined,0,DataStream.BIG_ENDIAN);box.write(stream);return new Uint8Array(stream.buffer,8);}
 // MPEG-4 ES descriptor -> DecoderSpecificInfo, including nested descriptors.
 if(entry.esds){const walk=node=>{if(node.tag===5&&node.data)return new Uint8Array(node.data);for(const child of node.descs||[]){const found=walk(child);if(found)return found;}return null;};return walk(entry.esds.esd);}
 return undefined;
}
function demuxMP4(bytes){
 const file=MP4Box.createFile(),tracks=new Map(),samples=[];let failure=null;
 file.onError=e=>{failure=Error('MP4 demux: '+e);};
 file.onReady=info=>{for(const track of info.tracks){if(!track.video&&!track.audio)continue;const entry=file.getTrackById(track.id).mdia.minf.stbl.stsd.entries[0];tracks.set(track.id,{...track,description:description(entry)});file.setExtractionOptions(track.id,null,{nbSamples:1});}file.start();};
 file.onSamples=(id,_user,batch)=>{for(const sample of batch)samples.push({...sample,data:new Uint8Array(sample.data).slice(),track:tracks.get(id)});if(batch.length)file.releaseUsedSamples(id,batch[batch.length-1].number+1);};
 const data=bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength);data.fileStart=0;file.appendBuffer(data);file.flush();file.stop();
 if(failure)throw failure;if(!samples.length)throw Error('MP4 segment has no extractable samples (tracks='+tracks.size+', boxes='+mp4Boxes(bytes).join(',')+', bytes='+bytes.length+'). Check initialization and byte ranges.');
 return samples;
}
// HLS packed AAC is not MP4. Recognize containers before choosing a parser;
// never send arbitrary/HTML/error responses into MP4Box as if they were media.
function mp4Boxes(bytes){
 const names=[];const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
 for(let p=0;p+8<=bytes.length&&names.length<12;){
  const name=String.fromCharCode(...bytes.subarray(p+4,p+8));if(!/^[a-zA-Z0-9 ]{4}$/.test(name))break;
  let size=view.getUint32(p);if(size===1){if(p+16>bytes.length)break;size=view.getUint32(p+8)*4294967296+view.getUint32(p+12);}
  names.push(name);if(size===0)break;if(size<8||!Number.isSafeInteger(size))break;p+=size;
 }return names;
}
function mediaPayload(bytes){
 let at=0;
 while(at+3<=bytes.length&&bytes[at]===73&&bytes[at+1]===68&&bytes[at+2]===51){
  if(at+10>bytes.length)throw Error('Truncated HLS ID3 header');
  const size=bytes.subarray(at+6,at+10);if(size.some(n=>n&128))throw Error('Invalid HLS ID3 length');
  const length=10+size.reduce((n,v)=>n*128+v,0)+((bytes[at+5]&16)?10:0);
  if(at+length>bytes.length)throw Error('Truncated HLS ID3 metadata');at+=length;
 }return bytes.subarray(at);
}
// Packed HLS audio carries its first PTS in ID3 PRIV, not in ADTS.
function packedTimestamp(bytes){
 const u32=p=>((bytes[p]*16777216)+(bytes[p+1]<<16)+(bytes[p+2]<<8)+bytes[p+3]);
 const sync=p=>{if(p+4>bytes.length||[0,1,2,3].some(i=>bytes[p+i]&128))return NaN;return bytes[p]*2097152+bytes[p+1]*16384+bytes[p+2]*128+bytes[p+3];};
 for(let at=0;at+10<=bytes.length&&bytes[at]===73&&bytes[at+1]===68&&bytes[at+2]===51;){
  const version=bytes[at+3],size=sync(at+6),end=at+10+size;if(!Number.isFinite(size)||end>bytes.length)return null;
  if((version===3||version===4)&&!(bytes[at+5]&128)){
   let pos=at+10;if(bytes[at+5]&64){const n=version===4?sync(pos):u32(pos)+4;if(!Number.isFinite(n)||n<4||pos+n>end)return null;pos+=n;}
   while(pos+10<=end){const n=version===4?sync(pos+4):u32(pos+4);if(!Number.isFinite(n)||n<=0||pos+10+n>end)break;
    if(bytes[pos]===80&&bytes[pos+1]===82&&bytes[pos+2]===73&&bytes[pos+3]===86&&!bytes[pos+8]&&!bytes[pos+9]){
     const owner='com.apple.streaming.transportStreamTimestamp';let q=pos+10,match=true;for(let i=0;i<owner.length;i++)if(bytes[q+i]!==owner.charCodeAt(i))match=false;q+=owner.length;
     if(match&&bytes[q]===0&&q+9<=pos+10+n){q++;if(!bytes[q]&&!bytes[q+1]&&!bytes[q+2]&&!(bytes[q+3]&254))return ((bytes[q+3]&1)*4294967296+u32(q+4))/90000;}
    }pos+=10+n;
   }
  }at=end+((version===4&&(bytes[at+5]&16))?10:0);
 }return null;
}
function demuxADTS(bytes,timestamp){
 const rates=[96000,88200,64000,48000,44100,32000,24000,22050,16000,12000,11025,8000,7350],samples=[];let at=0,clock=0,track=null;
 while(at<bytes.length){
  if(bytes[at]===73&&bytes[at+1]===68&&bytes[at+2]===51){const rest=mediaPayload(bytes.subarray(at));at=bytes.length-rest.length;continue;}
  if(bytes.length-at<7||bytes[at]!==255||(bytes[at+1]&246)!==240){if(bytes.subarray(at).every(v=>v===0))break;throw Error('Malformed AAC/ADTS frame at byte '+at);}
  const rateIndex=(bytes[at+2]>>2)&15,rate=rates[rateIndex],profile=(bytes[at+2]>>6)+1,channels=((bytes[at+2]&1)<<2)|(bytes[at+3]>>6),header=(bytes[at+1]&1)?7:9;
  const length=((bytes[at+3]&3)<<11)|(bytes[at+4]<<3)|(bytes[at+5]>>5);
  if(!rate||!channels||(bytes[at+6]&3))throw Error('Unsupported AAC/ADTS configuration');
  if(length<=header||at+length>bytes.length)throw Error('Truncated AAC/ADTS frame');
  if(!track)track={codec:'mp4a.40.'+profile,audio:{sample_rate:rate,channel_count:channels===7?8:channels},description:new Uint8Array([(profile<<3)|(rateIndex>>1),((rateIndex&1)<<7)|(channels<<3)])};
  if(track.audio.sample_rate!==rate||track.codec!=='mp4a.40.'+profile||track.audio.channel_count!==(channels===7?8:channels))throw Error('AAC configuration changed inside a segment');
  const pts=(timestamp===null?0:timestamp*rate)+clock;samples.push({cts:pts,dts:pts,timescale:rate,duration:1024,is_sync:true,data:bytes.subarray(at+header,at+length),track});clock+=1024;at+=length;
 }
 if(!samples.length)throw Error('AAC segment has no complete frames');samples.packedAudio=true;samples.packedTimestamp=timestamp;return samples;
}
function demux(bytes,init){
 const payload=mediaPayload(bytes),boxes=mp4Boxes(payload);
 if(boxes.length&&['ftyp','styp','moof','moov','sidx','emsg','free','skip','mdat','prft'].includes(boxes[0]))return demuxMP4(init?join([init,payload]):payload);
 const ts=payload[0]===0x47&&(payload.length<189||payload[188]===0x47);
 const aac=payload.length>=7&&payload[0]===0xff&&(payload[1]&0xf6)===0xf0;
 if(aac)return demuxADTS(payload,packedTimestamp(bytes));
 if(!ts&&!aac)throw Error('Unsupported HLS segment format (bytes='+bytes.length+', init='+(init?.length||0)+'). Expected MPEG-TS, fragmented MP4 or AAC/ADTS.');
 const muxer=new muxjs.mp4.Transmuxer({keepOriginalTimestamps:true,remux:true}),parts=[];
 try{
  muxer.on('data',part=>parts.push(...demuxMP4(join([part.initSegment,part.data]))));
  muxer.push(payload);muxer.flush();
 }finally{muxer.dispose();}
 if(!parts.length)throw Error((aac?'AAC':'MPEG-TS')+' segment produced no samples (bytes='+payload.length+')');return parts;
}
class CanvasPlayer {
 static supported(){return !!(self.isSecureContext&&self.VideoDecoder&&self.AudioDecoder&&self.EncodedVideoChunk&&self.EncodedAudioChunk);}
 constructor(canvas,{onerror=()=>{},quality='hd',audioContext=null,bufferSeconds=0}={}){
  this.canvas=canvas;this.ctx=canvas.getContext('2d',{alpha:false});if(!this.ctx)throw Error('Canvas rendering unavailable');
  this.audioContext=audioContext;this.ownsAudioContext=!audioContext;this.audioTail=null;
  this.bufferSeconds=Math.max(0,Math.min(2,Number(bufferSeconds)||0));this.bufferReadyAt=0;this.preparedVideoEnd=0;
  this.quality=quality;this.offeredHeights=[];this.selectedHeight=0;this.onerror=onerror;this.paused=true;this.muted=true;this.duration=0;this.readyState=0;this.ended=false;this.error=null;this.closed=false;
  this.frames=[];this.audio=[];this.nodes=new Set();this.timelines=new Map();this.segmentDiagnostics=[];this.segmentCache=new Map();this.playbackEvents=[];this.audioEnd=0;this.lastAudioSampleRate=0;this.hasAudio=false;this.videoStarved=false;this.position=0;this.videoEnd=0;this.anchor=0;this.running=false;this.serial=0;this.videoNeedsKey=false;this.videoRecoveryAt=-Infinity;this.lastVideoDrawAt=performance.now();this.videoGeneration=0;this.videoRecoveryWindow=0;this.videoRecoveryCount=0;this.videoRetryAfter=0;this.decoders=new Map();this.configs=new Map();this.initializers=new Map();
  this.stats={drawn:0,dropped:0,decoded:0,audioDecoded:0,maxFrames:0,maxAudio:0,audioScheduled:0,audioLate:0,audioJoined:0,audioRestored:0,bufferWaitMs:0,rebufferCount:0,timestampResets:0,directAudioCopies:0,audioGapMs:0,maxAudioNodes:0,videoHiccups:0,audioUnderruns:0,staleAudioDropped:0,maxSegmentCache:0,audioDecoderFlushes:0,videoRecoveries:0,staleVideoDropped:0,videoQueueTimeouts:0};
  this.profileStart=performance.now();this.profileBuckets=[];this.profileEvents=[];this.lastProfilePaintAt=0;
  this.profileDocument=self.document||null;this.profileVisibilityReset=()=>{this.lastProfilePaintAt=0;};
  this.profileDocument?.addEventListener?.('visibilitychange',this.profileVisibilityReset);
  this.animation=requestAnimationFrame(()=>this.paint());
  // Audio look-ahead must not depend on Canvas animation callbacks.
  this.audioTimer=setInterval(()=>{if(!this.closed&&!this.paused&&this.running){try{this.scheduleAudio(this.currentTime);this.checkVideoProgress();}catch(error){this.fail(error);}}},20);
 }
 profileMetric(name,value,detail={}){
  if(this.closed||!Number.isFinite(value)||value<0)return;
  const at=performance.now(),slot=Math.floor(at/5000);
  let bucket=this.profileBuckets[this.profileBuckets.length-1];
  if(!bucket||bucket.slot!==slot){bucket={slot,metrics:{}};this.profileBuckets.push(bucket);if(this.profileBuckets.length>12)this.profileBuckets.shift();}
  const metric=bucket.metrics[name]||(bucket.metrics[name]={count:0,total:0,max:0,maxAtMs:0,mediaTime:0});
  metric.count++;metric.total+=value;
  if(value>=metric.max){metric.max=value;metric.maxAtMs=at-this.profileStart;metric.mediaTime=this.currentTime;}
  // Bounded event history correlates slow work; thresholds select detail only,
  // and are not claims that a particular duration causes a playback failure.
  if(name==='demuxMs'||(name==='decoderWaitMs'&&value>=10)||(name==='renderCallbackGapMs'&&value>=80)||(name==='canvasDrawMs'&&value>=16)){
   this.profileEvents.push({metric:name,value,atMs:at-this.profileStart,mediaTime:this.currentTime,...detail});
   if(this.profileEvents.length>60)this.profileEvents.shift();
  }
 }
 performanceProfile(){
  const now=performance.now(),metrics={};
  for(const bucket of this.profileBuckets){if((bucket.slot+1)*5000<=now-60000)continue;for(const [name,m] of Object.entries(bucket.metrics)){
   const out=metrics[name]||(metrics[name]={count:0,total:0,max:0,maxAtMs:0,mediaTime:0});out.count+=m.count;out.total+=m.total;
   if(m.max>=out.max){out.max=m.max;out.maxAtMs=m.maxAtMs;out.mediaTime=m.mediaTime;}
  }}
  for(const m of Object.values(metrics)){m.mean=m.total/m.count;delete m.total;}
  return {windowSeconds:60,elapsedMs:now-this.profileStart,visibility:this.profileDocument?.visibilityState||'unknown',metrics,
   videoQueueDepth:this.decoders.get('video')?.decodeQueueSize||0,framesQueued:this.frames.length,
   events:this.profileEvents.filter(e=>e.atMs>=now-this.profileStart-60000).map(e=>({...e}))};
 }
 clock(){return this.audioContext?.state==='running'?this.audioContext.currentTime:performance.now()/1000;}
 audible(){return !this.muted&&this.hasAudio&&this.audioContext?.state==='running';}
 mediaEnd(){return this.audible()?this.audioEnd:this.videoEnd;}
 get currentTime(){return this.running&&!this.paused?Math.max(this.position,Math.min(this.duration,Math.max(this.position,this.mediaEnd()),this.position+this.clock()-this.anchor)):this.position;}
 set currentTime(value){this.seek(value);}
 async requestBytes(url,range,allowFull=false){
  const absolute=new URL(url,location.href);if(absolute.origin!==location.origin)throw Error('Media must use the ScreenLink proxy');
  const outer=this.abort.signal;
  for(let attempt=0;;attempt++){
   if(outer.aborted)throw new DOMException('Playback replaced','AbortError');
   const control=new AbortController(),cancel=()=>control.abort();outer.addEventListener('abort',cancel,{once:true});const timer=setTimeout(()=>control.abort(),15000);
   try{const response=await fetch(absolute,{signal:control.signal,cache:'no-store',headers:range?{Range:`bytes=${range.start}-${range.end}`}:{}});
    if(!response.ok){const e=Error('Media HTTP '+response.status);e.status=response.status;throw e;}
    if(range&&response.status!==206&&!(allowFull&&response.status===200))throw Error('Media server did not honor byte range');
    const bytes=new Uint8Array(await response.arrayBuffer());bytes.httpStatus=response.status;bytes.contentRange=response.headers.get('Content-Range');this.lastTransportError=null;return bytes;
   }catch(error){
    if(outer.aborted)throw new DOMException('Playback replaced','AbortError');
    const transient=error.name==='AbortError'||error instanceof TypeError||[408,429,500,502,503,504].includes(error.status);
    if(!transient)throw error;
    this.stats.fetchRetries=(this.stats.fetchRetries||0)+1;this.lastTransportError={message:error.message,time:Date.now(),attempt:attempt+1};
    // Retry the same bytes. Keep decoders, PCM, frames and the playback clock.
    // The normal buffer scheduler pauses only when usable media actually runs out.
    if(attempt>=5){const e=Error('Phone/media transport unavailable after retries: '+error.message);e.kind='transport';throw e;}
   }finally{clearTimeout(timer);outer.removeEventListener('abort',cancel);}
   await sleep(Math.min(2000,250*Math.pow(2,attempt)));
  }
 }

 // Keep each phone-side response below the broadcast extension's 6 MB budget.
 async bytes(url,range,segment=false){
  if(!segment)return this.requestBytes(url,range);
  const size=1024*1024,start=range?.start||0;
  let part=await this.requestBytes(url,{start,end:Math.min(range?.end??(start+size-1),start+size-1)},!range);
  const parse=bytes=>/^bytes (\d+)-(\d+)\/(\d+)$/.exec(bytes.contentRange||'');
  let match=parse(part);
  if(!match){if(!range&&part.httpStatus===200)return part;throw Error('Media byte range missing or invalid');}
  const last=range?.end??(Number(match[3])-1),length=last-start+1;
  if(length<=0||length>32*1024*1024)throw Error('Media segment exceeds 32 MB client limit');
  const result=new Uint8Array(length);let at=start;
  for(;;){
   if(!match||Number(match[1])!==at||Number(match[2])-at+1!==part.length||Number(match[2])>last)throw Error('Media byte range is inconsistent');
   result.set(part,at-start);at+=part.length;if(at>last)break;
   part=await this.requestBytes(url,{start:at,end:Math.min(last,at+size-1)});match=parse(part);
  }
  return result;
 }
 async load(url,start=0){
  this.abort=new AbortController();let manifestURL=new URL(url,location.href).href,manifest;
  for(let depth=0;depth<4;depth++){
   manifest=playlist(new TextDecoder().decode(await this.bytes(manifestURL)),manifestURL);
   if(!manifest.variants.length)break;
   this.offeredHeights=[...new Set(manifest.variants.map(v=>Number((v.RESOLUTION||'').split('x')[1])||0).filter(n=>n>0))].sort((a,b)=>b-a);
   const choice=chooseVariant(manifest.variants,this.quality);this.selectedHeight=Number((choice.RESOLUTION||'').split('x')[1])||0;
   const audio=manifest.audio.filter(a=>a['GROUP-ID']===choice.AUDIO);this.audioURL=(audio.find(a=>a.DEFAULT==='YES')||audio[0])?.url;manifestURL=choice.url;
  }
  if(manifest.variants.length||!manifest.segments.length||!manifest.end)throw Error('Live or nested HLS needs the compatibility player');
  this.videoList=manifest;this.duration=manifest.duration;
  if(this.audioURL){const list=playlist(new TextDecoder().decode(await this.bytes(this.audioURL)),this.audioURL);if(list.variants.length||!list.end)throw Error('Unsupported alternate audio playlist');this.audioList=list;}
  await this.seek(start);return this;
 }
 fail(error){if(this.closed||error?.name==='AbortError')return;this.error={code:3,message:error.message||String(error)};this.pause();this.onerror(error);}
 async configure(track,kind,serial){
  if(kind==='video'&&Math.min(track.video.width,track.video.height)>1080)throw Error('Source exceeds the 1080p playback limit.');
  const config=kind==='video'?{codec:track.codec,codedWidth:track.video.width,codedHeight:track.video.height,description:track.description,hardwareAcceleration:'prefer-hardware'}:{codec:track.codec,sampleRate:track.audio.sample_rate,numberOfChannels:track.audio.channel_count,description:track.description};
  if(config.codec.toLowerCase()==='opus'){config.codec='opus';delete config.description;}
  const key=JSON.stringify({...config,description:config.description?Array.from(config.description):[]});
  if(this.configs.get(kind)===key&&this.decoders.get(kind)?.state==='configured')return this.decoders.get(kind);
  const videoGeneration=this.videoGeneration;
  // Browser implementations may accept a codec while declining the hardware hint.
  const Type=kind==='video'?VideoDecoder:AudioDecoder;
  let supported=await Type.isConfigSupported(config);if(!supported.supported&&kind==='video'){delete config.hardwareAcceleration;supported=await Type.isConfigSupported(config);}
  if(serial!==this.serial||this.closed)throw new DOMException('Playback replaced','AbortError');
  if(!supported.supported)throw Error('Unsupported '+kind+' codec '+track.codec);
  if(kind==='video'&&videoGeneration!==this.videoGeneration)return null;
  const old=this.decoders.get(kind);if(old){if(kind==='audio'){await old.flush();this.stats.audioDecoderFlushes++;}if(old.state!=='closed')old.close();}
  const decoder=new Type({output:frame=>{if(serial!==this.serial||this.decoders.get(kind)!==decoder){frame.close();return;}this.output(kind,frame);},error:error=>{
   if(serial!==this.serial||this.decoders.get(kind)!==decoder)return;
   if(kind==='video'&&this.audible()&&this.running){this.resetVideo('decoder-error');return;}this.fail(error);
  }});decoder.configure(config);this.decoders.set(kind,decoder);this.configs.set(kind,key);return decoder;
 }
 output(kind,data){
  if(this.closed){data.close();return;}
  if(kind==='video'){
   this.stats.decoded++;this.videoEnd=Math.max(this.videoEnd,(data.timestamp+(data.duration||33333))/1e6);if(data.timestamp/1e6<this.currentTime-0.10){this.stats.staleVideoDropped++;data.close();return;}
   this.frames.push(data);this.frames.sort((a,b)=>a.timestamp-b.timestamp);this.stats.maxFrames=Math.max(this.stats.maxFrames,this.frames.length);
   while(this.frames.length>48){this.frames.pop().close();this.stats.dropped++;}
  }else{
   const mediaNow=this.currentTime;this.stats.audioDecoded++;
   if(!this.hasAudio){if(this.running&&!this.muted&&this.audioContext?.state==='running'){this.position=mediaNow;this.running=false;this.stopAudio(true);}this.hasAudio=true;this.audioEnd=Math.max(this.audioEnd,this.position);}
   const end=(data.timestamp+data.duration)/1e6;
   if(end<this.position||end<mediaNow-.8){this.stats.staleAudioDropped++;data.close();return;}this.audioEnd=Math.max(this.audioEnd,end);
   // Copy decoded planes directly into the final Web Audio buffer.
   try{
    const buffer=new AudioBuffer({numberOfChannels:data.numberOfChannels,length:data.numberOfFrames,sampleRate:data.sampleRate});
    for(let channel=0;channel<data.numberOfChannels;channel++)data.copyTo(buffer.getChannelData(channel),{planeIndex:channel,format:'f32-planar'});
    this.lastAudioSampleRate=data.sampleRate;this.audio.push({timestamp:data.timestamp/1e6,sampleRate:data.sampleRate,frames:data.numberOfFrames,buffer});this.stats.directAudioCopies++;
   }finally{data.close();}
   this.stats.maxAudio=Math.max(this.stats.maxAudio,this.audio.length);if(this.audio.length>512)this.fail(Error('Audio buffer exceeded its limit'));
  }
  if(kind==='video')this.readyState=2;
 }
 checkVideoProgress(){
  // Detect a decoder that accepts input but stops producing frames. Preserve
  // the audio clock and recover at a real source keyframe, never a fake frame.
  if(!this.audible()||!this.running||this.paused||this.finished||this.frames.length||!this.decoders.has('video')){
   this.lastVideoDrawAt=performance.now();return;
  }
  if(this.preparedVideoEnd>this.currentTime+.25&&performance.now()-this.lastVideoDrawAt>3000){
   this.lastVideoDrawAt=performance.now();this.resetVideo('output-stall');
  }
 }
 resetVideo(reason){
  this.videoGeneration++;const now=performance.now();
  if(now-this.videoRecoveryWindow>10000){this.videoRecoveryWindow=now;this.videoRecoveryCount=0;}
  if(++this.videoRecoveryCount>4)this.videoRetryAfter=now+3000;
  const decoder=this.decoders.get('video');this.decoders.delete('video');this.configs.delete('video');
  if(decoder&&decoder.state!=='closed')decoder.close();
  for(const frame of this.frames)frame.close();this.frames=[];this.videoNeedsKey=true;
  this.stats.videoRecoveries++;this.recordPlayback('video-recovery-'+reason,this.currentTime);
  // Audio nodes, sample clock, decoded PCM, transport and user quality stay intact.
 }
 async prepareSegment(segment,serial=this.serial){
  const fetchStart=performance.now();let init=null;if(segment.map){const key=JSON.stringify(segment.map);if(!this.initializers.has(key))this.initializers.set(key,await this.bytes(segment.map.url,segment.map.range));init=this.initializers.get(key);}
  if(serial!==this.serial||this.closed)throw new DOMException('Playback replaced','AbortError');
  const bytes=await this.bytes(segment.url,segment.range,true);return {init,bytes,fetchMs:performance.now()-fetchStart};
 }
 async decodeSegment(segment,kind,serial,prepared=null,allowEmpty=false){
  const {init,bytes,fetchMs=0}=prepared||await this.prepareSegment(segment,serial);if(serial!==this.serial||this.closed)return;
  const demuxStart=performance.now(),reusedDemux=!!prepared?.samples;let extracted;try{if(prepared?.samples)extracted=prepared.samples;else{extracted=demux(bytes,init);if(prepared)prepared.samples=extracted;}}catch(error){throw Error('HLS '+kind+' segment at '+segment.start.toFixed(2)+'s: '+error.message);}
  const demuxMs=performance.now()-demuxStart;if(!reusedDemux)this.profileMetric('demuxMs',demuxMs,{segmentStart:segment.start,bytes:bytes.length});

  const samples=extracted.filter(s=>s.track&&(kind==='all'||(kind==='audio'?!!s.track.audio:!!s.track.video))).sort((a,b)=>(a.dts??a.cts)/a.timescale-(b.dts??b.cts)/b.timescale);
  if(!samples.length){if(allowEmpty)return;throw Error('Selected HLS track has no samples');}
  // Preserve inter-track offsets; normalize each fragment onto its playlist timeline.
  const origin=Math.min(...extracted.map(s=>s.cts/s.timescale));
  let timeline=this.timelines.get(kind);
  const reset=timeline&&(origin<timeline.lastOrigin-.1||(segment.start>timeline.lastSegmentStart&&origin<=timeline.lastOrigin+.001));
  const packedFallback=extracted.packedAudio&&(extracted.packedTimestamp===null||reset);
  if(timeline&&packedFallback&&!segment.discontinuity){timeline.offset=timeline.end-origin;this.stats.timestampResets++;}
  else if(!timeline||segment.discontinuity||reset){timeline={offset:segment.start-origin,lastOrigin:origin,lastSegmentStart:segment.start};this.timelines.set(kind,timeline);if(reset)this.stats.timestampResets++;}
  timeline.end=Math.max(...samples.map(s=>(s.cts+s.duration)/s.timescale))+timeline.offset;
  timeline.lastOrigin=origin;timeline.lastSegmentStart=segment.start;
  // A real discontinuity may start a new AAC coding history. Continuous
  // HLS segments must keep the same decoder overlap/filter-bank state.
  if(segment.discontinuity&&(kind==='audio'||kind==='all'))this.configs.delete('audio');
  const mapping=timeline.offset;
  const diagnostic={audioTiming:extracted.packedAudio?(packedFallback?'sample-count':'id3-pts'):'container-pts',mappedEnd:timeline.end,fetchMs,demuxMs,kind,start:segment.start,duration:segment.duration,sourceStart:origin,mappedStart:origin+mapping,reset:!!reset,video:0,audio:0};
  for(const sample of samples)diagnostic[sample.track.video?'video':'audio']++;
  this.segmentDiagnostics.push(diagnostic);if(this.segmentDiagnostics.length>8)this.segmentDiagnostics.shift();
  // Audio must keep filling its look-ahead while video waits for Canvas space.
  // Each lane retains source decode order and the shared mapped timeline.
  const consume=async lane=>{
   for(const sample of lane){
   if(serial!==this.serial||this.closed)return;
   const type=sample.track.video?'video':'audio';
   const sampleTime=mapping+sample.cts/sample.timescale;
   if(type==='video'&&performance.now()<this.videoRetryAfter){this.stats.staleVideoDropped++;continue;}
   if(type==='video'&&this.audible()&&this.running&&sampleTime<this.currentTime-.75){
    if(!this.videoNeedsKey)this.resetVideo('catch-up');
    this.stats.staleVideoDropped++;continue;
   }
   if(type==='video'&&this.videoNeedsKey&&!sample.is_sync){this.stats.staleVideoDropped++;continue;}
   let decoder=await this.configure(sample.track,type,serial);
   if(!decoder)continue;
   const timestamp=Math.round((mapping+sample.cts/sample.timescale)*1e6),duration=Math.max(1,Math.round(sample.duration/sample.timescale*1e6));
   const Chunk=type==='video'?EncodedVideoChunk:EncodedAudioChunk;
   if(serial!==this.serial||this.closed)return;
   while((type==='video'&&this.frames.length>12)||(type==='audio'&&this.audio.length>128)){if(serial!==this.serial||this.closed)return;await sleep(10);}
   if(serial!==this.serial||this.closed)return;
   if(type==='video'){
    if(this.decoders.get(type)!==decoder||decoder.state!=='configured'||this.videoNeedsKey){
     if(!sample.is_sync){this.stats.staleVideoDropped++;continue;}
     decoder=await this.configure(sample.track,type,serial);
     if(serial!==this.serial||this.closed)return;
     if(!decoder||this.decoders.get(type)!==decoder||decoder.state!=='configured')continue;
    }
    this.videoNeedsKey=false;
   }
   try{decoder.decode(new Chunk({type:type==='audio'||sample.is_sync?'key':'delta',timestamp,duration,data:sample.data}));}
   catch(error){if(type==='video'&&this.audible()&&this.running){this.resetVideo('decode-error');continue;}throw error;}
   const queuedAt=performance.now(),queueBefore=decoder.decodeQueueSize;
   if(type==='video')this.profileMetric('videoQueueDepth',queueBefore);
   while(decoder.state==='configured'&&decoder.decodeQueueSize>12){
    if(serial!==this.serial||this.closed)return;
    if(type==='video'&&this.audible()&&this.running&&performance.now()-queuedAt>1500){
     this.stats.videoQueueTimeouts++;this.resetVideo('queue-timeout');break;
    }
    await sleep(5);
   }
   if(type==='video'&&queueBefore>12)this.profileMetric('decoderWaitMs',performance.now()-queuedAt,{queueBefore});
  }
  };
  await Promise.all([consume(samples.filter(s=>s.track.video)),consume(samples.filter(s=>s.track.audio))]);
  if(serial!==this.serial||this.closed)return;
  // Keep reference/reorder state across continuous HLS segments. A flush
  // here would require the next segment to begin with a key chunk.

 }
 async preparedSegment(segment,serial,owners){
  while(serial===this.serial&&!this.closed&&!this.segmentCache.has(segment)&&this.segmentCache.size>=6)await sleep(10);
  if(serial!==this.serial||this.closed)throw new DOMException('Playback replaced','AbortError');
  let entry=this.segmentCache.get(segment);
  if(!entry){entry={remaining:new Set(owners),promise:this.prepareSegment(segment,serial).then(data=>{if(serial===this.serial&&!this.closed&&owners.includes('video'))this.preparedVideoEnd=Math.max(this.preparedVideoEnd,segment.start+segment.duration);return {data};},error=>({error}))};this.segmentCache.set(segment,entry);this.stats.maxSegmentCache=Math.max(this.stats.maxSegmentCache,this.segmentCache.size);}
  return {entry,result:await entry.promise};
 }
 releaseSegment(segment,entry,kind){entry.remaining.delete(kind);if(!entry.remaining.size&&this.segmentCache.get(segment)===entry)this.segmentCache.delete(segment);}
 async seek(value){
  if(!this.videoList||this.closed)return;this.serial++;const serial=this.serial;
  this.abort?.abort();this.abort=new AbortController();this.position=Math.max(0,Math.min(Number(value)||0,Math.max(0,this.duration-0.01)));this.videoEnd=this.position;this.anchor=this.clock();this.running=false;this.ended=false;this.readyState=0;this.release();this.timelines.clear();this.audioEnd=this.position;this.hasAudio=false;this.videoStarved=false;this.videoNeedsKey=false;
  const run=async()=>{
   // Interleave muxed samples by decode time; independently pace alternate tracks.
   // Otherwise a bounded video queue can starve audio while waiting for drawing.
   const consume=async(list,kind,owners,allowEmpty=false)=>{
    const segments=list.segments.filter(s=>s.start+s.duration>this.position);
    const fetchAt=index=>this.preparedSegment(segments[index],serial,owners).then(value=>value,error=>({result:{error}}));
    let pending=segments.length?fetchAt(0):null;
    for(let index=0;index<segments.length;index++){
     const segment=segments[index];
     while(serial===this.serial&&!this.closed&&segment.start>this.currentTime+(kind==='audio'?4:2))await sleep(30);
     if(serial!==this.serial||this.closed)return;
     const {entry,result}=await pending;if(serial!==this.serial||this.closed)return;if(result.error)throw result.error;
     if(kind==='video')this.preparedVideoEnd=Math.max(this.preparedVideoEnd,segment.start+segment.duration);
     pending=index+1<segments.length?fetchAt(index+1):null;
     try{await this.decodeSegment(segment,kind,serial,result.data,allowEmpty);}finally{this.releaseSegment(segment,entry,kind);}
    }
    // Drain only at end of rendition, including final reordered video frames.
    if(serial===this.serial&&!this.closed){
     const decoder=this.decoders.get(kind);
     if(decoder?.state==='configured'){
      if(kind==='audio'){await decoder.flush();this.stats.audioDecoderFlushes++;}
      else {
       let timer;
       try{await Promise.race([decoder.flush(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Video end flush deadline')),2000);})]);}
       catch(error){if(serial!==this.serial||this.closed)return;if(this.audible()&&this.running)this.resetVideo('end-flush-timeout');else throw error;}
       finally{clearTimeout(timer);}
      }
     }
    }
   };
   if(this.audioList)await Promise.all([consume(this.videoList,'video',['video']),consume(this.audioList,'audio',['audio'])]);
   else await Promise.all([consume(this.videoList,'video',['video','audio'],true),consume(this.videoList,'audio',['video','audio'],true)]);
   if(serial===this.serial)this.finished=true;
  };
  this.bufferReadyAt=performance.now()/1000+this.bufferSeconds;this.preparedVideoEnd=this.position;
  this.finished=false;run().catch(error=>{if(serial===this.serial)this.fail(error);});
 }
 startClock(){this.anchor=this.clock()+.04;this.running=true;}
 canStart(){if(performance.now()/1000<this.bufferReadyAt)return false;const reserve=Math.min(this.bufferSeconds,Math.max(0,this.duration-this.position));if(this.bufferSeconds&&this.preparedVideoEnd-this.position+1e-5<reserve&&!this.finished)return false;const video=this.readyState>=2&&(this.videoEnd-this.position>=.12||this.finished);return video&&(!this.audible()||this.audioEnd-this.position>=Math.max(.6,reserve)||this.finished);}
 async play(){if(this.closed)return;this.paused=false;if(this.canStart()&&!this.running)this.startClock();}
 pause(){this.position=this.currentTime;this.paused=true;this.running=false;this.stopAudio(true);}
 stopAudio(restore=false){
  const now=this.audioContext?.currentTime||0;
  for(const node of this.nodes){
   const packet=node.screenlinkPacket;
   if(restore&&packet&&packet.timestamp+packet.frames/packet.sampleRate>this.position){this.audio.push(packet);this.stats.audioRestored++;}
   node.onended=()=>{node.screenlinkPacket=null;try{node.disconnect();node.fadeGain?.disconnect();}catch{}};
   try{
    if(this.audioContext?.state==='running'&&node.fadeGain){const gain=node.fadeGain.gain;gain.cancelScheduledValues(now);gain.setValueAtTime(gain.value,now);gain.linearRampToValueAtTime(0,now+.008);node.stop(now+.01);}
    else{node.stop();node.disconnect();node.fadeGain?.disconnect();}
   }catch{}
  }
  this.nodes.clear();this.audioTail=null;
  if(restore){this.audio.sort((a,b)=>a.timestamp-b.timestamp);this.stats.maxAudio=Math.max(this.stats.maxAudio,this.audio.length);}
 }
 async enableAudio(sharedContext=null){
  const position=this.currentTime;
  this.position=position;this.stopAudio(true);
  if(sharedContext&&!this.audioContext){this.audioContext=sharedContext;this.ownsAudioContext=false;}
  if(!this.audioContext)this.audioContext=new AudioContext({sampleRate:this.lastAudioSampleRate||44100});
  if(!this.gain){this.gain=this.audioContext.createGain();this.low=this.audioContext.createBiquadFilter();this.low.type='lowshelf';this.low.frequency.value=180;this.high=this.audioContext.createBiquadFilter();this.high.type='highshelf';this.high.frequency.value=3500;this.gain.connect(this.low).connect(this.high).connect(this.audioContext.destination);}
  await this.audioContext.resume();this.position=position;this.anchor=this.clock()+.04;this.muted=false;this.gain.gain.value=1;await this.play();
 }
 setEQ(mode){if(this.low){this.low.gain.value=mode==='music'?3:0;this.high.gain.value=mode==='music'?2:0;}}
 scheduleAudio(now){
  if(this.closed||this.paused||!this.running)return;
  // Retain future decoded PCM while muted, so enabling sound does not lose
  // the entire look-ahead window. Expired packets can still be discarded.
  while(this.audio.length&&this.audio[0].timestamp+this.audio[0].frames/this.audio[0].sampleRate<=now)this.audio.shift();
  if(this.muted||!this.audioContext||this.audioContext.state!=='running')return;
  const contextNow=this.audioContext.currentTime,base=this.anchor-this.position;
  while(this.audio.length&&this.audio[0].timestamp<now+4&&this.nodes.size<256){
   const packet=this.audio.shift(),duration=packet.frames/packet.sampleRate;
   let start=base+packet.timestamp;
   // One absolute sample clock for all chunks. Snap small AAC boundary
   // rounding/normalization differences to the preceding PCM sample's end.
   if(this.audioTail!==null&&Math.abs(start-this.audioTail)<=Math.min(0.04,duration*1.5)){
    if(Math.abs(start-this.audioTail)>1/packet.sampleRate)this.stats.audioJoined++;
    start=this.audioTail;
   }
   if(this.audioTail!==null&&start-this.audioTail>.001)this.stats.audioGapMs+=(start-this.audioTail)*1000;
   const offset=Math.max(0,contextNow+0.02-start);
   if(offset>=duration){this.stats.audioLate++;continue;}
   if(offset>0){start+=offset;this.stats.audioLate++;}
   const node=this.audioContext.createBufferSource(),fade=this.audioContext.createGain();fade.gain.value=1;node.buffer=packet.buffer;node.connect(fade);fade.connect(this.gain);node.fadeGain=fade;node.screenlinkPacket=packet;this.nodes.add(node);
   node.onended=()=>{this.nodes.delete(node);node.screenlinkPacket=null;node.disconnect();fade.disconnect();};
   node.start(start,offset);this.audioTail=start+duration-offset;this.stats.audioScheduled++;this.stats.maxAudioNodes=Math.max(this.stats.maxAudioNodes,this.nodes.size);
  }
 }
 recordPlayback(type,position){this.playbackEvents.push({type,position,audioLead:this.audioContext&&this.audioTail!==null?Math.max(0,this.audioTail-this.audioContext.currentTime):0,videoLead:Math.max(0,this.videoEnd-position)});if(this.playbackEvents.length>12)this.playbackEvents.shift();}
 paint(){
  if(this.closed)return;
  const profileNow=performance.now(),visible=this.profileDocument?.visibilityState!=='hidden';
  if(!this.paused&&this.running&&visible&&this.lastProfilePaintAt)this.profileMetric('renderCallbackGapMs',profileNow-this.lastProfilePaintAt);
  this.lastProfilePaintAt=visible?profileNow:0;
  if(!this.paused){
   if(this.canStart()&&!this.running)this.startClock();
   const now=this.currentTime,raw=this.position+this.clock()-this.anchor,end=this.mediaEnd();
   if(this.running&&!this.finished&&raw>end+.005){this.stats.bufferWaitMs+=Math.max(0,(raw-end)*1000);this.position=now;this.running=false;this.stats.rebufferCount++;if(this.audible())this.stats.audioUnderruns++;this.recordPlayback('buffer-empty',now);this.stopAudio(true);}
   const held=this.running&&this.audible()&&raw>this.videoEnd+.05;
   if(held&&!this.videoStarved){this.stats.videoHiccups++;this.recordPlayback('video-hold-audio-continues',now);}this.videoStarved=held;let frame=null;
   while(this.frames.length&&this.frames[0].timestamp/1e6<=now+0.015){if(frame){frame.close();this.stats.dropped++;}frame=this.frames.shift();}
   if(frame){try{if(this.canvas.width!==frame.displayWidth||this.canvas.height!==frame.displayHeight){this.canvas.width=frame.displayWidth;this.canvas.height=frame.displayHeight;}const drawStart=performance.now();this.ctx.drawImage(frame,0,0,this.canvas.width,this.canvas.height);this.profileMetric('canvasDrawMs',performance.now()-drawStart);this.stats.drawn++;this.lastVideoDrawAt=performance.now();}catch(error){this.fail(error);}finally{frame.close();}}
   this.scheduleAudio(now);
   if(this.finished&&now>=this.duration-0.02){this.pause();this.position=this.duration;this.ended=true;}
  }
  this.animation=requestAnimationFrame(()=>this.paint());
 }
 release(){
  for(const frame of this.frames)frame.close();this.frames=[];this.audio=[];
  for(const decoder of this.decoders.values())if(decoder.state!=='closed')decoder.close();this.decoders.clear();this.configs.clear();
  this.stopAudio();this.segmentCache.clear();
 }
 destroy(){if(this.closed)return;this.profileDocument?.removeEventListener?.('visibilitychange',this.profileVisibilityReset);this.closed=true;this.serial++;this.abort?.abort();cancelAnimationFrame(this.animation);clearInterval(this.audioTimer);this.release();this.initializers.clear();const cleanup=()=>{if(this.ownsAudioContext)this.audioContext?.close();else{this.gain?.disconnect();this.low?.disconnect();this.high?.disconnect();}};if(this.gain&&this.audioContext?.state==='running')setTimeout(cleanup,12);else cleanup();}
}
self.ScreenLinkCanvas={CanvasPlayer,playlist,demux,chooseVariant};
})();
