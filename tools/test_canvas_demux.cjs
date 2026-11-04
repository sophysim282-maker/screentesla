const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const [app,fixtures]=process.argv.slice(2);global.self=global;
for(const name of ['MP4Demux.js','TSDemux.js','CanvasPlayer.js'])vm.runInThisContext(fs.readFileSync(path.join(app,name),'utf8'),{filename:name});
const read=name=>new Uint8Array(fs.readFileSync(path.join(fixtures,name))),demux=ScreenLinkCanvas.demux;
const ts=read('part00.ts'),init=read('init.mp4'),frag=read('fragment00.m4s'),packed=read('packed00.aac');
const id3Length=10+Array.from(packed.subarray(6,10)).reduce((n,v)=>n*128+v,0);
for(const data of [packed,packed.subarray(id3Length)]){
 const samples=demux(data);assert(samples.length>40);assert(samples.every(s=>s.track.audio&&!s.track.video&&s.track.codec==='mp4a.40.2'&&s.data.length>0));assert(samples[0].track.description?.length);
}
assert(demux(ts).some(s=>s.track.video));assert(demux(frag,init).some(s=>s.track.video));
const taggedTS=new Uint8Array(id3Length+ts.length);taggedTS.set(packed.subarray(0,id3Length));taggedTS.set(ts,id3Length);assert(demux(taggedTS).some(s=>s.track.video));
assert.throws(()=>demux(packed.subarray(0,12)),/Truncated HLS ID3/);
assert.throws(()=>demux(new Uint8Array(Buffer.from('<html>not media</html>'))),/Unsupported HLS segment format/);
assert.throws(()=>demux(init),/tracks=2.*boxes=.*bytes=/);
console.log('CANVAS_DEMUX_PASSED: packed AAC with/without ID3, TS with/without ID3, fMP4, malformed and non-media input; no media elements.');
