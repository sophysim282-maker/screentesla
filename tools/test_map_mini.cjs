// Build 71: the HTTPS car website plays YouTube with the browser's own video
// player (HLS.js + <video>, as on http://3.3.3.3:8080) drawn on the canvas.
// Usage: node tools/test_browser_video.cjs App <hls fixture dir>
const fs=require('fs'),path=require('path'),https=require('https'),assert=require('assert'),os=require('os'),{execFileSync}=require('child_process'),{chromium}=require('playwright');
const app=process.argv[2],fixtures=process.argv[3],temp=fs.mkdtempSync(path.join(os.tmpdir(),'screenlink-browser-video-'));
execFileSync('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost,IP:127.0.0.1','-keyout',temp+'/key','-out',temp+'/cert'],{stdio:'ignore'});
const assets={'/':'CanvasShell.html','/video':'CanvasShell.html','/app/pure.js':'CanvasShell.js','/app/screen.js':'CanvasScreen.js','/app/canvas.js':'CanvasPlayer.js','/app/mp4box.js':'MP4Demux.js','/app/mux.js':'TSDemux.js','/app/hls.js':'HLSPlayer.js','/app/browser-video.js':'BrowserVideoPlayer.js','/sw.js':'CanvasServiceWorker.js','/app/car-poster.jpg':'CarPoster.jpg','/app/car-ambient.webp':'CarAmbient.webp'};
const token='private-fixture-token',source='master.m3u8';let controls={quality:'auto',volume:1,eq:'normal',revision:1},reports=[],segmentRequests=0,mapState={mapLive:true,screen:'drive',distance:'300 m',instruction:'Turn right onto Norodom Blvd',eta:'14:32',remaining:'12 min'},mapFrames=0,mapCmds=[];
const server=https.createServer({key:fs.readFileSync(temp+'/key'),cert:fs.readFileSync(temp+'/cert')},(req,res)=>{const u=new URL(req.url,'https://localhost');res.setHeader('Cache-Control','no-store');
 if(assets[u.pathname]){res.setHeader('Content-Type',u.pathname.endsWith('.js')?'application/javascript':u.pathname.endsWith('.jpg')?'image/jpeg':u.pathname.endsWith('.webp')?'image/webp':'text/html');return res.end(fs.readFileSync(path.join(app,assets[u.pathname])));}
 if(u.pathname==='/local-viewer/request'){req.resume();res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({phase:'approved',token}));}
 if(u.searchParams.get('token')!==token){res.statusCode=403;return res.end('{}');}
 if(u.pathname==='/screen/privacy'){req.resume();res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({hidden:true,privacyRevision:1}));}
 if(u.pathname==='/map/state'){res.setHeader('Content-Type','application/json');return res.end(JSON.stringify(mapState));}
 if(u.pathname==='/map/bg.jpg'){res.setHeader('Content-Type','image/jpeg');return res.end(fs.readFileSync(path.join(app,'CarPoster.jpg')));}
 if(u.pathname==='/map/frame.jpg'){mapFrames++;res.setHeader('Content-Type','image/jpeg');return res.end(fs.readFileSync(path.join(app,'CarPoster.jpg')));}
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
 const page=await (await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1280,height:720}})).newPage();page.on('pageerror',e=>console.error('PAGE',e.message));
 await page.goto(base+'/video');
 await page.waitForFunction(()=>ScreenLinkCanvasStatus().mediaStats?.drawn>20,null,{timeout:30000});
 await page.waitForFunction(()=>!document.getElementById('mapMini').hidden&&document.getElementById('mapMiniImg').naturalWidth>0,null,{timeout:10000});
 const mini=await page.evaluate(()=>{const m=document.getElementById('mapMini').getBoundingClientRect(),v=document.getElementById('mediaCanvas').getBoundingClientRect();return {mw:m.width,mh:m.height,vw:v.width,turn:document.getElementById('mapText').textContent,dist:document.getElementById('mapDist').textContent,eta:document.getElementById('mapEta').textContent,turnShown:!document.getElementById('mapTurn').hidden};});
 assert(mini.mw>200&&mini.mw<mini.vw*0.5,'Small map sits in the corner of the video');assert.equal(mini.turn,'Turn right onto Norodom Blvd');assert.equal(mini.dist,'300 m');assert.equal(mini.eta,'14:32 · 12 min');assert(mini.turnShown);
 const f0=mapFrames;await page.waitForTimeout(1500);assert(mapFrames-f0>=4,'Map pictures keep refreshing: '+(mapFrames-f0));
 console.log('MAP_MINI_SHOWN',mini);if(process.env.SHOT_DIR)await page.screenshot({path:process.env.SHOT_DIR+'/car-map-small.png'});
 const before=(await status(page)).mediaPosition;
 await page.click('#mapMini');await page.waitForTimeout(700);
 const big=await page.evaluate(()=>{const m=document.getElementById('mapMini').getBoundingClientRect(),v=document.getElementById('mediaCanvas').getBoundingClientRect();return {big:document.body.classList.contains('map-big'),mw:m.width,vw:v.width};});
 assert(big.big&&big.mw>1000&&big.vw<big.mw*0.5,'Tap swaps: big map, small video');if(process.env.SHOT_DIR)await page.screenshot({path:process.env.SHOT_DIR+'/car-map-big.png'});
 await page.click('#mediaCanvas');await page.waitForTimeout(700);
 assert(!(await page.evaluate(()=>document.body.classList.contains('map-big'))),'Tap the small video swaps back');
 const after=(await status(page)).mediaPosition;assert(after>before+1,'Video keeps playing during the swap');
 // Build 88: phone map screen closed / locked -> GPS-moved map picture keeps the rear map.
 mapState={mapLive:false,bg:true,bgId:1,bgLat:11.5621,bgLng:104.9160,bgZoom:16,lat:11.5630,lng:104.9172,heading:90,screen:'drive',distance:'1.2 km',instruction:'Continue on Russian Blvd',eta:'14:40',remaining:'20 min'};
 await page.waitForFunction(()=>!document.getElementById('mapMini').hidden&&!document.getElementById('mapBg').hidden&&document.getElementById('mapBgImg').naturalWidth>0&&/rotate\(/.test(document.getElementById('mapBgImg').style.transform),null,{timeout:8000});
 const bg=await page.evaluate(()=>({car:!document.getElementById('mapBgCar').hidden,live:document.getElementById('mapMiniImg').style.visibility,text:document.getElementById('mapText').textContent,t:document.getElementById('mapBgImg').style.transform}));
 assert(bg.car&&bg.live==='hidden'&&bg.text==='Continue on Russian Blvd'&&/rotate\(-90deg\)/.test(bg.t),'Background map with car marker, heading and directions: '+JSON.stringify(bg));
 if(process.env.SHOT_DIR)await page.screenshot({path:process.env.SHOT_DIR+'/car-map-background.png'});
 console.log('MAP_BACKGROUND_PASSED',bg);
 mapState={mapLive:false,screen:'browse'};await page.waitForFunction(()=>document.getElementById('mapMini').hidden,null,{timeout:6000});
 console.log('MAP_MINI_PASSED: small map with next turn and arrival beside the video, live pictures, tap to swap and back, hides when navigation stops; video kept playing.');
}finally{await browser?.close();server.close();fs.rmSync(temp,{recursive:true,force:true});}})().catch(e=>{console.error(e);process.exit(1);});
