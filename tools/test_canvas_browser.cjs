const http=require('http'),fs=require('fs'),path=require('path'),assert=require('assert'),{chromium}=require('playwright');
const root=process.argv[2],fixtures=process.argv[3];let source=process.argv.includes('--quality')?'quality.m3u8':'master.m3u8',command=0,paused=false,kind='rate',seek=0,reports=[];
const scripts={'/media/canvas.js':'CanvasPlayer.js','/media/mp4box.js':'MP4Demux.js','/media/mux.js':'TSDemux.js','/media/hls.js':'HLSPlayer.js'};
const server=http.createServer((req,res)=>{const url=new URL(req.url,'http://localhost');res.setHeader('Cache-Control','no-store');
 if(url.pathname==='/'){res.setHeader('Content-Type','text/html');return res.end(fs.readFileSync(path.join(root,'MediaPlayer.html')));}
 if(scripts[url.pathname]){res.setHeader('Content-Type','application/javascript');return res.end(fs.readFileSync(path.join(root,scripts[url.pathname])));}
 if(url.pathname==='/media/state'){res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({active:true,epoch:source,url:'/media/fixture/'+source,command,commandKind:kind,seek,paused,start:0,fraction:0}));}
 if(url.pathname==='/media/report'){let body='';req.on('data',data=>body+=data);req.on('end',()=>{reports.push(JSON.parse(body));res.end('{}');});return;}
 if(url.pathname.startsWith('/media/fixture/')){const file=path.basename(url.pathname),location=path.join(fixtures,file);if(!fs.existsSync(location)){res.statusCode=404;return res.end();}res.setHeader('Content-Type',file.endsWith('.m3u8')?'application/vnd.apple.mpegurl':'application/octet-stream');const data=fs.readFileSync(location);if(req.headers.range){const m=/bytes=(\d+)-(\d+)/.exec(req.headers.range);res.statusCode=206;res.setHeader('Content-Range',`bytes ${m[1]}-${m[2]}/${data.length}`);return res.end(data.subarray(+m[1],+m[2]+1));}return res.end(data);}
 res.statusCode=404;res.end();
});
(async()=>{
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});const page=await browser.newPage();page.on('pageerror',error=>console.error('PAGE',error));page.on('console',msg=>{if(msg.type()==='error')console.error(msg.text());});
 await page.goto('http://127.0.0.1:'+server.address().port+'/?token=fixture');
 await page.waitForFunction(()=>typeof codecPlayer!=='undefined'&&codecPlayer?.stats.drawn>25&&codecPlayer.currentTime>1,null,{timeout:20000});
 let result=await page.evaluate(()=>({engine,stats:codecPlayer.stats,time:codecPlayer.currentTime,source:player.getAttribute('src'),pixels:canvas.getContext('2d').getImageData(0,0,canvas.width,canvas.height).data.some((v,i)=>i%4!==3&&v>20)}));
 if(process.argv.includes('--quality')){
  assert(result.engine.startsWith('WebCodecs'));assert(result.pixels);assert(!result.source);
  await page.waitForFunction(()=>codecPlayer?.stats.drawn>10&&canvas.width===1920&&canvas.height===1080,null,{timeout:20000});
  assert.equal(await page.evaluate(()=>codecPlayer.selectedHeight),1080);assert.deepEqual(await page.evaluate(()=>codecPlayer.offeredHeights),[1080,720,144]);
  await page.selectOption('#quality','720');await page.waitForFunction(()=>codecPlayer?.selectedHeight===720&&codecPlayer.stats.drawn>10&&canvas.height===720,null,{timeout:20000});
  await page.selectOption('#quality','1080');await page.waitForFunction(()=>codecPlayer?.selectedHeight===1080&&codecPlayer.stats.drawn>10&&canvas.height===1080,null,{timeout:20000});
  assert(await page.evaluate(()=>codecPlayer.stats.audioDecoded>0));console.log('Local Canvas HD passed: actual 1080p default, 720p manual and return to decoded 1080p, original audio; master advertises HD above 6 Mbps, no upscaling.');await browser.close();server.close();return;
 }
 assert(result.engine.startsWith('WebCodecs'));assert(result.pixels);assert(!result.source);assert(result.stats.audioDecoded>10);console.log('Direct TS demux, decoded audio and Canvas pixels:',result);
 command++;paused=true;await page.waitForFunction(()=>codecPlayer.paused);const before=await page.evaluate(()=>codecPlayer.currentTime);await page.waitForTimeout(300);assert(Math.abs(await page.evaluate(()=>codecPlayer.currentTime)-before)<0.05);
 command++;paused=false;kind='seek';seek=5;await page.waitForFunction(()=>codecPlayer.currentTime>5.4&&codecPlayer.stats.drawn>35,null,{timeout:10000});
 await page.click('#sound');await page.waitForFunction(()=>codecPlayer.audioContext?.state==='running'&&!codecPlayer.muted);await page.selectOption('#eq','music');assert.equal(await page.evaluate(()=>codecPlayer.low.gain.value),3);
 await page.waitForTimeout(500);assert(await page.evaluate(()=>codecPlayer.stats.audioDecoded>20));assert(reports.some(r=>r.ready&&r.duration>9&&r.position>0));
 assert(await page.evaluate(()=>codecPlayer.stats.maxFrames<=180&&codecPlayer.stats.maxAudio<=600));console.log('Pause, seek, audio activation, Music EQ and bounded buffers passed');
 source='fragmented.m3u8';command++;kind='rate';seek=0;
 await page.waitForFunction(()=>current==='fragmented.m3u8'&&codecPlayer?.currentTime>1&&codecPlayer.stats.drawn>20,null,{timeout:20000});
 assert(await page.evaluate(()=>engine.startsWith('WebCodecs')&&codecPlayer.stats.audioDecoded>10));console.log('Fragmented MP4 init-map demux passed');
 await page.evaluate(()=>{window.retired=codecPlayer;document.getElementById('reconnect').click();});
 await page.waitForFunction(()=>retired.closed&&retired.frames.length===0&&retired.decoders.size===0&&codecPlayer!==retired&&codecPlayer.stats.drawn>10,null,{timeout:15000});
 console.log('Reconnect releases frames, decoders and audio nodes');
 await page.close();source='master.m3u8';command++;kind='rate';paused=false;seek=0;
 const delayed=await browser.newPage();let releaseSegment;const segmentGate=new Promise(resolve=>releaseSegment=resolve);await delayed.route('**/part02.ts',async route=>{await segmentGate;try{await route.continue();}catch{}});
 await delayed.goto('http://127.0.0.1:'+server.address().port+'/?token=fixture');
 await delayed.waitForFunction(()=>codecPlayer?.currentTime>3.96,null,{timeout:15000});await delayed.waitForTimeout(500);
 assert(await delayed.evaluate(()=>codecPlayer.muted),'This starvation case exercises silent video playback');
 assert(await delayed.evaluate(()=>codecPlayer.currentTime<4.1),'Muted playback must hold at the last decoded frame until the blocked segment arrives');releaseSegment();
 await delayed.waitForFunction(()=>codecPlayer?.currentTime>4.3,null,{timeout:10000});assert(await delayed.evaluate(()=>engine.startsWith('WebCodecs')));console.log('Network starvation freezes the media clock and resumes direct playback');
 await browser.close();server.close();
})().catch(error=>{console.error(error);server.close();process.exit(1);});
