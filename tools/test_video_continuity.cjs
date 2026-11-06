const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync(process.argv[2]||'App/CanvasPlayer.js','utf8');
let flushes=0;
class Decoder {
 static async isConfigSupported(c){return {supported:true,config:c};}
 constructor(c){this.callbacks=c;this.state='unconfigured';this.decodeQueueSize=0;this.needsKey=true;}
 configure(){this.state='configured';this.needsKey=true;}
 decode(c){if(this.needsKey&&c.type!=='key')throw new DOMException('A key frame is required after flush','DataError');this.needsKey=false;this.callbacks.output({timestamp:c.timestamp,duration:c.duration,displayWidth:1920,displayHeight:1080,close(){}});}
 async flush(){flushes++;this.needsKey=true;}
 close(){this.state='closed';}
}
const scope={performance,setTimeout,clearTimeout,setInterval,clearInterval,DOMException,URL,TextDecoder,Uint8Array,DataView,ArrayBuffer,VideoDecoder:Decoder,AudioDecoder:Decoder,EncodedVideoChunk:class{constructor(c){Object.assign(this,c);}},requestAnimationFrame:()=>1,cancelAnimationFrame(){},location:{href:'https://viewer.test/'}};
scope.self=scope;vm.createContext(scope);vm.runInContext(source,scope);
(async()=>{
 const player=new scope.ScreenLinkCanvas.CanvasPlayer({getContext:()=>({drawImage(){}})});
 player.serial=1;
 const track={codec:'avc1.640028',video:{width:1920,height:1080}};
 try{
  for(let segment=0;segment<3;segment++){
   const samples=[0,1].map(i=>({track,cts:segment*2+i,dts:segment*2+i,timescale:30,duration:1,is_sync:segment===0&&i===0,data:new Uint8Array([1])}));
   await player.decodeSegment({start:segment*2/30,duration:2/30},'video',1,{samples,bytes:new Uint8Array()});
  }
  assert.equal(player.stats.decoded,6,'All six frames across non-key HLS boundaries must decode');
  assert.equal(flushes,0,'Do not flush at continuous HLS boundaries');
  // Simulate a decoder which accepts input but stops returning frames.
  for(const frame of player.frames)frame.close();player.frames=[];
  player.running=true;player.paused=false;player.muted=false;player.hasAudio=true;player.audioContext={state:'running',currentTime:1};player.ownsAudioContext=false;player.duration=20;player.audioEnd=10;player.anchor=1;player.position=1;player.preparedVideoEnd=10;player.lastVideoDrawAt=performance.now()-4000;
  const serial=player.serial;player.checkVideoProgress();
  assert.equal(player.stats.videoRecoveries,1,'Silent output stall must trigger video recovery');
  assert.equal(player.serial,serial,'Video recovery must preserve transport generation');
  assert(player.running&&!player.paused,'Video recovery must preserve running audio');
  assert(player.videoNeedsKey,'Recovery must wait for a real keyframe');
  console.log('PASS: 1080p continuous GOP across HLS boundaries; video-only watchdog preserves audio and transport');
 }finally{player.destroy();}
})().catch(e=>{console.error(e);process.exit(1);});
