from pathlib import Path
import re,tempfile,subprocess,json
script=re.search(r'<script>(.*?)</script>',(Path(__file__).resolve().parent.parent/'App'/'Viewer.html').read_text(),re.S).group(1)
harness=r'''
const vm=require('vm'),assert=require('assert');
function setup(expire=false){
 const elements={};for(const key of ['video','status','mode','reconnect','fullscreen'])elements[key]={src:'',textContent:'',removeAttribute(name){this[name]='';},decode:async()=>{}};
 let frameRequests=0,urls=[];const timers=new Map();let timer=0;
 const context={URL:Object.assign(class extends URL{},{createObjectURL:()=> 'blob:frame',revokeObjectURL:()=>{}}),URLSearchParams,AbortController,
 location:{search:'?token=secret'},performance:{now:()=>Date.now()},localStorage:{getItem:()=>null,setItem(){}},
 document:{getElementById:id=>elements[id],documentElement:{requestFullscreen:()=>Promise.resolve()},body:{classList:{add(){},toggle(){}}}},
 setTimeout:fn=>{timers.set(++timer,fn);return timer;},clearTimeout:id=>timers.delete(id),
 fetch:async url=>{urls.push(url);if(url.startsWith('/status.json'))return expire?{status:403,ok:false}:new Promise(()=>{});
 frameRequests++;if(frameRequests===1)return {status:200,ok:true,blob:async()=>new Blob(['jpeg']),headers:{get:()=> '99'}};
 return new Promise(()=>{});}};
 vm.runInNewContext(SCRIPT,context);return {elements,urls,timers};
}
(async()=>{
 const normal=setup();assert(normal.elements.video.src.startsWith('/stream.mjpg?token=secret'));
 normal.elements.mode.onclick();await new Promise(setImmediate);await new Promise(setImmediate);
 assert(normal.elements.video.src==='blob:frame');assert(normal.urls.some(url=>url.endsWith('after=99')));
 normal.elements.mode.onclick();assert(normal.elements.video.src.startsWith('/stream.mjpg?'));
 const expired=setup(true);await new Promise(setImmediate);await new Promise(setImmediate);
 assert(expired.elements.status.textContent.includes('expired'));assert.equal(expired.elements.video.src,'');
 assert.equal(expired.timers.size,0);
 console.log('Viewer tests passed: continuous default, snapshot fallback, switching back and expired-link cleanup.');
})().catch(error=>{console.error(error);process.exitCode=1;});
'''.replace('SCRIPT',json.dumps(script))
with tempfile.NamedTemporaryFile(mode='w',suffix='.js') as f:
 f.write(harness);f.flush();subprocess.run(['node',f.name],check=True)
