// Build 144: fast start. On Auto the WebCodecs player plays the first piece from the 720p list, then
// moves up to 1080p at the next piece without stopping the picture or the sound.
// Usage: node tools/test_fast_start.cjs App <fixture dir with master.m3u8, v720/v1080/a lists>
const fs=require('fs'),path=require('path'),https=require('https'),assert=require('assert'),os=require('os'),{execFileSync}=require('child_process'),{chromium}=require('playwright');
const app=process.argv[2],fixtures=process.argv[3],temp=fs.mkdtempSync(path.join(os.tmpdir(),'screenlink-browser-video-'));
execFileSync('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost,IP:127.0.0.1','-keyout',temp+'/key','-out',temp+'/cert'],{stdio:'ignore'});
const assets={'/':'CanvasShell.html','/video':'CanvasShell.html','/app/pure.js':'CanvasShell.js','/app/screen.js':'CanvasScreen.js','/app/canvas.js':'CanvasPlayer.js','/app/mp4box.js':'MP4Demux.js','/app/mux.js':'TSDemux.js','/app/hls.js':'HLSPlayer.js','/app/browser-video.js':'BrowserVideoPlayer.js','/sw.js':'CanvasServiceWorker.js','/app/car-poster.jpg':'CarPoster.jpg','/app/car-ambient.webp':'CarAmbient.webp'};
const token='private-fixture-token',source='master.m3u8';const requested=[];let controls={quality:'auto',volume:1,eq:'normal',revision:1},reports=[],segmentRequests=0;
const server=https.createServer({key:fs.readFileSync(temp+'/key'),cert:fs.readFileSync(temp+'/cert')},(req,res)=>{const u=new URL(req.url,'https://localhost');res.setHeader('Cache-Control','no-store');
 if(assets[u.pathname]){res.setHeader('Content-Type',u.pathname.endsWith('.js')?'application/javascript':u.pathname.endsWith('.jpg')?'image/jpeg':u.pathname.endsWith('.webp')?'image/webp':'text/html');return res.end(fs.readFileSync(path.join(app,assets[u.pathname])));}
 if(u.pathname==='/local-viewer/request'){req.resume();res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({phase:'approved',token}));}
 if(u.searchParams.get('token')!==token){res.statusCode=403;return res.end('{}');}
 if(u.pathname==='/screen/privacy'){req.resume();res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({hidden:true,privacyRevision:1}));}
 if(u.pathname==='/media/state'){res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({viewerControls:controls,active:true,epoch:source,url:'/media/resource/'+source+'?token='+token,command:0,commandKind:'rate',paused:false,start:0,fraction:0}));}
 if(u.pathname==='/media/report'){let data='';req.on('data',d=>data+=d);req.on('end',()=>{const r=JSON.parse(data);reports.push(r);if(controls.playback&&r.viewerPlaybackRevision===controls.playback.revision)delete controls.playback;res.end('{}');});return;}
 if(u.pathname.startsWith('/media/resource/')){const name=path.basename(u.pathname),file=path.join(fixtures,name);if(!fs.existsSync(file)){res.statusCode=404;return res.end();}let bytes=fs.readFileSync(file);
  if(name.endsWith('.m3u8')){res.setHeader('Content-Type','application/vnd.apple.mpegurl');bytes=Buffer.from(bytes.toString().replace(/^(?!#)(.+)$/gm,s=>s.trim()?'/media/resource/'+s.trim()+'?token='+token:s).replace(/URI="([^"]+)"/g,(m,u)=>'URI="/media/resource/'+u+'?token='+token+'"'));}else{segmentRequests++;requested.push(name);res.setHeader('Content-Type','video/mp2t');}
  return res.end(bytes);}
 res.statusCode=404;res.end();
});
const status=page=>page.evaluate(()=>ScreenLinkCanvasStatus());
(async()=>{let browser;try{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='https://127.0.0.1:'+server.address().port;
 browser=await chromium.launch({headless:true,args:['--no-sandbox','--ignore-certificate-errors','--autoplay-policy=no-user-gesture-required']});
 const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1280,height:800}});
 const page=await context.newPage();page.on('pageerror',e=>console.error('PAGE',e.message));page.on("console",m=>console.error("CONSOLE",m.text().slice(0,200)));
 await page.goto(base+'/video?engine=webcodecs');
 await page.waitForFunction(()=>ScreenLinkCanvasStatus().mediaStats?.drawn>10,null,{timeout:30000});
 let s=await status(page);assert.equal(s.mediaHeight,720,'First pictures come from the 720p list: '+s.mediaWidth+'x'+s.mediaHeight);
 const firstVideo=requested.find(n=>n.startsWith('v'));assert(firstVideo.startsWith('v720_00'),'First video piece asked is 720p: '+firstVideo);
 const t0=await status(page),w0=Date.now();
 await page.waitForFunction(()=>ScreenLinkCanvasStatus().mediaHeight===1080,null,{timeout:15000});
 await page.waitForTimeout(3000);const t1=await status(page),elapsed=(Date.now()-w0)/1000;
 const advance=t1.mediaPosition-t0.mediaPosition;
 assert(advance>elapsed*.85&&advance<elapsed*1.15,'Playback runs on through the switch: '+advance.toFixed(2)+'s in '+elapsed.toFixed(2)+'s');
 assert.equal(t1.mediaStats.rebufferCount,0,'No waiting at the switch');
 const v720=requested.filter(n=>n.startsWith('v720')),v1080=requested.filter(n=>n.startsWith('v1080'));
 assert(v720.length<=2,'Only the first piece(s) come from 720p: '+v720.join(','));
 assert(!v1080.includes('v1080_00.ts'),'The 1080p first piece is not downloaded twice');
 assert(t1.mediaStats.audioUnderruns===0,'Sound never ran dry: '+t1.mediaStats.audioUnderruns);
 assert(!t1.mediaError,'No error: '+t1.mediaError);
 console.log('FAST_START_OK',{v720,v1080first:v1080[0],advance:+advance.toFixed(2),elapsed:+elapsed.toFixed(2),drawn:t1.mediaStats.drawn,hiccups:t1.mediaStats.videoHiccups,resets:t1.mediaStats.timestampResets});
}catch(e){console.error(e);try{const p=browser.contexts()[0].pages()[0];const st=await p.evaluate(()=>ScreenLinkCanvasStatus());console.error('STATUS',JSON.stringify({engine:st.engine,phase:st.connectionPhase,err:st.mediaError,h:st.mediaHeight,pos:st.mediaPosition,drawn:st.mediaStats?.drawn}),'REQ',requested.slice(0,12).join(','));}catch(x){console.error(x.message);}process.exitCode=1;}finally{await browser?.close();server.close();}})();
