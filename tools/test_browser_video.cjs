// Build 71: the HTTPS car website plays YouTube with the browser's own video
// player (HLS.js + <video>, as on http://3.3.3.3:8080) drawn on the canvas.
// Usage: node tools/test_browser_video.cjs App <hls fixture dir>
const fs=require('fs'),path=require('path'),https=require('https'),assert=require('assert'),os=require('os'),{execFileSync}=require('child_process'),{chromium}=require('playwright');
const app=process.argv[2],fixtures=process.argv[3],temp=fs.mkdtempSync(path.join(os.tmpdir(),'screenlink-browser-video-'));
execFileSync('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost,IP:127.0.0.1','-keyout',temp+'/key','-out',temp+'/cert'],{stdio:'ignore'});
const assets={'/':'CanvasShell.html','/video':'CanvasShell.html','/app/pure.js':'CanvasShell.js','/app/screen.js':'CanvasScreen.js','/app/canvas.js':'CanvasPlayer.js','/app/mp4box.js':'MP4Demux.js','/app/mux.js':'TSDemux.js','/app/hls.js':'HLSPlayer.js','/app/browser-video.js':'BrowserVideoPlayer.js','/sw.js':'CanvasServiceWorker.js','/app/car-poster.jpg':'CarPoster.jpg','/app/car-ambient.webp':'CarAmbient.webp'};
const token='private-fixture-token',source='master.m3u8';let controls={quality:'auto',volume:1,eq:'normal',revision:1},reports=[],segmentRequests=0;
const server=https.createServer({key:fs.readFileSync(temp+'/key'),cert:fs.readFileSync(temp+'/cert')},(req,res)=>{const u=new URL(req.url,'https://localhost');res.setHeader('Cache-Control','no-store');
 if(assets[u.pathname]){res.setHeader('Content-Type',u.pathname.endsWith('.js')?'application/javascript':u.pathname.endsWith('.jpg')?'image/jpeg':u.pathname.endsWith('.webp')?'image/webp':'text/html');return res.end(fs.readFileSync(path.join(app,assets[u.pathname])));}
 if(u.pathname==='/local-viewer/request'){req.resume();res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({phase:'approved',token}));}
 if(u.searchParams.get('token')!==token){res.statusCode=403;return res.end('{}');}
 if(u.pathname==='/screen/privacy'){req.resume();res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({hidden:true,privacyRevision:1}));}
 if(u.pathname==='/media/state'){res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({viewerControls:controls,active:true,epoch:source,url:'/media/resource/'+source+'?token='+token,command:0,commandKind:'rate',paused:false,start:0,fraction:0}));}
 if(u.pathname==='/media/report'){let data='';req.on('data',d=>data+=d);req.on('end',()=>{const r=JSON.parse(data);reports.push(r);if(controls.playback&&r.viewerPlaybackRevision===controls.playback.revision)delete controls.playback;res.end('{}');});return;}
 if(u.pathname.startsWith('/media/resource/')){const name=path.basename(u.pathname),file=path.join(fixtures,name);if(!fs.existsSync(file)){res.statusCode=404;return res.end();}let bytes=fs.readFileSync(file);
  if(name.endsWith('.m3u8')){res.setHeader('Content-Type','application/vnd.apple.mpegurl');bytes=Buffer.from(bytes.toString().replace(/^(?!#)(.+)$/gm,s=>s.trim()?'/media/resource/'+s.trim()+'?token='+token:s));}else{segmentRequests++;res.setHeader('Content-Type','video/mp2t');}
  return res.end(bytes);}
 res.statusCode=404;res.end();
});
const status=page=>page.evaluate(()=>ScreenLinkCanvasStatus());
(async()=>{let browser;try{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='https://127.0.0.1:'+server.address().port;
 browser=await chromium.launch({headless:true,executablePath:process.env.SCREENLINK_CHROME_BIN||undefined,args:['--no-sandbox','--ignore-certificate-errors','--autoplay-policy=no-user-gesture-required']});
 const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1280,height:800}});
 const page=await context.newPage();page.on('pageerror',e=>console.error('PAGE',e.message));
 await page.goto(base+'/video?engine=browser');
 await page.waitForFunction(()=>ScreenLinkCanvasStatus().engine==='browser'&&ScreenLinkCanvasStatus().mediaStats?.drawn>30,null,{timeout:30000});
 let s=await status(page);assert.equal(s.engine,'browser','?engine=browser selects the browser video player');
 assert(s.mediaWidth===640&&s.mediaHeight===360,'Canvas takes the decoded video size');
 assert(await page.locator('#mediaCanvas').evaluate(c=>c.getContext('2d').getImageData(0,0,c.width,c.height).data.some((v,i)=>i%4!==3&&v>30)),'Video pictures are drawn on the canvas');
 assert.equal(await page.locator('video').count(),1,'Exactly one hidden video element');
 assert(await page.locator('video').evaluate(v=>getComputedStyle(v).display==='none'),'Video element stays hidden; the canvas shows the picture');
 // Smooth progress: media time and drawn pictures advance with wall time.
 const t0=await status(page),w0=Date.now();await page.waitForTimeout(3000);const t1=await status(page),elapsed=(Date.now()-w0)/1000;
 const advance=t1.mediaPosition-t0.mediaPosition,drawnRate=(t1.mediaStats.drawn-t0.mediaStats.drawn)/elapsed;
 assert(advance>elapsed*.85&&advance<elapsed*1.15,'Playback advances in real time: '+advance.toFixed(2)+'s in '+elapsed.toFixed(2)+'s');
 assert(drawnRate>20,'About 30 pictures per second reach the canvas: '+drawnRate.toFixed(1));
 assert.equal(t1.mediaStats.stalls,0,'No waiting/stall events');
 console.log('BROWSER_VIDEO_PLAYS',{advance:+advance.toFixed(2),elapsed:+elapsed.toFixed(2),drawnPerSecond:+drawnRate.toFixed(1)});
 // Sound through Web Audio with phone volume and Normal/Music.
 if(await page.locator('#sound').isVisible())await page.click('#sound');
 await page.waitForFunction(()=>ScreenLinkCanvasStatus().audioState==='running'&&ScreenLinkCanvasStatus().volumeGain!==null,null,{timeout:10000});
 assert.equal(await page.evaluate(()=>document.querySelector('video').muted),false,'Sound enabled on the video element');
 controls={...controls,volume:.4,eq:'music',revision:2};
 await page.waitForFunction(()=>Math.abs(ScreenLinkCanvasStatus().volumeGain-.4)<.02,null,{timeout:6000});
 await page.waitForFunction(()=>ScreenLinkCanvasStatus().eqLowGain===3,null,{timeout:6000});
 controls={...controls,eq:'normal',revision:3};await page.waitForFunction(()=>ScreenLinkCanvasStatus().eqLowGain===0,null,{timeout:6000});
 console.log('BROWSER_VIDEO_SOUND_CONTROLS_PASSED');
 // Phone pause, seek and resume (epoch + source command scoped, acknowledged).
 controls={...controls,playback:{epoch:source,sourceCommand:0,revision:1,paused:true}};
 await page.waitForFunction(()=>ScreenLinkCanvasStatus().mediaPaused,null,{timeout:6000});
 const pausedAt=(await status(page)).mediaPosition;await page.waitForTimeout(1500);assert(Math.abs((await status(page)).mediaPosition-pausedAt)<.05,'Stays paused');
 controls={...controls,playback:{epoch:source,sourceCommand:0,revision:2,seek:12,paused:false}};
 await page.waitForFunction(()=>!ScreenLinkCanvasStatus().mediaPaused&&ScreenLinkCanvasStatus().mediaPosition>12.2,null,{timeout:8000});
 await page.waitForTimeout(1500);assert(!controls.playback,'Phone command acknowledged by report');
 console.log('BROWSER_VIDEO_PHONE_PLAYBACK_PASSED');
 // Quality change restarts at the same position without leaking video elements.
 const before=(await status(page)).mediaPosition;controls={...controls,quality:'720',revision:4};
 await page.waitForFunction(p=>ScreenLinkCanvasStatus().quality==='720'&&ScreenLinkCanvasStatus().mediaPosition>p&&!ScreenLinkCanvasStatus().mediaPaused,before,{timeout:10000});
 assert.equal(await page.locator('video').count(),1,'Old video element removed after restart');
 assert(reports.some(r=>r.ready&&r.position>12),'Phone receives playing position reports');
 console.log('BROWSER_VIDEO_QUALITY_RESTART_PASSED');
 // The WebCodecs player stays available for comparison.
 const compare=await context.newPage();await compare.goto(base+'/video');
 await compare.waitForFunction(()=>ScreenLinkCanvasStatus().mediaStats?.drawn>5,null,{timeout:30000});
 assert.equal((await status(compare)).engine,'webcodecs');assert.equal(await compare.locator('video').count(),0);
 console.log('WEBCODECS_DEFAULT_PASSED');
 await compare.waitForTimeout(2500);
 const lines=reports.flatMap(r=>Array.isArray(r.carLog)?r.carLog:[]);
 assert(lines.some(l=>l.startsWith('summary: webcodecs')),'Car sends a WebCodecs playback summary to the phone log');
 assert(lines.some(l=>l.startsWith('video decoder now prefer-hardware')),'Car reports its video decoder');
 assert(lines.some(l=>l.startsWith('summary: browser')),'Browser player also reports');
 assert(lines.every(l=>typeof l==='string'&&l.length<=220&&!l.includes(token)&&!l.includes('/media/')),'Car log lines are short, without token or media URLs');
 console.log('CAR_LOG_PASSED',lines.slice(0,3));
 console.log('BROWSER_VIDEO_PASSED: /video defaults to WebCodecs; ?engine=browser plays with canvas, Web Audio, phone controls and quality restart.');
}finally{await browser?.close();server.close();fs.rmSync(temp,{recursive:true,force:true});}})().catch(e=>{console.error(e);process.exit(1);});
