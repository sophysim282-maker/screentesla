// Build 115: "My waiting screen". Files the user chose on the phone are shown on the car while no video
// plays, rotate as a slideshow, freeze while a video loads, give way to the video picture with the
// chosen transition, release their files, and come back when the video stops.
// Usage: node tools/test_waiting_screen.cjs App <file.mp4>
const fs=require('fs'),path=require('path'),https=require('https'),assert=require('assert'),os=require('os'),{execFileSync}=require('child_process'),{chromium}=require('playwright');
const app=process.argv[2]||'App',file=process.argv[3],temp=fs.mkdtempSync(path.join(os.tmpdir(),'screenlink-waiting-'));
assert(file&&fs.existsSync(file),'Pass an mp4 file');const movie=fs.readFileSync(file);
execFileSync('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost,IP:127.0.0.1','-keyout',temp+'/key','-out',temp+'/cert'],{stdio:'ignore'});
const assets={'/':'CanvasShell.html','/video':'CanvasShell.html','/app/pure.js':'CanvasShell.js','/app/screen.js':'CanvasScreen.js','/app/canvas.js':'CanvasPlayer.js','/app/mp4box.js':'MP4Demux.js','/app/mux.js':'TSDemux.js','/app/hls.js':'HLSPlayer.js','/app/browser-video.js':'BrowserVideoPlayer.js','/sw.js':'CanvasServiceWorker.js','/app/car-poster.jpg':'CarPoster.jpg','/app/car-ambient.webp':'CarAmbient.webp'};
const token='private-fixture-token';let active=false,list={v:1,transition:'zoom',fit:'fill',hold:3,items:[{id:'pic',kind:'image',mime:'image/jpeg'},{id:'clip',kind:'video',mime:'video/mp4'}]};const asked=[];
const sendFile=(req,res)=>{const m=/^bytes=(\d+)-(\d*)$/.exec(req.headers.range||'');res.setHeader('Content-Type','video/mp4');res.setHeader('Accept-Ranges','bytes');
 if(m){const a=Number(m[1]),b=Math.min(movie.length-1,m[2]?Number(m[2]):movie.length-1);res.statusCode=206;res.setHeader('Content-Range','bytes '+a+'-'+b+'/'+movie.length);return res.end(movie.subarray(a,b+1));}res.end(movie);};
const server=https.createServer({key:fs.readFileSync(temp+'/key'),cert:fs.readFileSync(temp+'/cert')},(req,res)=>{const u=new URL(req.url,'https://localhost');res.setHeader('Cache-Control','no-store');
 if(assets[u.pathname]){res.setHeader('Content-Type',u.pathname.endsWith('.js')?'application/javascript':u.pathname.endsWith('.jpg')?'image/jpeg':u.pathname.endsWith('.webp')?'image/webp':'text/html');return res.end(fs.readFileSync(path.join(app,assets[u.pathname])));}
 if(u.pathname==='/local-viewer/request'){req.resume();res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({phase:'approved',token}));}
 if(u.pathname==='/media/resource/file1')return sendFile(req,res);
 if(u.searchParams.get('token')!==token){res.statusCode=403;return res.end('{}');}
 if(u.pathname==='/waiting/list'){res.setHeader('Content-Type','application/json');return res.end(JSON.stringify(list));}
 if(u.pathname==='/waiting/item/pic'){asked.push('pic@'+u.searchParams.get('v'));res.setHeader('Content-Type','image/jpeg');return res.end(fs.readFileSync(path.join(app,'CarPoster.jpg')));}
 if(u.pathname==='/waiting/item/clip'){asked.push('clip@'+u.searchParams.get('v'));return sendFile(req,res);}
 if(u.pathname==='/screen/privacy'){req.resume();res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({hidden:true,privacyRevision:1}));}
 if(u.pathname==='/map/state'){res.setHeader('Content-Type','application/json');return res.end('{}');}
 if(u.pathname==='/media/state'){res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({viewerControls:{quality:'auto',volume:1,eq:'normal',revision:1},active,ready:active,epoch:active?'video-1':'',url:active?'/media/resource/file1':'',kind:'file',command:0,commandKind:'rate',paused:false,position:0,duration:0,start:0,fraction:0,error:''}));}
 if(u.pathname==='/media/report'){req.resume();req.on('end',()=>res.end('{}'));return;}
 res.statusCode=404;res.end();
});
(async()=>{let browser;try{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='https://127.0.0.1:'+server.address().port;
 browser=await chromium.launch({headless:true,executablePath:process.env.SCREENLINK_CHROME_BIN||undefined,args:['--no-sandbox','--ignore-certificate-errors','--autoplay-policy=no-user-gesture-required']});
 const page=await (await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1280,height:720}})).newPage();page.on('pageerror',e=>{console.error('PAGE',e.message);process.exitCode=1;});
 await page.goto(base+'/video');
 // Waiting: the first file shows over the (empty) video area.
 await page.waitForFunction(()=>{const w=ScreenLinkWaiting(),box=document.getElementById('waitLayer');return w.state==='on'&&!box.hidden&&!box.classList.contains('gone')&&box.querySelector('img.wait-item.on')?.naturalWidth>0;},null,{timeout:25000});
 assert.equal(await page.evaluate(()=>getComputedStyle(document.querySelector('.wait-item')).objectFit),'cover','Fill the screen');
 assert(asked.includes('pic@1'),'The file comes from the phone with the list version');
 if(process.env.CAR_MAP_SHOTS)await page.screenshot({path:process.env.CAR_MAP_SHOTS+'/waiting.png'});
 // Slideshow: after the hold time the video file takes over and plays.
 await page.waitForFunction(()=>ScreenLinkWaiting().index===1&&document.querySelector('video.wait-item.on')?.currentTime>0.2,null,{timeout:12000});
 assert(await page.evaluate(()=>document.querySelector('video.wait-item').muted),'A waiting video plays without sound');
 // A YouTube-style video starts loading: the waiting clip stops on its picture.
 active=true;
 await page.waitForFunction(()=>ScreenLinkWaiting().frozen||ScreenLinkWaiting().state!=='on',null,{timeout:8000});
 // First picture of the video: transition out, files released.
 await page.waitForFunction(()=>ScreenLinkCanvasStatus().mediaStats?.drawn>5&&ScreenLinkWaiting().state==='off'&&document.getElementById('waitLayer').hidden&&ScreenLinkWaiting().shown===0,null,{timeout:30000});
 assert(await page.evaluate(()=>document.getElementById('waitLayer').classList.contains('t-zoom')),'The chosen transition is used');
 const playing=await page.evaluate(()=>ScreenLinkCanvasStatus().mediaPosition);await page.waitForTimeout(700);assert(await page.evaluate(()=>ScreenLinkCanvasStatus().mediaPosition)>playing,'The video keeps playing after the transition');
 // Video stops: the waiting screen comes back.
 active=false;
 await page.waitForFunction(()=>ScreenLinkWaiting().state==='on'&&!document.getElementById('waitLayer').classList.contains('gone')&&ScreenLinkWaiting().shown>0,null,{timeout:12000});
 // The user removes everything on the phone: back to the normal screen.
 list={v:2,transition:'fade',fit:'fit',hold:3,items:[]};
 await page.waitForFunction(()=>ScreenLinkWaiting().items===0&&document.getElementById('waitLayer').hidden,null,{timeout:25000});
 // Dark dip and flash also complete (they use the overlay).
 for(const kind of ['dip','flash']){
  list={v:list.v+1,transition:kind,fit:'fit',hold:30,items:[{id:'pic',kind:'image',mime:'image/jpeg'}]};
  await page.waitForFunction(k=>ScreenLinkWaiting().transition===k&&ScreenLinkWaiting().state==='on'&&!document.getElementById('waitLayer').classList.contains('gone'),kind,{timeout:25000});
  assert.equal(await page.evaluate(()=>getComputedStyle(document.querySelector('.wait-item')).objectFit),'contain','Show all of it');
  active=true;await page.waitForFunction(()=>ScreenLinkWaiting().state==='off'&&document.getElementById('waitLayer').hidden,null,{timeout:30000});
  await page.waitForFunction(()=>Number(getComputedStyle(document.getElementById('waitFx')).opacity)<0.05,null,{timeout:4000});
  active=false;await page.waitForFunction(()=>ScreenLinkWaiting().state==='on',null,{timeout:12000});
 }
 console.log('WAITING_SCREEN_PASSED: own picture and video shown while waiting, slideshow, freeze while loading, zoom / dark dip / flash to the video, files released, back after the video, removed from the phone.');
}finally{server.closeAllConnections?.();server.close();await browser?.close();fs.rmSync(temp,{recursive:true,force:true});}})().catch(e=>{console.error(e);process.exit(1);});
