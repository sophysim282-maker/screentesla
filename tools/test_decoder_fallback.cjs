// Build 74: after repeated hardware decoder stalls the WebCodecs player switches
// to the browser's software decoder for the session instead of freezing again.
const fs=require('fs'),vm=require('vm'),assert=require('assert');
let now=1000;const configs=[];
class Decoder{static async isConfigSupported(config){return {supported:true,config};}
 constructor(c){this.callbacks=c;this.state='unconfigured';this.decodeQueueSize=0;}
 configure(config){this.state='configured';configs.push(config.hardwareAcceleration);} decode(){} async flush(){} close(){this.state='closed';}}
const scope={performance:{now:()=>now},setTimeout,clearTimeout,setInterval:()=>1,clearInterval(){},requestAnimationFrame:()=>1,cancelAnimationFrame(){},AbortController,DOMException,URL,TextDecoder,Uint8Array,DataView,ArrayBuffer,VideoDecoder:Decoder,AudioDecoder:Decoder,EncodedVideoChunk:class{},location:{href:'https://viewer.test/'}};
scope.self=scope;vm.createContext(scope);vm.runInContext(fs.readFileSync(process.argv[2]||'App/CanvasPlayer.js','utf8'),scope);
const track={codec:'avc1.640028',video:{width:1920,height:1080}};
const make=pref=>{const p=new scope.ScreenLinkCanvas.CanvasPlayer({getContext:()=>({drawImage(){}})},pref?{decoderPreference:pref}:{});p.serial=1;return p;};
(async()=>{
 let p=make();await p.configure(track,'video',1);assert.equal(configs.at(-1),'prefer-hardware','Hardware decoding first');
 p.resetVideo('output-stall');await p.configure(track,'video',1);assert.equal(configs.at(-1),'prefer-hardware','One stall keeps hardware');
 now+=70000;p.resetVideo('output-stall');await p.configure(track,'video',1);assert.equal(configs.at(-1),'prefer-hardware','Stalls a minute apart keep hardware');
 now+=5000;p.resetVideo('queue-timeout');await p.configure(track,'video',1);assert.equal(configs.at(-1),'prefer-software','Two stalls within a minute switch to software');
 assert.equal(p.stats.softwareDecoderFallback,true);assert(p.playbackEvents.some(e=>e.type==='decoder-software-fallback'));
 now+=5000;p.resetVideo('output-stall');await p.configure(track,'video',1);assert.equal(configs.at(-1),'prefer-software','Stays on software for the session');
 p=make();p.resetVideo('test-error');p.resetVideo('seek');await p.configure(track,'video',1);assert.equal(configs.at(-1),'prefer-hardware','Ordinary resets do not switch');
 p=make('hardware');p.resetVideo('output-stall');p.resetVideo('output-stall');await p.configure(track,'video',1);assert.equal(configs.at(-1),'prefer-hardware','decoder=hardware never switches');
 p=make('software');await p.configure(track,'video',1);assert.equal(configs.at(-1),'prefer-software','decoder=software from the start');
 console.log('PASS: decoder stalls switch WebCodecs to software decoding once per session; hardware/software overrides respected');
})().catch(e=>{console.error(e);process.exit(1);});
