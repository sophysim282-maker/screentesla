// Build 98: the car draws the map itself (Google Maps JavaScript) from the phone's GPS + route,
// reports it to the phone, follows the car, hides with the phone's Car map OFF switch, and falls
// back to the phone's map pictures when Google refuses the key. Google is replaced by a stub.
// Usage: node tools/test_car_map_js.cjs App
const fs=require('fs'),path=require('path'),https=require('https'),assert=require('assert'),os=require('os'),{execFileSync}=require('child_process'),{chromium}=require('playwright');
const app=process.argv[2]||'App',temp=fs.mkdtempSync(path.join(os.tmpdir(),'screenlink-car-map-'));
execFileSync('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost,IP:127.0.0.1','-keyout',temp+'/key','-out',temp+'/cert'],{stdio:'ignore'});
const assets={'/':'CanvasShell.html','/video':'CanvasShell.html','/app/pure.js':'CanvasShell.js','/app/screen.js':'CanvasScreen.js','/app/canvas.js':'CanvasPlayer.js','/app/mp4box.js':'MP4Demux.js','/app/mux.js':'TSDemux.js','/app/hls.js':'HLSPlayer.js','/app/browser-video.js':'BrowserVideoPlayer.js','/sw.js':'CanvasServiceWorker.js','/app/car-poster.jpg':'CarPoster.jpg','/app/car-ambient.webp':'CarAmbient.webp'};
const token='private-fixture-token';
// Encoded polyline for (38.5,-120.2) (40.7,-120.95) (43.252,-126.453) from Google's documentation.
let mapState={mapLive:false,bg:true,bgId:1,screen:'drive',navigating:true,distance:'300 m',instruction:'Turn right',eta:'14:32',remaining:'12 min',lat:11.5564,lng:104.9282,heading:90,mapOn:true,mapKey:'test-key',routeLine:'_p~iF~ps|U_ulLnnqC_mqNvxq`@',routeId:100};
const cmds=[];let frames=0;
const server=https.createServer({key:fs.readFileSync(temp+'/key'),cert:fs.readFileSync(temp+'/cert')},(req,res)=>{const u=new URL(req.url,'https://localhost');res.setHeader('Cache-Control','no-store');
 if(assets[u.pathname]){res.setHeader('Content-Type',u.pathname.endsWith('.js')?'application/javascript':u.pathname.endsWith('.jpg')?'image/jpeg':u.pathname.endsWith('.webp')?'image/webp':'text/html');return res.end(fs.readFileSync(path.join(app,assets[u.pathname])));}
 if(u.pathname==='/local-viewer/request'){req.resume();res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({phase:'approved',token}));}
 if(u.searchParams.get('token')!==token){res.statusCode=403;return res.end('{}');}
 if(u.pathname==='/screen/privacy'){req.resume();res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({hidden:true,privacyRevision:1}));}
 if(u.pathname==='/map/state'){res.setHeader('Content-Type','application/json');return res.end(JSON.stringify(mapState));}
 if(u.pathname==='/map/cmd'){cmds.push(Object.fromEntries(u.searchParams));res.setHeader('Content-Type','application/json');return res.end('{"ok":true}');}
 if(u.pathname==='/map/bg.jpg'||u.pathname==='/map/frame.jpg'){frames++;res.setHeader('Content-Type','image/jpeg');return res.end(fs.readFileSync(path.join(app,'CarPoster.jpg')));}
 if(u.pathname==='/media/state'){res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({viewerControls:{quality:'auto',volume:1,eq:'normal',revision:1},active:false,epoch:'',url:'',command:0}));}
 if(u.pathname==='/media/report'){req.resume();req.on('end',()=>res.end('{}'));return;}
 res.statusCode=404;res.end();
});
const fakeGoogle=refuse=>`(()=>{window.__fake={zoom:0,center:null,path:[],rotation:null};
 class Map{constructor(el,o){this.el=el;window.__fake.zoom=o.zoom;window.__fake.center=o.center;el.dataset.fakeMap='1';}getZoom(){return window.__fake.zoom}setZoom(z){window.__fake.zoom=z}panTo(c){window.__fake.center=c}getCenter(){return window.__fake.center}}
 class Marker{constructor(o){this.icon=o.icon;this.pos=o.position}setPosition(p){this.pos=p;window.__fake.marker=p}getIcon(){return {...this.icon}}setIcon(i){this.icon=i;window.__fake.rotation=i.rotation}}
 class Polyline{constructor(o){}setPath(p){window.__fake.path=p}}
 window.google={maps:{Map,Marker,Polyline,SymbolPath:{FORWARD_CLOSED_ARROW:2}}};
 const cb=new URL(document.currentScript.src).searchParams.get('callback');
 setTimeout(()=>{${refuse?'window.gm_authFailure&&window.gm_authFailure();':'window[cb]();'}},50);})();`;
(async()=>{let browser;try{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='https://127.0.0.1:'+server.address().port;
 browser=await chromium.launch({headless:true,executablePath:process.env.SCREENLINK_CHROME_BIN||undefined,args:['--no-sandbox','--ignore-certificate-errors']});
 for(const refuse of [false,true]){
  const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1280,height:720}});let googleKey='';
  await context.route('https://maps.googleapis.com/**',route=>{googleKey=new URL(route.request().url()).searchParams.get('key');route.fulfill({contentType:'application/javascript',body:fakeGoogle(refuse)});});
  const page=await context.newPage();page.on('pageerror',e=>console.error('PAGE',e.message));cmds.length=0;mapState={...mapState,mapOn:true,lat:11.5564,lng:104.9282,heading:90,routeId:100};
  await page.goto(base+'/video');
  if(!refuse){
   await page.waitForFunction(()=>!document.getElementById('mapMini').hidden&&!document.getElementById('mapJs').hidden,null,{timeout:15000});
   assert.equal(googleKey,'test-key','Key comes from the phone state, not from the website code');
   const f=await page.evaluate(()=>window.__fake);
   assert.equal(f.zoom,17,'Driving zoom');assert.equal(f.marker.lat,11.5564);assert.equal(f.rotation,90,'Arrow turns with the heading');
   assert.equal(f.path.length,3);assert(Math.abs(f.path[2].lat-43.252)<1e-6&&Math.abs(f.path[2].lng+126.453)<1e-6,'Route line decoded');
   await page.waitForFunction(()=>true);assert(cmds.some(c=>c.a==='carmap'&&c.ok==='1'),'Car tells the phone it draws the map');
   assert.equal(await page.evaluate(()=>getComputedStyle(document.getElementById('mapBg')).display),'none','No picture map while the car draws it');
   mapState={...mapState,lat:11.56,lng:104.93,heading:180};
   await page.waitForFunction(()=>window.__fake.marker.lat===11.56&&window.__fake.rotation===180,null,{timeout:5000});
   assert.equal(await page.evaluate(()=>document.getElementById('mapTurn').hidden),false,'Turn card still shown over the map');
   await page.click('#mapMini');await page.waitForTimeout(400);assert(await page.evaluate(()=>document.body.classList.contains('map-big')),'Tap still swaps map and video');
   mapState={...mapState,mapOn:false};
   await page.waitForFunction(()=>document.getElementById('mapMini').hidden,null,{timeout:5000});
   console.log('CAR_MAP_DRAWN: Google map from phone GPS/route, follows car, reports to phone, tap swap, Car map OFF hides it.');
  }else{
   await page.waitForFunction(()=>!document.getElementById('mapMini').hidden&&!document.getElementById('mapBg').hidden,null,{timeout:15000});
   assert(cmds.some(c=>c.a==='carmap'&&c.ok==='0'&&/refused/.test(c.why||'')),'Car tells the phone Google refused the key');
   assert.equal(await page.evaluate(()=>document.getElementById('mapJs').hidden),true);
   console.log('CAR_MAP_FALLBACK: refused key falls back to the phone map picture and is reported.');
  }
  await context.close();
 }
 console.log('CAR_MAP_JS_PASSED');
}finally{server.closeAllConnections?.();server.close();await browser?.close();fs.rmSync(temp,{recursive:true,force:true});}})().catch(e=>{console.error(e);process.exit(1);});
