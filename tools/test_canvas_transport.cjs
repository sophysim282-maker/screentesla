const assert=require('assert'),fs=require('fs'),vm=require('vm');
global.self=global;global.location={href:'https://local.test/',origin:'https://local.test'};
vm.runInThisContext(fs.readFileSync('App/CanvasPlayer.js','utf8'));
const {CanvasPlayer,chooseVariant}=ScreenLinkCanvas;
const player=()=>Object.assign(Object.create(CanvasPlayer.prototype),{abort:new AbortController(),stats:{},decoders:new Map([['video',{sentinel:true}]]),frames:[{sentinel:true}],audio:[{sentinel:true}]});
(async()=>{
 const source=new Uint8Array(8*1024*1024+17);for(let i=0;i<source.length;i++)source[i]=i%251;
 const ranges=[];let requests=0;
 global.fetch=async(_url,options)=>{
  requests++;if(requests===2)return new Response('temporary',{status:503});
  const m=/bytes=(\d+)-(\d+)/.exec(options.headers.Range),start=+m[1],end=Math.min(+m[2],source.length-1);ranges.push([start,end]);
  assert(end-start+1<=1024*1024,'Phone response exceeds chunk budget');
  return new Response(source.subarray(start,end+1),{status:206,headers:{'Content-Range':`bytes ${start}-${end}/${source.length}`}});
 };
 const p=player(),frames=p.frames,audio=p.audio,decoders=p.decoders;
 const bytes=await p.bytes('/segment',null,true);assert.deepEqual(bytes,source);
 assert.equal(p.stats.fetchRetries,1);assert.equal(p.frames,frames);assert.equal(p.audio,audio);assert.equal(p.decoders,decoders);
 assert.equal(ranges.length,9);assert.equal(ranges[8][1],source.length-1);
 const partial=await p.bytes('/segment',{start:900000,end:2400000},true);assert.deepEqual(partial,source.subarray(900000,2400001));
 let denied=0;global.fetch=async()=>{denied++;return new Response('',{status:403});};
 await assert.rejects(()=>p.bytes('/denied'),/403/);assert.equal(denied,1,'Permanent authorization failure must not retry');
 p.abort.abort();await assert.rejects(()=>p.bytes('/cancelled'),e=>e.name==='AbortError');
 const variants=[144,720,1080,2160].map(h=>({RESOLUTION:`${h*16/9}x${h}`,BANDWIDTH:h}));
 assert.equal(chooseVariant(variants,'720').RESOLUTION,'1280x720');assert.equal(chooseVariant(variants,'1080').RESOLUTION,'1920x1080');
 assert.throws(()=>chooseVariant([variants[0],variants[3]],'1080'),/no 720p or 1080p/);
 assert.equal(chooseVariant([variants[0]],'hd').RESOLUTION,variants[0].RESOLUTION,'Explicit developer source mode remains available');
 console.log('CANVAS_TRANSPORT_PASSED: 8 MB source via 1 MB ranges, transient 503 retried with decoder/PCM/frame identity preserved, exact partial range, auth/cancellation and HD-only normal selection.');
})().catch(e=>{console.error(e);process.exit(1);});
