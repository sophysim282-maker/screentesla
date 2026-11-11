// Execute the shipped shell with interrupted control responses and browser restores.
const fs=require('fs'),vm=require('vm'),assert=require('assert');
let now=100000,offline=false,credential=1,active=false,denied=false,requests=[],delayedApproval=null;
const listeners={},elements=new Map(),sessionData=new Map(),localData=new Map(),timers=[];
const storage=data=>({getItem:k=>data.get(k)||null,setItem:(k,v)=>data.set(k,v)});
function el(id){if(elements.has(id))return elements.get(id);const e={value:id==='quality'?'auto':id==='viewMode'?'youtube':'normal',options:[],dataset:{},style:{setProperty(){}},addEventListener(){},classList:{toggle(){},contains(){return false}},setAttribute(){},after(){},appendChild(){},getAttribute(){return ''},disabled:false,hidden:true,width:640,height:360};elements.set(id,e);return e;}
class Screen{constructor(){this.framesDrawn=0;this.hold=true;}hide(){this.hold=true;}destroy(){this.closed=true;}privacy(){}state(){}}
const scope={console,Date:class extends Date{static now(){return now}},URL,URLSearchParams,Uint8Array,DOMException,AbortController,VideoDecoder:function(){},isSecureContext:true,location:{origin:'https://car.test',pathname:'/video',search:''},sessionStorage:storage(sessionData),localStorage:storage(localData),history:{replaceState(){}},crypto:require('crypto').webcrypto,ScreenLinkScreen:{CanvasScreen:Screen},ScreenLinkCanvas:{},MutationObserver:class{observe(){}},document:{addEventListener(){},querySelector(){return null},getElementById:el,createElement:()=>el(Symbol()),body:el('body')},matchMedia:()=>({matches:false,addEventListener(){}}),navigator:{},setTimeout:(fn,ms)=>{timers.push({fn,ms});return timers.length},clearTimeout(id){if(timers[id-1])timers[id-1].cleared=true;},window:{addEventListener(name,fn){listeners[name]=fn;}},WebSocket:class{static OPEN=1},fetch:async(path,opts)=>{
 if(offline)throw new TypeError('Failed to fetch');
 if(path==='/local-viewer/request'){if(delayedApproval)await delayedApproval;requests.push(JSON.parse(opts.body));return {ok:true,json:async()=>({phase:'approved',token:'private-proof-'+credential})};}
 if(denied)return {ok:false,status:403};
 if(path.startsWith('/screen/privacy'))return {ok:true,json:async()=>({hidden:true,privacyRevision:1})};
 if(path.startsWith('/media/state'))return {ok:true,json:async()=>({active,epoch:'video-one',command:0,screenLocked:true,paused:false})};
 if(path.startsWith('/media/report'))return {ok:true,json:async()=>({})};
 throw Error('Unexpected '+path);
}};scope.self=scope;vm.createContext(scope);
const source=fs.readFileSync(process.env.SCREENLINK_TEST_SHELL_OVERRIDE||'App/CanvasShell.js','utf8').replace("if(isSecureContext&&typeof VideoDecoder==='function')autoConnect();",'');
vm.runInContext(source.replace(/\}\)\(\);\s*$/, "self.test={raw,connect,tick,api,setPlayer:p=>{player=p;mediaEpoch='video-one';command=0;}};})();"),scope);
const flush=async()=>{for(let i=0;i<40;i++)await Promise.resolve();};
(async()=>{
 await scope.test.connect();await flush();assert(scope.ScreenLinkCanvasStatus().connected);
 const p={destroy(){this.closed=true},play(){},pause(){},stats:{drawn:1},currentTime:3,running:true,paused:false,duration:600,readyState:4,frames:[],audio:[],nodes:new Set()};scope.test.setPlayer(p);active=true;
 // Simulate a paused/delayed renderer as well as a sustained control outage.
 // Reconnection is needed, but that must not destroy already-buffered media.
 offline=true;for(let i=0;i<3;i++){now+=9000;await scope.test.tick();}
 assert(!scope.ScreenLinkCanvasStatus().connected);
 assert(!p.closed,'A temporary HTTPS outage must not destroy buffered video, even when drawing has stalled');
 offline=false;await scope.test.connect();await flush();
 assert(scope.ScreenLinkCanvasStatus().connected);assert(!p.closed,'Same approved session must reuse the existing player');assert.equal(requests.at(-1).previousToken,'private-proof-1');
 // A revoked authorization is not a temporary outage: stop buffered private media.
 denied=true;await scope.test.api('/media/state').catch(()=>{});assert(p.closed,'Explicit authorization failure must stop private playback');denied=false;
 credential=2;active=false;await scope.test.connect();await flush();assert(scope.ScreenLinkCanvasStatus().connected);
 const saved=JSON.parse(localData.get('screenlink-approved-viewer-v1'));assert.equal(saved.token,'private-proof-2');assert(saved.expires>now);
 listeners.pagehide();listeners.pageshow({persisted:true});await flush();assert(scope.ScreenLinkCanvasStatus().connected);assert.equal(requests.at(-1).previousToken,'private-proof-2');
 listeners.pagehide();let release;delayedApproval=new Promise(r=>{release=r});const late=scope.test.connect();await flush();listeners.pagehide();release();await late;await flush();assert(!scope.ScreenLinkCanvasStatus().connected,'Late response must not revive abandoned page');delayedApproval=null;
 // A partial JSON body must retain its deadline, so polling cannot hang forever.
 const original=scope.fetch;let bodyStarted=false;
 scope.fetch=async(_path,opts)=>({ok:true,json:()=>{bodyStarted=true;return new Promise((resolve,reject)=>opts.signal.addEventListener('abort',()=>reject(new DOMException('Body timed out','AbortError')),{once:true}));}});
 const before=timers.length;const pending=scope.test.raw('/media/state').then(()=>assert.fail('Expected body timeout'),e=>assert.equal(e.name,'AbortError'));await flush();assert(bodyStarted);const timeout=timers.slice(before).find(t=>t.ms===4000);assert(timeout&&!timeout.cleared);timeout.fn();await pending;scope.fetch=original;
 const diagnostic=JSON.stringify(scope.ScreenLinkCanvasStatus());assert(!diagnostic.includes('private-proof-')&&!diagnostic.includes(saved.nonce));
 console.log('LIVE_RECONNECT_PASSED: stalled drawing + control outage retains buffered player; same-session recovery; authorization revocation; stored proof; back/forward restore; stale replies; body deadline; credential redaction.');
})().catch(e=>{console.error(e);process.exit(1)});
