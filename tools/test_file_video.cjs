// Build 111 (TikTok test): when the phone hands over one plain video file (media state kind "file")
// instead of YouTube's playlist, the car page plays it with the browser's own video element, draws it
// on the same canvas, and asks the phone for the file with byte ranges.
// Usage: node tools/test_file_video.cjs App <file.mp4>
const fs=require('fs'),path=require('path'),https=require('https'),assert=require('assert'),os=require('os'),{execFileSync}=require('child_process'),{chromium}=require('playwright');
const app=process.argv[2]||'App',file=process.argv[3],temp=fs.mkdtempSync(path.join(os.tmpdir(),'screenlink-file-video-'));
assert(file&&fs.existsSync(file),'Pass an mp4 file');const movie=fs.readFileSync(file);
execFileSync('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost,IP:127.0.0.1','-keyout',temp+'/key','-out',temp+'/cert'],{stdio:'ignore'});
const assets={'/':'CanvasShell.html','/video':'CanvasShell.html','/app/pure.js':'CanvasShell.js','/app/screen.js':'CanvasScreen.js','/app/canvas.js':'CanvasPlayer.js','/app/mp4box.js':'MP4Demux.js','/app/mux.js':'TSDemux.js','/app/hls.js':'HLSPlayer.js','/app/browser-video.js':'BrowserVideoPlayer.js','/sw.js':'CanvasServiceWorker.js','/app/car-poster.jpg':'CarPoster.jpg','/app/car-ambient.webp':'CarAmbient.webp'};
const token='private-fixture-token';let ranges=0,reports=0,kind='file';
const server=https.createServer({key:fs.readFileSync(temp+'/key'),cert:fs.readFileSync(temp+'/cert')},(req,res)=>{const u=new URL(req.url,'https://localhost');res.setHeader('Cache-Control','no-store');
 if(assets[u.pathname]){res.setHeader('Content-Type',u.pathname.endsWith('.js')?'application/javascript':u.pathname.endsWith('.jpg')?'image/jpeg':u.pathname.endsWith('.webp')?'image/webp':'text/html');return res.end(fs.readFileSync(path.join(app,assets[u.pathname])));}
 if(u.pathname==='/local-viewer/request'){req.resume();res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({phase:'approved',token}));}
 if(u.pathname==='/media/resource/file1'){const m=/^bytes=(\d+)-(\d*)$/.exec(req.headers.range||'');res.setHeader('Content-Type','video/mp4');res.setHeader('Accept-Ranges','bytes');
  if(m){ranges++;const a=Number(m[1]),b=Math.min(movie.length-1,m[2]?Number(m[2]):movie.length-1);res.statusCode=206;res.setHeader('Content-Range','bytes '+a+'-'+b+'/'+movie.length);return res.end(movie.subarray(a,b+1));}return res.end(movie);}
 if(u.searchParams.get('token')!==token){res.statusCode=403;return res.end('{}');}
 if(u.pathname==='/screen/privacy'){req.resume();res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({hidden:true,privacyRevision:1}));}
 if(u.pathname==='/map/state'){res.setHeader('Content-Type','application/json');return res.end('{}');}
 if(u.pathname==='/media/state'){res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({viewerControls:{quality:'auto',volume:1,eq:'normal',revision:1},active:true,ready:true,epoch:'tiktok-1',url:'/media/resource/file1',kind,command:0,commandKind:'rate',paused:false,position:0,duration:0,start:0,fraction:0,error:''}));}
 if(u.pathname==='/media/report'){reports++;req.resume();req.on('end',()=>res.end('{}'));return;}
 res.statusCode=404;res.end();
});
(async()=>{let browser;try{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='https://127.0.0.1:'+server.address().port;
 browser=await chromium.launch({headless:true,executablePath:process.env.SCREENLINK_CHROME_BIN||undefined,args:['--no-sandbox','--ignore-certificate-errors','--autoplay-policy=no-user-gesture-required']});
 const page=await (await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1280,height:720}})).newPage();page.on('pageerror',e=>{console.error('PAGE',e.message);process.exitCode=1;});
 await page.goto(base+'/video');
 await page.waitForFunction(()=>ScreenLinkCanvasStatus().engine==='browser'&&ScreenLinkCanvasStatus().mediaStats?.drawn>10&&ScreenLinkCanvasStatus().mediaPosition>1,null,{timeout:30000});
 const st=await page.evaluate(()=>ScreenLinkCanvasStatus());
 assert.equal(st.mediaWidth,640);assert.equal(st.mediaHeight,360);assert(st.mediaDuration>3,'File duration known: '+st.mediaDuration);assert.equal(st.mediaError,'');
 await page.waitForFunction(()=>document.getElementById('mediaCover').hidden,null,{timeout:6000});
 assert(reports>0,'The car reports playback to the phone as it does for YouTube');
 console.log('FILE_VIDEO_PASSED: a plain video file plays on the car page through the browser video element ('+st.mediaStats.drawn+' pictures, '+ranges+' range requests).');
}finally{server.closeAllConnections?.();server.close();await browser?.close();fs.rmSync(temp,{recursive:true,force:true});}})().catch(e=>{console.error(e);process.exit(1);});
