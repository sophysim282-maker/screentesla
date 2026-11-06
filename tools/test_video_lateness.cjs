const fs=require('fs'),vm=require('vm'),assert=require('assert');
let mediaTime=2,now=1000,created=[],drawn=[];
class Decoder {
 static async isConfigSupported(config){return {supported:true,config};}
 constructor(callbacks){this.callbacks=callbacks;this.state='unconfigured';this.decodeQueueSize=0;this.chunks=[];created.push(this);}
 configure(){this.state='configured';}
 decode(c){this.chunks.push(c.type);this.callbacks.output(frame(c.timestamp));}
 async flush(){}
 close(){this.state='closed';}
}
function frame(timestamp){return {timestamp,duration:33333,displayWidth:1920,displayHeight:1080,closed:0,close(){this.closed++;assert.equal(this.closed,1,'Frame must close exactly once');}};}
const scope={performance:{now:()=>now},setTimeout,clearTimeout,setInterval:()=>1,clearInterval(){},requestAnimationFrame:()=>1,cancelAnimationFrame(){},AbortController,DOMException,URL,TextDecoder,Uint8Array,DataView,ArrayBuffer,VideoDecoder:Decoder,AudioDecoder:Decoder,EncodedVideoChunk:class{constructor(c){Object.assign(this,c);}},location:{href:'https://viewer.test/'}};
scope.self=scope;vm.createContext(scope);vm.runInContext(fs.readFileSync(process.argv[2]||'App/CanvasPlayer.js','utf8'),scope);
function player(){
 const p=new scope.ScreenLinkCanvas.CanvasPlayer({getContext:()=>({drawImage(f){drawn.push(f.timestamp);}})});
 p.serial=1;p.duration=100;p.position=2;p.anchor=2;p.clock=()=>2;p.running=true;p.paused=false;p.muted=false;p.hasAudio=true;p.audioEnd=20;p.videoEnd=20;p.readyState=2;p.audioContext={state:'running',currentTime:2};p.ownsAudioContext=false;
 Object.defineProperty(p,'currentTime',{configurable:true,get:()=>mediaTime});
 return p;
}
(async()=>{
 const p=player();
 const late=frame(1800000);p.output('video',late);p.paint();
 assert.equal(p.stats.drawn,1,'200ms late output must still update the picture');
 assert.equal(late.closed,1);assert.equal(p.lastDrawnVideoTimestamp,1800000);
 for(const pts of [1700000,1800000]){const stale=frame(pts);p.output('video',stale);assert.equal(stale.closed,1);}
 const newer=frame(1900000);p.output('video',newer);p.paint();assert.equal(p.stats.drawn,2);
 p.output('video',frame(2100000));p.output('video',frame(2050000));mediaTime=2.11;p.paint();assert.equal(p.lastDrawnVideoTimestamp,2100000);
 assert(drawn.every((x,i)=>i===0||x>drawn[i-1]),'Reordered output must not rewind');
 p.resetVideo('test-error');assert.equal(p.lastDrawnVideoTimestamp,2100000,'Recovery retains last drawn guard');
 p.videoList={segments:[]};await p.seek(.5);mediaTime=.5;p.paused=false;
 const sought=frame(450000);p.output('video',sought);p.paint();assert.equal(p.lastDrawnVideoTimestamp,450000,'Seek permits lower timestamps');
 p.destroy();
 mediaTime=2;const q=player(),track={codec:'avc1.640028',video:{width:1920,height:1080}},audio={state:'configured',close(){this.state='closed';}};q.decoders.set('audio',audio);
 const samples=[30,31].map((cts,i)=>({track,cts,dts:cts,timescale:30,duration:1,is_sync:i===0,data:new Uint8Array([1])}));
 await q.decodeSegment({start:1,duration:2/30},'video',1,{samples,bytes:new Uint8Array()});
 const decoder=q.decoders.get('video');assert(decoder,'Late encoded video must preserve decoder references');
 assert.deepEqual(decoder.chunks,['key','delta']);assert.equal(q.stats.videoRecoveries,0,'Timestamp lag alone must not reset');
 assert.equal(q.decoders.get('audio'),audio);assert.equal(q.serial,1);q.paint();
 const serial=q.serial;q.videoList={segments:[]};await q.seek(.5);
 const old=frame(2000000);decoder.callbacks.output(old);assert.equal(old.closed,1);assert.equal(q.frames.length,0,'Old serial callback must be rejected');
 mediaTime=.5;const next=await q.configure(track,'video',q.serial);q.resetVideo('test-error');const retired=frame(500000);next.callbacks.output(retired);assert.equal(retired.closed,1);assert.equal(q.frames.length,0,'Old decoder callback must be rejected');
 q.destroy();console.log('PASS: late output stays drawable, monotonic timestamps, seek reset, encoded reference continuity, audio identity and stale callback isolation');
})().catch(e=>{console.error(e);process.exit(1);});
