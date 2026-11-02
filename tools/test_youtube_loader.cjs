// Exercise the actual deployed loader against HLS.js's default fragment context.
const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync(require('path').join(__dirname,'../docs/webrtc-youtube-viewer.html'),'utf8');
const loaderSource=html.slice(html.indexOf('class RTCLoader {'),html.indexOf('function feedback()'));
const rpcSource=html.slice(html.indexOf('class MediaRPC {'),html.indexOf('let peer='));
const scope={performance,URL,TextDecoder,TextEncoder,Uint8Array,ArrayBuffer,DataView,setTimeout,clearTimeout,log(){},lastResourceFailure:null};vm.createContext(scope);vm.runInContext(rpcSource+';this.RPC=MediaRPC;'+loaderSource+';this.Loader=RTCLoader;',scope);
const url='https://screenlink.local/media/resource/11111111-1111-4111-8111-111111111111';
(async()=>{
 const requests=[];scope.rpc={ready:true,request(path,extra){requests.push(extra);return {promise:Promise.resolve({status:200,data:new Uint8Array([1,2,3]),first:performance.now()}),abort(){}};}};
 const load=async range=>{let success=false,failure=null;new scope.Loader().load({url,responseType:'arraybuffer',...range},{},{onSuccess(){success=true;},onError(error){failure=error;}});await new Promise(r=>setImmediate(r));return {success,failure};};
 assert((await load({rangeStart:0,rangeEnd:0})).success);assert.equal(requests.at(-1).range,undefined,'HLS.js 0/0 sentinel must request the whole fragment');
 assert((await load({})).success);assert.equal(requests.at(-1).range,undefined,'Manifest without a range must remain a full request');
 assert((await load({rangeStart:0,rangeEnd:32})).success);assert.equal(requests.at(-1).range,'bytes=0-31');
 assert((await load({rangeStart:20,rangeEnd:40})).success);assert.equal(requests.at(-1).range,'bytes=20-39');
 const before=requests.length;assert((await load({rangeStart:40,rangeEnd:20})).failure);assert.equal(requests.length,before,'Invalid range must never reach the phone');
 const sent=[],channel={readyState:'open',send(text){sent.push(JSON.parse(text));}};const rpc=new scope.RPC(channel);rpc.receive(JSON.stringify({type:'hello',protocol:'screenlink-media-v1'}));scope.rpc=rpc;
 let failure=null;new scope.Loader().load({url,responseType:'arraybuffer',rangeStart:0,rangeEnd:0},{},{onSuccess(){assert.fail('Rejected resource must not load');},onError(error){failure=error;}});
 rpc.receive(JSON.stringify({type:'response',id:sent.at(-1).id,status:400,length:0,mime:'text/plain'}));await new Promise(r=>setImmediate(r));assert.equal(failure.code,400,'Actual receiver HTTP status must reach HLS.js');assert.equal(scope.lastResourceFailure.code,400);assert(!JSON.stringify(scope.lastResourceFailure).includes('screenlink.local'),'Diagnostics must omit resource URLs');rpc.close();
 console.log('YouTube loader regression passed: real HLS 0/0 sentinel, full manifests, valid exclusive-end byte ranges, invalid-range rejection and HTTP error propagation without source URLs.');
})().catch(error=>{console.error(error);process.exit(1);});
