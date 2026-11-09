// Build 76: a short phone/network pause (like the 8 s WEBSITE SILENT in the car log)
// must not freeze the WebCodecs picture while sound continues.
// Usage: node tools/test_network_pause.cjs App <60 s HLS fixture> [expect-freeze]
const fs=require('fs'),path=require('path'),https=require('https'),assert=require('assert'),os=require('os'),{execFileSync}=require('child_process'),{chromium}=require('playwright');
const app=process.argv[2],fixtures=process.argv[3],expectFreeze=process.argv[4]==='expect-freeze',temp=fs.mkdtempSync(path.join(os.tmpdir(),'screenlink-pause-'));
execFileSync('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost,IP:127.0.0.1','-keyout',temp+'/key','-out',temp+'/cert'],{stdio:'ignore'});
const assets={'/video':'CanvasShell.html','/app/pure.js':'CanvasShell.js','/app/screen.js':'CanvasScreen.js','/app/canvas.js':'CanvasPlayer.js','/app/mp4box.js':'MP4Demux.js','/app/mux.js':'TSDemux.js','/app/hls.js':'HLSPlayer.js','/app/browser-video.js':'BrowserVideoPlayer.js','/sw.js':'CanvasServiceWorker.js','/app/car-poster.jpg':'CarPoster.jpg','/app/car-ambient.webp':'CarAmbient.webp'};
// Car-like links: each media request takes SEGMENT_DELAY_MS (phone fetches from YouTube).
const SLOW=Number(process.env.SEGMENT_DELAY_MS||0);
const token='private-fixture-token';let pausedUntil=0;const held=[];
const server=https.createServer({key:fs.readFileSync(temp+'/key'),cert:fs.readFileSync(temp+'/cert')},(req,res)=>{const u=new URL(req.url,'https://localhost');res.setHeader('Cache-Control','no-store');
 if(assets[u.pathname]){res.setHeader('Content-Type',u.pathname.endsWith('.js')?'application/javascript':u.pathname.endsWith('.jpg')?'image/jpeg':u.pathname.endsWith('.webp')?'image/webp':'text/html');return res.end(fs.readFileSync(process.env.PLAYER&&u.pathname==='/app/canvas.js'?process.env.PLAYER:path.join(app,assets[u.pathname])));}
 const serve=()=>{
  if(u.pathname==='/local-viewer/request'){req.resume();res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({phase:'approved',token}));}
  if(u.searchParams.get('token')!==token){res.statusCode=403;return res.end('{}');}
  if(u.pathname==='/screen/privacy'){req.resume();res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({hidden:true,privacyRevision:1}));}
  if(u.pathname==='/media/state'){res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({viewerControls:{quality:'auto',volume:1,eq:'normal',revision:1},active:true,epoch:'e1',url:'/media/resource/master.m3u8?token='+token,command:0,commandKind:'rate',paused:false,start:0,fraction:0}));}
  if(u.pathname==='/media/report'){req.resume();req.on('end',()=>res.end('{}'));return;}
  if(u.pathname.startsWith('/media/resource/')){const name=path.basename(u.pathname),file=path.join(fixtures,name);if(!fs.existsSync(file)){res.statusCode=404;return res.end();}let bytes=fs.readFileSync(file);
   if(name.endsWith('.m3u8')){res.setHeader('Content-Type','application/vnd.apple.mpegurl');bytes=Buffer.from(bytes.toString().replace(/^(?!#)(.+)$/gm,s=>s.trim()?'/media/resource/'+s.trim()+'?token='+token:s));}
   else res.setHeader('Content-Type','video/mp2t');
   if(req.headers.range){const m=/bytes=(\d+)-(\d+)/.exec(req.headers.range),end=Math.min(+m[2],bytes.length-1);res.statusCode=206;res.setHeader('Content-Range',`bytes ${m[1]}-${end}/${bytes.length}`);bytes=bytes.subarray(+m[1],end+1);}
   if(!name.endsWith('.m3u8')&&SLOW){setTimeout(()=>{if(!res.destroyed)res.end(bytes);},SLOW);return;}
   return res.end(bytes);}
  res.statusCode=404;res.end();
 };
 // During the pause every phone request hangs, as in the car log (WEBSITE SILENT).
 // Build 94: BLACKOUT=1 drops every connection instead (the car's "Failed to fetch").
 if(Date.now()<pausedUntil){if(process.env.BLACKOUT)req.socket.destroy();else held.push(serve);}else serve();
});
(async()=>{let browser;try{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='https://127.0.0.1:'+server.address().port;
 browser=await chromium.launch({headless:true,executablePath:process.env.SCREENLINK_CHROME_BIN||undefined,args:['--no-sandbox','--ignore-certificate-errors','--autoplay-policy=no-user-gesture-required']});
 const page=await (await browser.newContext({ignoreHTTPSErrors:true})).newPage();
 await page.goto(base+'/video?wait='+(process.env.PAUSE_AT||12));
 await page.waitForFunction(()=>ScreenLinkCanvasStatus().engine==='webcodecs'&&ScreenLinkCanvasStatus().mediaPosition>(Number(new URLSearchParams(location.search).get('wait'))||12)&&ScreenLinkCanvasStatus().audioState==='running',null,{timeout:150000});
 if(process.env.STARTUP){
  const st=await page.evaluate(()=>ScreenLinkCanvasStatus());const freezes=st.mediaStats.videoHiccups+st.mediaStats.rebufferCount;
  console.log('STARTUP_FIRST_'+(process.env.PAUSE_AT||12)+'S',{freezes,holds:st.mediaStats.videoHiccups,rebuffers:st.mediaStats.rebufferCount,videoAhead:+st.encodedVideoLead.toFixed(1)});
  if(expectFreeze)assert(freezes>0,'Old player expected to freeze at start');else assert.equal(freezes,0,'No freeze at the start of the video');
  console.log(expectFreeze?'OLD_PLAYER_FREEZES_AT_START':'STARTUP_PASSED: no freeze in the first seconds');return;
 }
 const before=await page.evaluate(()=>ScreenLinkCanvasStatus());
 const PAUSE=Number(process.env.PAUSE_MS||6000);pausedUntil=Date.now()+PAUSE;setTimeout(()=>{for(const f of held.splice(0))f();},PAUSE);
 await page.waitForTimeout(PAUSE+500);
 const after=await page.evaluate(()=>ScreenLinkCanvasStatus());
 const holds=after.mediaStats.videoHiccups-before.mediaStats.videoHiccups,rebuffers=after.mediaStats.rebufferCount-before.mediaStats.rebufferCount,advanced=after.mediaPosition-before.mediaPosition,pictures=after.mediaStats.drawn-before.mediaStats.drawn;
 const result={videoAheadBefore:+before.encodedVideoLead.toFixed(1),advanced:+advanced.toFixed(1),pictures,holds,rebuffers};
 if(process.env.BLACKOUT){await page.waitForTimeout(4000);const later=await page.evaluate(()=>({error:ScreenLinkCanvasStatus().lastPlaybackError?.message||ScreenLinkCanvasStatus().mediaError||'',retries:ScreenLinkCanvasStatus().mediaStats?.fetchRetries||0}));result.playerError=later.error;result.fetchRetries=later.retries;
  if(!expectFreeze)assert.equal(later.error,'','Player must not give up during a short blackout');}
 console.log('DURING_PAUSE',result);
 if(expectFreeze){assert(holds>0||rebuffers>0||pictures<100||result.playerError,'Old player expected to freeze');console.log('OLD_PLAYER_FREEZES_AS_IN_CAR');}
 else{assert.equal(holds,0,'No picture hold during the pause');assert.equal(rebuffers,0,'No rebuffer during the pause');assert(advanced>PAUSE/1000-.5,'Playback keeps running');assert(pictures>PAUSE/1000*22,'About 30 pictures per second keep drawing');console.log('NETWORK_PAUSE_PASSED: phone pause absorbed by read-ahead; picture and sound continued.');}
}finally{await browser?.close();server.close();fs.rmSync(temp,{recursive:true,force:true});}})().catch(e=>{console.error(e);process.exit(1);});
