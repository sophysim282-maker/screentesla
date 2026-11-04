// Exercise the real shell with controlled network, clock and receiver generations.
const fs=require('fs'),vm=require('vm'),assert=require('assert');
let now=100000,offline=false,epoch=1,requests=[],screenInstances=0,privacyRevision=9,delayedApproval=null;
const listeners={};
const elements=new Map();function el(id){if(elements.has(id))return elements.get(id);const e={value:id==='quality'?'auto':id==='viewMode'?'youtube':'normal',options:[],dataset:{},style:{setProperty(){}},classList:{toggle(){}},setAttribute(){},after(){},appendChild(){},getAttribute(){return ''},disabled:false,hidden:false,width:640,height:360};elements.set(id,e);return e;}
class Screen {constructor(){screenInstances++;this.framesDrawn=0;this.minRevision=0;this.hold=true;}hide(){this.hold=true;}destroy(){this.closed=true;}privacy(meta){this.minRevision=meta.privacyRevision;}state(){}}
const timers=[];const context={console,Date:class extends Date{static now(){return now}},URLSearchParams,Uint8Array,DOMException,AbortController,VideoDecoder:function(){},isSecureContext:true,location:{origin:'https://car.test',pathname:'/video',search:''},sessionStorage:{getItem(){return '0123456789abcdef0123456789abcdef'},setItem(){}},localStorage:{getItem(){return null},setItem(){}},history:{replaceState(){}},crypto:require('crypto').webcrypto,ScreenLinkScreen:{CanvasScreen:Screen},ScreenLinkCanvas:{},MutationObserver:class{observe(){}},document:{getElementById:el,createElement:()=>el(Symbol()),body:el('body')},matchMedia:()=>({matches:false}),navigator:{},setTimeout:(fn,ms)=>{timers.push({fn,ms});return timers.length},clearTimeout(){},window:{addEventListener(name,fn){listeners[name]=fn;}},WebSocket:class{static OPEN=1},fetch:async(path,opts)=>{
 if(offline)throw new TypeError('Failed to fetch');
 if(path==='/local-viewer/request'){if(delayedApproval)await delayedApproval;const body=JSON.parse(opts.body);requests.push(body);return {ok:true,json:async()=>({phase:'approved',token:'credential-'+epoch})};}
 if(path.startsWith('/screen/privacy')){privacyRevision=epoch===1?9:1;return {ok:true,json:async()=>({hidden:true,privacyRevision})};}
 if(path.startsWith('/media/state'))return {ok:true,json:async()=>({active:false,screenLocked:true})};
 throw Error('Unexpected '+path);
}};context.self=context;vm.createContext(context);
const source=fs.readFileSync('App/CanvasShell.js','utf8').replace("if(isSecureContext&&typeof VideoDecoder==='function')autoConnect();",'');
vm.runInContext(source.replace(/\}\)\(\);\s*$/, 'self.test={connect,tick,connectionLost,privacy,setPlayer:p=>{player=p;}};})();'),context);
const flush=async()=>{for(let i=0;i<20;i++)await Promise.resolve();};
(async()=>{
 await context.test.connect();await flush();assert(context.ScreenLinkCanvasStatus().connected);assert.equal(requests.length,1);
 // Three sustained state failures must leave stale connected state and reauthenticate.
 offline=true;for(let i=0;i<3;i++){now+=9000;await context.test.tick();}
 assert(!context.ScreenLinkCanvasStatus().connected,'A dead receiver must not remain connected forever');
 epoch=2;offline=false;await context.test.connect();await flush();assert(context.ScreenLinkCanvasStatus().connected);assert.equal(requests[1].previousToken,'credential-1');assert.equal(privacyRevision,1);assert(screenInstances>=3,'New receiver session must discard old screen revision/decoder');
 assert.equal(context.ScreenLinkCanvasStatus().reconnections,1);
 // Buffered video that actually draws must survive repeated health errors.
 const p={destroy(){this.closed=true;},stats:{drawn:1},currentTime:3,frames:[],audio:[],nodes:new Set()};context.test.setPlayer(p);offline=true;
 for(let i=0;i<4;i++){now+=9000;p.stats.drawn++;await context.test.tick();}
 assert(context.ScreenLinkCanvasStatus().connected,'Healthy buffered playback must not be reset by health request failures');
 // The browser may cache the page when navigating away, then restore it.
 offline=false;listeners.pagehide();assert(!context.ScreenLinkCanvasStatus().connected);assert(p.closed);
 const beforeRestore=requests.length;listeners.pageshow({persisted:true});await flush();
 assert(context.ScreenLinkCanvasStatus().connected,'Back/forward restore must restart automatic discovery');
 assert.equal(requests.length,beforeRestore+1);assert.equal(requests.at(-1).previousToken,'credential-2');
 // An approval that completes after leaving the page must never resurrect it.
 listeners.pagehide();let release;delayedApproval=new Promise(resolve=>{release=resolve;});
 const late=context.test.connect();await flush();listeners.pagehide();release();await late;await flush();
 assert(!context.ScreenLinkCanvasStatus().connected,'Late approval must not revive an abandoned page');
 delayedApproval=null;listeners.pageshow({persisted:true});await flush();assert(context.ScreenLinkCanvasStatus().connected);
 console.log('CANVAS_RECONNECT_PASSED: sustained outage reauth, previous credential, fresh privacy generation, healthy buffered playback retained, back/forward restoration and abandoned approval cancellation.');
})().catch(e=>{console.error(e);process.exit(1)});
