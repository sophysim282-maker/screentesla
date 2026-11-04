/* Deterministic scheduling/PCM regression. No network, media elements or speakers. */
const fs=require('fs'),vm=require('vm'),assert=require('assert');
global.self=global;global.requestAnimationFrame=()=>1;global.cancelAnimationFrame=()=>{};global.setInterval=()=>1;global.clearInterval=()=>{};
vm.runInThisContext(fs.readFileSync(process.argv[2]||'App/CanvasPlayer.js','utf8'));
const rate=48000,size=1024,duration=size/rate;
function fixture(){
 let clock=0,reads=0;const starts=[];
 const context={state:'running',get currentTime(){return clock+(reads++%3)*0.0029;},
 createBuffer(channels,frames,sampleRate){const data=Array.from({length:channels},()=>new Float32Array(frames));return {data,frames,sampleRate,copyToChannel(a,i){data[i].set(a);}};},
 createGain(){return {gain:{value:1,cancelScheduledValues(){},setValueAtTime(){},linearRampToValueAtTime(){}},connect(){},disconnect(){}};},
 createBufferSource(){return {connect(){},disconnect(){},stop(){this.stopped=true;},start(at,offset=0){starts.push({at,offset,node:this,buffer:this.buffer});}};}};
 const player=new ScreenLinkCanvas.CanvasPlayer({getContext:()=>({})},{audioContext:context});
 player.paused=false;player.running=true;player.muted=false;player.duration=100;player.videoEnd=100;player.position=0;player.anchor=0.05;player.gain={};
 function packet(i,jitter=0){const buffer=context.createBuffer(1,size,rate);buffer.copyToChannel(Float32Array.from({length:size},(_,n)=>0.5*Math.sin(2*Math.PI*440*(i*size+n)/rate)),0);return {timestamp:i*duration+jitter,frames:size,sampleRate:rate,buffer};}
 return {player,context,starts,packet,setClock(t){clock=t;}};
}
const f=fixture();for(let i=0;i<90;i++)f.player.audio.push(f.packet(i,i===30?0.008:0));
for(let t=0;t<1.95;t+=0.02){f.setClock(t);f.player.scheduleAudio(Math.max(0,t-0.05));}
assert.equal(f.starts.length,90);let maxGap=0;
for(let i=1;i<f.starts.length;i++){const a=f.starts[i-1],b=f.starts[i];maxGap=Math.max(maxGap,Math.abs(b.at-(a.at+a.buffer.frames/rate-a.offset)));}
assert(maxGap<1/rate,'PCM chunks must be contiguous within one sample; actual gap '+maxGap);
// Render the actual scheduled PCM in a software sample timeline; neither count
// of decoded packets nor a nonzero AudioContext proves continuous output.
const pcm=new Float32Array(Math.ceil(2.2*rate));
for(const s of f.starts){const start=Math.round(s.at*rate),offset=Math.round(s.offset*rate);for(let n=offset;n<s.buffer.frames;n++)pcm[start+n-offset]+=s.buffer.data[0][n];}
let maxStep=0,silent=0;for(let n=Math.ceil(.06*rate);n<Math.floor(1.9*rate);n++){maxStep=Math.max(maxStep,Math.abs(pcm[n]-pcm[n-1]));if(pcm[n]===0&&pcm[n-1]===0)silent++;}
assert(maxStep<0.04,'Scheduling must not introduce waveform jumps: '+maxStep);assert.equal(silent,0,'No inserted silence inside continuous sine PCM');
const paused=fixture();for(let i=0;i<20;i++)paused.player.audio.push(paused.packet(i));paused.player.scheduleAudio(0);const scheduled=paused.starts.length;assert(scheduled>0);paused.setClock(.12);paused.player.pause();assert.equal(paused.player.nodes.size,0);assert(paused.player.audio.some(p=>p.timestamp<.35),'Pause restores already-scheduled future PCM');assert(paused.player.stats.audioRestored>0);paused.player.release();assert.equal(paused.player.audio.length,0);
const muted=fixture();muted.player.muted=true;muted.player.audio.push(muted.packet(0));muted.player.scheduleAudio(0);assert.equal(muted.player.audio.length,1,'Muting must not discard future PCM');
const gap=fixture();gap.player.audio.push(gap.packet(0),gap.packet(1,.1));gap.player.scheduleAudio(0);assert(gap.starts[1].at-gap.starts[0].at>0.1,'A real timestamp gap must not be flattened');
const windowed=fixture();for(const ts of [.5,.59,.61]){const packet=windowed.packet(0);packet.timestamp=ts;windowed.player.audio.push(packet);}windowed.player.scheduleAudio(0);assert.equal(windowed.starts.length,2,'Schedule through the 600ms lookahead');assert.equal(windowed.player.audio.length,1,'Do not schedule beyond the bounded 600ms window');
console.log('CANVAS_AUDIO_PASSED: jittered clock, AAC boundary correction, continuous PCM waveform, pause restoration, mute preservation, real timestamp gaps. maxGap='+maxGap+' maxStep='+maxStep);

(async()=>{
 const f=fixture(),p=f.player;p.audioContext=null;p.gain=null;p.anchor=performance.now()/1000-.4;
 const before=p.currentTime;f.context.resume=async()=>{};f.context.createGain=f.context.createBiquadFilter=()=>({connect(){return this;},disconnect(){},gain:{value:0},frequency:{value:0}});f.context.destination={};
 await p.enableAudio(f.context);assert(p.currentTime>=before-.01&&p.currentTime<before+.05,'Enabling shared audio must preserve playhead across performance/AudioContext clocks');console.log('AUDIO_CLOCK_HANDOFF_PASSED');
})().catch(error=>{console.error(error);process.exitCode=1;});
