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
 if(failure)throw failure;if(!samples.length)throw Error('No decodable samples in media segment');
 return samples;
}
function demux(bytes,init){
 if(bytes[0]!==0x47)return demuxMP4(init?join([init,bytes]):bytes);
 const muxer=new muxjs.mp4.Transmuxer({keepOriginalTimestamps:true,remux:true}),parts=[];
 muxer.on('data',part=>parts.push(...demuxMP4(join([part.initSegment,part.data]))));muxer.push(bytes);muxer.flush();muxer.dispose();
 if(!parts.length)throw Error('Unsupported transport stream');return parts;
}
class CanvasPlayer {
 static supported(){return !!(self.isSecureContext&&self.VideoDecoder&&self.AudioDecoder&&self.EncodedVideoChunk&&self.EncodedAudioChunk);}
 constructor(canvas,{onerror=()=>{}}={}){
  this.canvas=canvas;this.ctx=canvas.getContext('2d',{alpha:false});if(!this.ctx)throw Error('Canvas rendering unavailable');
  this.onerror=onerror;this.paused=true;this.muted=true;this.duration=0;this.readyState=0;this.ended=false;this.error=null;this.closed=false;
  this.frames=[];this.audio=[];this.nodes=new Set();this.position=0;this.anchor=0;this.running=false;this.serial=0;this.decoders=new Map();this.configs=new Map();this.initializers=new Map();
  this.stats={drawn:0,dropped:0,decoded:0,audioDecoded:0,maxFrames:0,maxAudio:0};
  this.animation=requestAnimationFrame(()=>this.paint());
 }
 clock(){return this.audioContext?.state==='running'?this.audioContext.currentTime:performance.now()/1000;}
 get currentTime(){return this.running&&!this.paused?Math.min(this.duration,this.position+this.clock()-this.anchor):this.position;}
 set currentTime(value){this.seek(value);}
 async bytes(url,range){
  const absolute=new URL(url,location.href);if(absolute.origin!==location.origin)throw Error('Media must use the ScreenLink proxy');
  const response=await fetch(absolute,{signal:this.abort.signal,cache:'no-store',headers:range?{Range:`bytes=${range.start}-${range.end}`}:{}});
  if(!response.ok)throw Error('Media HTTP '+response.status);
  if(range&&response.status!==206)throw Error('Media server did not honor byte range');
  return new Uint8Array(await response.arrayBuffer());
 }
 async load(url,start=0){
  this.abort=new AbortController();let manifestURL=new URL(url,location.href).href,manifest;
  for(let depth=0;depth<4;depth++){
   manifest=playlist(new TextDecoder().decode(await this.bytes(manifestURL)),manifestURL);
   if(!manifest.variants.length)break;
   const variants=manifest.variants.filter(v=>!v.RESOLUTION||Number(v.RESOLUTION.split('x')[1])<=1080).sort((a,b)=>Number(a.BANDWIDTH)-Number(b.BANDWIDTH));
   const choice=variants.filter(v=>Number(v.BANDWIDTH)<=6000000).pop()||variants[0]||manifest.variants[0];
   const audio=manifest.audio.filter(a=>a['GROUP-ID']===choice.AUDIO);this.audioURL=(audio.find(a=>a.DEFAULT==='YES')||audio[0])?.url;manifestURL=choice.url;
  }
  if(manifest.variants.length||!manifest.segments.length||!manifest.end)throw Error('Live or nested HLS needs the compatibility player');
  this.videoList=manifest;this.duration=manifest.duration;
  if(this.audioURL){const list=playlist(new TextDecoder().decode(await this.bytes(this.audioURL)),this.audioURL);if(list.variants.length||!list.end)throw Error('Unsupported alternate audio playlist');this.audioList=list;}
  await this.seek(start);return this;
 }
 fail(error){if(this.closed||error?.name==='AbortError')return;this.error={code:3,message:error.message||String(error)};this.pause();this.onerror(error);}
 async configure(track,kind,serial){
  const config=kind==='video'?{codec:track.codec,codedWidth:track.video.width,codedHeight:track.video.height,description:track.description,hardwareAcceleration:'prefer-hardware'}:{codec:track.codec,sampleRate:track.audio.sample_rate,numberOfChannels:track.audio.channel_count,description:track.description};
  // Browser implementations may accept a codec while declining the hardware hint.
  const Type=kind==='video'?VideoDecoder:AudioDecoder;
  let supported=await Type.isConfigSupported(config);if(!supported.supported&&kind==='video'){delete config.hardwareAcceleration;supported=await Type.isConfigSupported(config);}
  if(serial!==this.serial||this.closed)throw new DOMException('Playback replaced','AbortError');
  if(!supported.supported)throw Error('Unsupported '+kind+' codec '+track.codec);
  const key=JSON.stringify({...config,description:config.description?Array.from(config.description):[]});
  if(this.configs.get(kind)===key)return this.decoders.get(kind);
  const old=this.decoders.get(kind);if(old){await old.flush();old.close();}
  const decoder=new Type({output:frame=>this.output(kind,frame),error:error=>this.fail(error)});decoder.configure(config);this.decoders.set(kind,decoder);this.configs.set(kind,key);return decoder;
 }
 output(kind,data){
  if(this.closed){data.close();return;}
  if(kind==='video'){
   this.stats.decoded++;if(data.timestamp/1e6<this.position-0.05){data.close();return;}
   this.frames.push(data);this.frames.sort((a,b)=>a.timestamp-b.timestamp);this.stats.maxFrames=Math.max(this.stats.maxFrames,this.frames.length);
   if(this.frames.length>180){this.fail(Error('Video buffer exceeded its limit'));return;}
  }else{
   this.stats.audioDecoded++;if(data.timestamp/1e6+data.duration/1e6<this.position){data.close();return;}
   const pcm=Array.from({length:data.numberOfChannels},(_,planeIndex)=>{const plane=new Float32Array(data.numberOfFrames);data.copyTo(plane,{planeIndex,format:'f32-planar'});return plane;});
   this.audio.push({timestamp:data.timestamp/1e6,sampleRate:data.sampleRate,frames:data.numberOfFrames,pcm});data.close();
   this.stats.maxAudio=Math.max(this.stats.maxAudio,this.audio.length);if(this.audio.length>600)this.fail(Error('Audio buffer exceeded its limit'));
  }
  this.readyState=2;
 }
 async decodeSegment(segment,kind,serial){
  let init=null;if(segment.map){const key=JSON.stringify(segment.map);if(!this.initializers.has(key))this.initializers.set(key,await this.bytes(segment.map.url,segment.map.range));init=this.initializers.get(key);}
  const bytes=await this.bytes(segment.url,segment.range);if(serial!==this.serial||this.closed)return;
  const samples=demux(bytes,init).filter(s=>s.track&&(kind==='all'||(kind==='audio'?!!s.track.audio:!!s.track.video)));
  if(!samples.length)throw Error('Selected HLS track has no samples');
  // Preserve inter-track offsets; normalize each fragment onto its playlist timeline.
  const origin=Math.min(...samples.map(s=>s.cts/s.timescale));
  for(const sample of samples){
   if(serial!==this.serial||this.closed)return;
   const type=sample.track.video?'video':'audio',decoder=await this.configure(sample.track,type,serial);
   const timestamp=Math.round((segment.start+sample.cts/sample.timescale-origin)*1e6),duration=Math.max(1,Math.round(sample.duration/sample.timescale*1e6));
   const Chunk=type==='video'?EncodedVideoChunk:EncodedAudioChunk;
   if(serial!==this.serial||this.closed)return;
   while((type==='video'&&this.frames.length>90)||(type==='audio'&&this.audio.length>400)){if(serial!==this.serial||this.closed)return;await sleep(10);}
   if(serial!==this.serial||this.closed)return;
   decoder.decode(new Chunk({type:type==='audio'||sample.is_sync?'key':'delta',timestamp,duration,data:sample.data}));
   while(decoder.decodeQueueSize>12){if(serial!==this.serial||this.closed)return;await sleep(5);}
  }
  for(const decoder of this.decoders.values())if(decoder.state==='configured')await decoder.flush();
 }
 async pump(list,kind,start,serial){
  for(const segment of list.segments){
   if(segment.start+segment.duration<=start)continue;
   while(serial===this.serial&&!this.closed&&segment.start>this.currentTime+2)await sleep(30);
   if(serial!==this.serial||this.closed)return;
   await this.decodeSegment(segment,kind,serial);
  }
 }
 async seek(value){
  if(!this.videoList||this.closed)return;this.serial++;const serial=this.serial;
  this.abort?.abort();this.abort=new AbortController();this.position=Math.max(0,Math.min(Number(value)||0,Math.max(0,this.duration-0.01)));this.anchor=this.clock();this.running=false;this.ended=false;this.readyState=0;this.release();
  const run=async()=>{
   // Serialize audio/video demux and decoder configuration across segment boundaries.
   const work=this.videoList.segments.filter(s=>s.start+s.duration>this.position).map(segment=>({segment,kind:this.audioList?'video':'all'}));
   if(this.audioList)work.push(...this.audioList.segments.filter(s=>s.start+s.duration>this.position).map(segment=>({segment,kind:'audio'})));
   work.sort((a,b)=>a.segment.start-b.segment.start);
   for(const item of work){
    while(serial===this.serial&&!this.closed&&item.segment.start>this.currentTime+2)await sleep(30);
    if(serial!==this.serial||this.closed)return;
    await this.decodeSegment(item.segment,item.kind,serial);
   }
   if(serial===this.serial)this.finished=true;
  };
  this.finished=false;run().catch(error=>{if(serial===this.serial)this.fail(error);});
 }
 async play(){if(this.closed)return;this.paused=false;if(this.readyState>=2&&!this.running){this.anchor=this.clock();this.running=true;}}
 pause(){this.position=this.currentTime;this.paused=true;this.running=false;for(const node of this.nodes){try{node.stop();}catch{}}this.nodes.clear();}
 async enableAudio(){
  const position=this.currentTime;
  if(!this.audioContext){this.audioContext=new AudioContext();this.gain=this.audioContext.createGain();this.low=this.audioContext.createBiquadFilter();this.low.type='lowshelf';this.low.frequency.value=180;this.high=this.audioContext.createBiquadFilter();this.high.type='highshelf';this.high.frequency.value=3500;this.gain.connect(this.low).connect(this.high).connect(this.audioContext.destination);}
  await this.audioContext.resume();this.position=position;this.anchor=this.clock();this.muted=false;this.gain.gain.value=1;await this.play();
 }
 setEQ(mode){if(this.low){this.low.gain.value=mode==='music'?3:0;this.high.gain.value=mode==='music'?2:0;}}
 scheduleAudio(now){
  while(this.audio.length&&this.audio[0].timestamp<now+0.25){
   const packet=this.audio.shift(),duration=packet.frames/packet.sampleRate;
   if(this.muted||!this.audioContext||this.audioContext.state!=='running'||packet.timestamp+duration<=now)continue;
   const buffer=this.audioContext.createBuffer(packet.pcm.length,packet.frames,packet.sampleRate);packet.pcm.forEach((channel,i)=>buffer.copyToChannel(channel,i));
   const node=this.audioContext.createBufferSource();node.buffer=buffer;node.connect(this.gain);this.nodes.add(node);node.onended=()=>{this.nodes.delete(node);node.disconnect();};
   const offset=Math.max(0,now-packet.timestamp);if(offset<duration)node.start(this.audioContext.currentTime+Math.max(0,packet.timestamp-now),offset);
  }
 }
 paint(){
  if(this.closed)return;
  if(!this.paused){
   if(this.readyState>=2&&!this.running){this.anchor=this.clock();this.running=true;}
   const now=this.currentTime;let frame=null;
   while(this.frames.length&&this.frames[0].timestamp/1e6<=now+0.015){if(frame){frame.close();this.stats.dropped++;}frame=this.frames.shift();}
   if(frame){try{if(this.canvas.width!==frame.displayWidth||this.canvas.height!==frame.displayHeight){this.canvas.width=frame.displayWidth;this.canvas.height=frame.displayHeight;}this.ctx.drawImage(frame,0,0,this.canvas.width,this.canvas.height);this.stats.drawn++;}finally{frame.close();}}
   this.scheduleAudio(now);
   if(this.finished&&now>=this.duration-0.02){this.pause();this.position=this.duration;this.ended=true;}
  }
  this.animation=requestAnimationFrame(()=>this.paint());
 }
 release(){
  for(const frame of this.frames)frame.close();this.frames=[];this.audio=[];
  for(const decoder of this.decoders.values())if(decoder.state!=='closed')decoder.close();this.decoders.clear();this.configs.clear();
  for(const node of this.nodes){try{node.stop();node.disconnect();}catch{}}this.nodes.clear();
 }
 destroy(){if(this.closed)return;this.closed=true;this.serial++;this.abort?.abort();cancelAnimationFrame(this.animation);this.release();this.initializers.clear();this.audioContext?.close();}
}
self.ScreenLinkCanvas={CanvasPlayer,playlist,demux};
})();
