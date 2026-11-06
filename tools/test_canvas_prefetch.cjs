const fs=require('fs'),vm=require('vm'),assert=require('assert');global.self=global;global.requestAnimationFrame=()=>1;global.cancelAnimationFrame=()=>{};global.setInterval=()=>1;global.clearInterval=()=>{};
vm.runInThisContext(fs.readFileSync(process.argv[2]||'App/CanvasPlayer.js','utf8'));
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const p=new ScreenLinkCanvas.CanvasPlayer({getContext:()=>({})});p.duration=3;p.videoList={segments:[0,1,2].map(id=>({id,start:id,duration:1}))};const trace=[];let inFlight=0,maxInFlight=0;
 p.prepareSegment=async segment=>{trace.push('fetch'+segment.id);inFlight++;maxInFlight=Math.max(maxInFlight,inFlight);await sleep(10);inFlight--;return {id:segment.id};};
 p.decodeSegment=async(segment,kind,serial,prepared)=>{trace.push('decode'+segment.id);assert.equal(prepared?.id,segment.id,'Decode uses the prepared segment');await sleep(30);};
 await p.seek(0);for(let i=0;i<100&&!p.finished&&!p.error;i++)await sleep(5);assert(!p.error,p.error?.message);assert(p.finished);
 assert(trace.indexOf('fetch1')<trace.indexOf('decode0'),'Next segment must be requested before current decoding drains the buffer');assert(trace.indexOf('fetch2')>trace.indexOf('decode0'),'Do not fetch entire video eagerly');assert(maxInFlight<=1,'One active fetch per rendition');p.destroy();
 const canceled=new ScreenLinkCanvas.CanvasPlayer({getContext:()=>({})});canceled.duration=1;canceled.videoList={segments:[{start:0,duration:1}]};let decoded=0;canceled.prepareSegment=async()=>{await sleep(30);return {};};canceled.decodeSegment=async()=>decoded++;
 await canceled.seek(0);canceled.destroy();await sleep(50);assert.equal(decoded,0,'A late old fetch cannot decode after destroy');
 console.log('CANVAS_PREFETCH_PASSED: next request overlaps current decoding, bounded fetch window, prepared payload reused, stale fetch suppressed.');
})().catch(error=>{console.error(error);process.exitCode=1;});
