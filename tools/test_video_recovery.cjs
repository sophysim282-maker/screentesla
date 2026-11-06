const http=require('http'),fs=require('fs'),path=require('path'),assert=require('assert'),{chromium}=require('playwright');
const app=process.argv[2],fixtures=process.argv[3];
const server=http.createServer((req,res)=>{
 const name=new URL(req.url,'http://localhost').pathname.slice(1);
 if(!name){res.setHeader('Content-Type','text/html');return res.end('<canvas id="c"></canvas>');}
 const location=path.join(['CanvasPlayer.js','MP4Demux.js','TSDemux.js'].includes(name)?app:fixtures,path.basename(name));
 if(!fs.existsSync(location)){res.statusCode=404;return res.end();}
 res.setHeader('Content-Type',name.endsWith('.js')?'application/javascript':'application/octet-stream');
 const data=fs.readFileSync(location),match=/bytes=(\d+)-(\d+)/.exec(req.headers.range||'');
 if(match){const start=+match[1],end=Math.min(+match[2],data.length-1);res.statusCode=206;res.setHeader('Content-Range',`bytes ${start}-${end}/${data.length}`);return res.end(data.subarray(start,end+1));}res.end(data);
});
(async()=>{
 let browser;
 try{
  await new Promise(r=>server.listen(0,'127.0.0.1',r));browser=await chromium.launch({headless:true,args:['--no-sandbox','--autoplay-policy=no-user-gesture-required']});const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:'+server.address().port);
  await page.evaluate(()=>{
   const Native=VideoDecoder;window.videoFault=false;window.reorderFault=false;
   window.VideoDecoder=class{
    static isConfigSupported(c){return Native.isConfigSupported(c);}
    constructor(callbacks){this.callbacks=callbacks;this.retired=false;this.held=new Set();this.native=new Native({output:frame=>{
     if(this.retired){frame.close();return;}
     if(window.videoFault||window.reorderFault){this.held.add(frame);setTimeout(()=>{if(!this.held.delete(frame))return;if(this.retired)frame.close();else callbacks.output(frame);},window.videoFault?2600:((frame.timestamp%3)*35));}
     else callbacks.output(frame);
    },error:callbacks.error});}
    configure(c){this.native.configure(c);}get state(){return this.native.state;}
    get decodeQueueSize(){return this.native.decodeQueueSize+(window.videoFault?32:0);}
    decode(c){this.native.decode(c);if(window.injectError){window.injectError=false;setTimeout(()=>{if(!this.retired){this.native.close();this.callbacks.error(new DOMException('Injected asynchronous video failure','EncodingError'));}},5);}}flush(){return window.videoFault?new Promise(()=>{}):this.native.flush();}
    close(){this.retired=true;for(const frame of this.held)frame.close();this.held.clear();this.native.close();}
   };
  });
  for(const file of ['MP4Demux.js','TSDemux.js','CanvasPlayer.js'])await page.addScriptTag({url:'/'+file});
  await page.evaluate(async()=>{window.p=new ScreenLinkCanvas.CanvasPlayer(document.getElementById('c'),{onerror:e=>window.failure=e.message});await p.load('/master.m3u8');await p.enableAudio();await p.play();});
  try{await page.waitForFunction(()=>p.currentTime>2&&p.stats.drawn>20,null,{timeout:25000});}catch(e){console.log('STARTUP_STATE',await page.evaluate(()=>({failure:window.failure,time:p.currentTime,stats:p.stats,frames:p.frames.length,audio:p.audio.length,hasAudio:p.hasAudio,paused:p.paused,running:p.running,videoEnd:p.videoEnd,audioEnd:p.audioEnd,ready:p.readyState,errors:window.failure})));console.log('PAGE_ERRORS',errors);throw e;}
  console.log('CLOUD_BASELINE_PROFILE',JSON.stringify(await page.evaluate(()=>p.performanceProfile())));
  const before=await page.evaluate(()=>{window.audioDecoder=p.decoders.get('audio');window.startSerial=p.serial;window.videoFault=true;return {time:p.currentTime,scheduled:p.stats.audioScheduled,drawn:p.stats.drawn};});
  await page.waitForTimeout(3200);
  const during=await page.evaluate(()=>({time:p.currentTime,audio:p.stats.audioScheduled,same:p.decoders.get('audio')===audioDecoder,serial:p.serial,recoveries:p.stats.videoRecoveries,failure:window.failure}));
  assert(during.time>before.time+2.7,'Audio clock stalled during video fault');assert(during.audio>before.scheduled,'Audio scheduling stopped');assert(during.same&&during.serial===1,'Recovery reset audio/transport');assert(during.recoveries>0,'Video watchdog did not run');assert(!during.failure,during.failure);
  await page.evaluate(()=>{videoFault=false;reorderFault=true;window.recoveredDrawn=p.stats.drawn;});
  await page.waitForFunction(()=>p.stats.drawn>recoveredDrawn+20&&p.currentTime>7,null,{timeout:15000});
  await page.evaluate(()=>{const until=performance.now()+90;while(performance.now()<until){};});
  await page.waitForTimeout(100);
  const result=await page.evaluate(()=>({profile:p.performanceProfile(),stats:p.stats,time:p.currentTime,videoEnd:p.videoEnd,audioEnd:p.audioEnd,sameAudio:p.decoders.get('audio')===audioDecoder,sameSerial:p.serial===startSerial,width:p.canvas.width,height:p.canvas.height,queued:p.frames.map(f=>f.timestamp/1e6),lastDrawn:p.lastDrawnVideoTimestamp/1e6,failure:window.failure}));
  assert(result.profile.metrics.demuxMs.count>0,'Actual segment demux must be measured');
  assert(result.profile.metrics.decoderWaitMs.max>1000,'Injected decoder backpressure must appear in profile');
  assert(result.profile.metrics.renderCallbackGapMs.max>=70,'Injected main-thread stall must appear in callback gaps');
  assert(result.profile.metrics.canvasDrawMs.count>0,'Canvas draw calls must be measured');
  assert(result.profile.events.length<=60,'Profile event history must remain bounded');
  assert.equal(result.width,1920);assert.equal(result.height,1080);assert(result.sameAudio&&result.sameSerial);assert(result.stats.videoQueueTimeouts>0);assert(result.stats.maxFrames<=49);assert(result.queued.every(t=>t>result.lastDrawn),'Already drawn frames survived monotonic admission');assert(!result.failure,result.failure);assert.deepEqual(errors,[]);
  await page.evaluate(()=>{window.beforeError=p.stats.videoRecoveries;window.injectError=true;});
  await page.waitForFunction(()=>p.stats.videoRecoveries>beforeError&&p.stats.drawn>recoveredDrawn+40,null,{timeout:15000});
  await page.waitForFunction(()=>p.currentTime>14&&p.stats.drawn>100,null,{timeout:20000});
  assert(await page.evaluate(()=>p.decoders.get('audio')===audioDecoder&&!p.error));
  console.log('BUILD59_VIDEO_RECOVERY_PASSED',JSON.stringify(result));
  await page.evaluate(async()=>{reorderFault=true;await p.seek(8);await p.play();});
  await page.waitForFunction(()=>p.serial>startSerial&&p.currentTime>9&&p.stats.drawn>120,null,{timeout:15000});
  assert(await page.evaluate(()=>!p.error&&p.frames.every(f=>f.timestamp>p.lastDrawnVideoTimestamp)),'Late old decoder callbacks crossed seek generation');
  await page.evaluate(()=>p.destroy());
 }finally{await browser?.close();server.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
