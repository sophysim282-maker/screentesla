from pathlib import Path
import re,json,tempfile,subprocess
script=re.search(r'<script>(.*?)</script>',(Path(__file__).resolve().parent.parent/'App'/'Viewer.html').read_text(),re.S).group(1)
harness=r'''
const vm=require('vm'),assert=require('assert');let appends=0,played=0,segmentCalls=0,urls=[];
class Buffer{constructor(){this.listeners={};this.updating=false;}addEventListener(n,f){(this.listeners[n]??=new Set()).add(f);}removeEventListener(n,f){this.listeners[n]?.delete(f);}appendBuffer(data){assert(data.byteLength>0);appends++;setImmediate(()=>{for(const f of [...this.listeners.updateend??[]])f();});}}
class Media{static isTypeSupported(m){return m.includes('avc1.42C01E');}addEventListener(n,f){if(n==='sourceopen')setImmediate(f);}addSourceBuffer(){return new Buffer();}}
const elements={};for(const id of ['video','player','status','mode','reconnect','fullscreen'])elements[id]={src:'',textContent:'',currentTime:0,paused:true,buffered:{length:1,start:()=>0,end:()=>0.3},removeAttribute(n){this[n]='';},pause(){this.paused=true;},load(){},play(){played++;this.paused=false;return Promise.resolve();},decode:async()=>{}};
const timers=new Map();let timer=0;
const response=(body,headers={})=>({status:200,ok:true,json:async()=>body,headers:{get:n=>headers[n]},arrayBuffer:async()=>new Uint8Array([0,1]).buffer});
const context={MediaSource:Media,URL:Object.assign(class extends URL{},{createObjectURL:()=> 'blob:mse',revokeObjectURL(){}}),URLSearchParams,AbortController,
location:{search:'?token=secret'},performance:{now:()=>Date.now()},localStorage:{getItem:()=>null,setItem(){}},
document:{getElementById:id=>elements[id],documentElement:{},body:{classList:{add(){},toggle(){}}}},
setTimeout:f=>{timers.set(++timer,f);return timer;},clearTimeout:id=>timers.delete(id),
fetch:async url=>{urls.push(url);if(url.startsWith('/status.json'))return new Promise(()=>{});
if(url.startsWith('/h264/info'))return response({ready:true,codec:'avc1.42C01E',epoch:'E1'});
if(url.startsWith('/h264/init.mp4'))return response(null,{'X-Stream-Epoch':'E1'});
if(url.startsWith('/h264/segments')){segmentCalls++;return segmentCalls===1?response(null,{'X-Stream-Epoch':'E1','X-Last-ID':'2'}):new Promise(()=>{});}
throw Error(url);}};
vm.runInNewContext(SCRIPT,context);
(async()=>{for(let i=0;i<8;i++)await new Promise(setImmediate);
assert.equal(appends,2);assert(played>0);assert(urls.some(u=>u.includes('after=2&epoch=E1')));
assert(!urls.some(u=>u.startsWith('/frame.jpg')));assert.equal(elements.player.hidden,false);assert.equal(elements.video.hidden,true);
elements.mode.onclick();assert(elements.video.src.startsWith('/stream.mjpg?'));assert.equal(elements.player.hidden,true);
console.log('H.264 viewer test passed: MSE initialization, fragment append, sequence continuation, playback and JPEG fallback.');
})().catch(e=>{console.error(e);process.exitCode=1;});
'''.replace('SCRIPT',json.dumps(script))
with tempfile.NamedTemporaryFile(mode='w',suffix='.js') as f:
 f.write(harness);f.flush();subprocess.run(['node',f.name],check=True)
