// Build 98/99: the car draws the map itself (Google Maps JavaScript) from the phone's GPS + route,
// reports it to the phone, follows the car, hides with the phone's Car map OFF switch, and falls
// back to the phone's map pictures when Google refuses the key. Google is replaced by a stub.
// Usage: node tools/test_car_map_js.cjs App
const fs=require('fs'),path=require('path'),https=require('https'),assert=require('assert'),os=require('os'),{execFileSync}=require('child_process'),{chromium}=require('playwright');
const app=process.argv[2]||'App',temp=fs.mkdtempSync(path.join(os.tmpdir(),'screenlink-car-map-'));
execFileSync('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost,IP:127.0.0.1','-keyout',temp+'/key','-out',temp+'/cert'],{stdio:'ignore'});
const assets={'/':'CanvasShell.html','/video':'CanvasShell.html','/app/pure.js':'CanvasShell.js','/app/screen.js':'CanvasScreen.js','/app/canvas.js':'CanvasPlayer.js','/app/mp4box.js':'MP4Demux.js','/app/mux.js':'TSDemux.js','/app/hls.js':'HLSPlayer.js','/app/browser-video.js':'BrowserVideoPlayer.js','/sw.js':'CanvasServiceWorker.js','/app/car-poster.jpg':'CarPoster.jpg','/app/car-ambient.webp':'CarAmbient.webp'};
const token='private-fixture-token';
// Encoded polyline for (38.5,-120.2) (40.7,-120.95) (43.252,-126.453) from Google's documentation.
let mapState={mapLive:false,bg:true,bgId:1,screen:'drive',navigating:true,distance:'300 m',instruction:'Turn right',eta:'12 min',remaining:'5.2 km',arrival:'14:32',maneuver:'TURN_RIGHT',then:'TURN_LEFT',lat:11.5564,lng:104.9282,heading:90,mapOn:true,mapKey:'test-key',routeLine:'_p~iF~ps|U_ulLnnqC_mqNvxq`@',routeId:100};
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
const fakeGoogle=(refuse,raster)=>`(()=>{window.__fake={handlers:{},options:{},fit:0,label:null,builds:0,zoom:0,center:null,path:[],edge:[],rotation:null,heading:null,tilt:null,type:'',traffic:false,dest:null,scheme:'',frames:0};
 class Map{constructor(el,o){this.el=el;const f=window.__fake;f.builds++;f.zoom=o.zoom;f.center=o.center;f.scheme=o.colorScheme||'';f.wanted=o.renderingType||'';el.dataset.fakeMap='1';}getRenderingType(){return '${raster?'RASTER':'VECTOR'}'}getZoom(){return window.__fake.zoom}setZoom(z){window.__fake.zoom=z}setCenter(c){window.__fake.center=c;window.__fake.frames++}getCenter(){return window.__fake.center}setMapTypeId(t){window.__fake.type=t}addListener(n,f){window.__fake.handlers[n]=f}setOptions(o){Object.assign(window.__fake.options,o)}getHeading(){return window.__fake.heading||0}fitBounds(b,p){window.__fake.fit++;window.__fake.fitPoints=b.n;window.__fake.heading=0}
  moveCamera(c){const f=window.__fake;f.center=c.center;f.zoom=c.zoom;f.heading=c.heading;f.tilt=c.tilt;f.frames++}}
 class Marker{constructor(o){this.o=o}setMap(m){if(this.o.zIndex===3)window.__fake.dest=m?this.pos:null}setPosition(p){this.pos=p;if(this.o.zIndex===5)window.__fake.marker=p}setIcon(i){if(this.o.zIndex===5){window.__fake.rotation=i.rotation;window.__fake.scale=i.scale}}setLabel(l){if(this.o.zIndex===3)window.__fake.label=l&&l.text}}
 class LatLngBounds{constructor(){this.n=0}extend(){this.n++}}class Point{constructor(x,y){this.x=x;this.y=y}}
 class Polyline{constructor(o){this.o=o}setMap(){}setPath(p){if(this.o.zIndex===2)window.__fake.path=p;else window.__fake.edge=p}}
 class TrafficLayer{setMap(m){window.__fake.traffic=!!m}}
 window.google={maps:{Map,Marker,Polyline,TrafficLayer,LatLngBounds,Point,SymbolPath:{CIRCLE:0,FORWARD_CLOSED_ARROW:2},RenderingType:{VECTOR:'VECTOR',RASTER:'RASTER'},ColorScheme:{LIGHT:'LIGHT',DARK:'DARK'}}};
 const cb=new URL(document.currentScript.src).searchParams.get('callback');
 setTimeout(()=>{${refuse?'window.gm_authFailure&&window.gm_authFailure();':'window[cb]();'}},50);})();`;
(async()=>{let browser;try{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='https://127.0.0.1:'+server.address().port;
 browser=await chromium.launch({headless:true,executablePath:process.env.SCREENLINK_CHROME_BIN||undefined,args:['--no-sandbox','--ignore-certificate-errors']});
 for(const mode of ['vector','raster','refuse']){
  const refuse=mode==='refuse',raster=mode==='raster';
  const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1280,height:720}});let googleKey='';
  await context.route('https://maps.googleapis.com/**',route=>{googleKey=new URL(route.request().url()).searchParams.get('key');route.fulfill({contentType:'application/javascript',body:fakeGoogle(refuse,raster)});});
  const page=await context.newPage();page.on('pageerror',e=>{console.error('PAGE',e.message);process.exitCode=1;});cmds.length=0;mapState={...mapState,mapOn:true,night:false,mapType:'normal',lat:11.5564,lng:104.9282,heading:90,routeId:100};
  await page.goto(base+'/video');
  if(mode==='vector'){
   await page.waitForFunction(()=>!document.getElementById('mapMini').hidden&&!document.getElementById('mapJs').hidden,null,{timeout:15000});
   assert.equal(googleKey,'test-key','Key comes from the phone state, not from the website code');
   const f=await page.evaluate(()=>window.__fake);
   assert.equal(f.wanted,'VECTOR','Asks Google for the 3D (vector) map');assert.equal(f.scheme,'LIGHT','Real Google day colours');assert.equal(f.traffic,true,'Live traffic layer');assert.equal(f.type,'roadmap');
   assert.equal(f.zoom,17.5,'Driving zoom');assert.equal(f.tilt,55,'Tilted 3D view while driving');assert.equal(f.heading,90,'Map turns so the travel direction is up');
   assert.equal(f.marker.lat,11.5564);assert.equal(f.rotation,0,'Car arrow points up on a heading-up map');
   assert(f.center.lng>104.9282&&Math.abs(f.center.lat-11.5564)<1e-6,'Camera looks ahead of the car (car in the lower part)');
   assert.equal(f.path.length,3);assert.equal(f.edge.length,3,'Route has a dark edge line');assert(Math.abs(f.path[2].lat-43.252)<1e-6&&Math.abs(f.path[2].lng+126.453)<1e-6,'Route line decoded');
   assert(Math.abs(f.dest.lat-43.252)<1e-6,'Red pin at the destination');
   await page.waitForFunction(()=>true);assert(cmds.some(c=>c.a==='carmap'&&c.ok==='1'),'Car tells the phone it draws the map');
   assert.equal(await page.evaluate(()=>getComputedStyle(document.getElementById('mapBg')).display),'none','No picture map while the car draws it');
   // Parked: no redraws. Moving: glides in several small steps to the new point.
   const parked=await page.evaluate(async()=>{const a=window.__fake.frames;await new Promise(r=>setTimeout(r,1700));return window.__fake.frames-a;});
   assert(parked<=3,'A parked car does not keep redrawing the map ('+parked+')');
   const before=await page.evaluate(()=>window.__fake.frames);
   mapState={...mapState,lat:11.5566,lng:104.9285,heading:180};
   await page.waitForFunction(()=>Math.abs(window.__fake.marker.lat-11.5566)<1e-9&&window.__fake.heading===180,null,{timeout:6000});
   assert(await page.evaluate(b=>window.__fake.frames-b,before)>=5,'Smooth glide between GPS points');
   assert.equal(await page.evaluate(()=>document.getElementById('mapTurn').hidden),false,'Turn card still shown over the map');
   assert(/<path/.test(await page.evaluate(()=>document.getElementById('mapArrow').innerHTML)),'Turn arrow drawn');
   assert.equal(await page.evaluate(()=>document.getElementById('mapThen').hidden),false,'Then chip shown');
   assert.equal(await page.evaluate(()=>document.getElementById('mapEtaTime').textContent),'12 min');assert.equal(await page.evaluate(()=>document.getElementById('mapEtaMore').textContent),'5.2 km · 14:32');
   if(process.env.CAR_MAP_SHOTS){await page.evaluate(()=>{document.getElementById('mapJs').style.background='#e5e3df';});await page.screenshot({path:process.env.CAR_MAP_SHOTS+'/mini.png'});}
   await page.click('#mapMini');await page.waitForTimeout(700);assert(await page.evaluate(()=>document.body.classList.contains('map-big')),'Tap still swaps map and video');
   assert(await page.evaluate(()=>window.__fake.scale)>1.5,'Bigger car arrow on the big map');
   if(process.env.CAR_MAP_SHOTS)await page.screenshot({path:process.env.CAR_MAP_SHOTS+'/big.png'});
   // Build 100: the big map is touched directly, like the phone.
   const o=await page.evaluate(()=>window.__fake.options);assert.equal(o.gestureHandling,'greedy','Drag, pinch, turn and tilt on the big map');assert.equal(o.clickableIcons,true,'Place names can be tapped');
   await page.click('#mapMini',{position:{x:640,y:300}});await page.waitForTimeout(300);assert(await page.evaluate(()=>document.body.classList.contains('map-big')),'A tap on the big map stays on the map');
   assert.equal(await page.evaluate(()=>document.getElementById('mapUi').hidden),false);assert.equal(await page.evaluate(()=>document.getElementById('mapExit').hidden),false,'Exit button while driving');
   cmds.length=0;await page.evaluate(()=>window.__fake.handlers.click({placeId:'ChIJ-place-1',stop(){window.__fake.stopped=true}}));
   await page.waitForFunction(()=>true);await page.waitForTimeout(200);
   assert(cmds.some(c=>c.a==='poi'&&c.id==='ChIJ-place-1'),'Tapping a place name opens that place by its Google id');assert(await page.evaluate(()=>window.__fake.stopped),'Google\'s own bubble is not shown');
   await page.evaluate(()=>window.__fake.handlers.dragstart());
   assert.equal(await page.evaluate(()=>document.getElementById('mapRecentre').hidden),false,'Re-centre appears after moving the map by hand');
   const held=await page.evaluate(()=>JSON.stringify(window.__fake.center));mapState={...mapState,lat:11.5570,lng:104.9285};
   await page.waitForFunction(()=>Math.abs(window.__fake.marker.lat-11.5570)<1e-9,null,{timeout:6000});
   assert.equal(await page.evaluate(()=>JSON.stringify(window.__fake.center)),held,'The map stays where the finger left it');
   await page.click('#mapRecentre');assert.notEqual(await page.evaluate(()=>JSON.stringify(window.__fake.center)),held,'Re-centre follows the car again');
   // Search like Google Maps: saved places, suggestions while typing, place card with the real name.
   mapState={...mapState,screen:'home',navigating:false,home:'Home street 1',work:'',recents:[{name:'Aeon Mall',address:'Sothearos Blvd'}],suggestions:[],results:[],status:''};
   await page.waitForFunction(()=>document.getElementById('mapTurn').hidden&&!document.getElementById('mapMini').classList.contains('map-drive'),null,{timeout:5000});
   await page.click('#mapQuery');await page.waitForFunction(()=>document.querySelectorAll('#mapList .map-row').length===2,null,{timeout:5000});
   assert.deepEqual(await page.evaluate(()=>[...document.querySelectorAll('#mapList .map-row b')].map(b=>b.textContent)),['Home','Aeon Mall']);
   cmds.length=0;await page.keyboard.type('cof fee');await page.waitForTimeout(500);
   assert(cmds.some(c=>c.a==='type'&&c.q==='cof fee'),'Typing asks the phone for suggestions (space key included)');assert(await page.evaluate(()=>document.body.classList.contains('map-big')),'Typing a space does not leave the map');
   mapState={...mapState,suggestions:[{id:'ChIJ-brown',main:'Brown Coffee',secondary:'Street 51, Phnom Penh'},{id:'ChIJ-b2',main:'Coffee <b>Corner</b>',secondary:''}]};
   await page.waitForFunction(()=>document.querySelector('#mapList .map-row b')?.textContent==='Brown Coffee',null,{timeout:5000});
   assert.equal(await page.evaluate(()=>document.querySelectorAll('#mapList .map-row b')[1].children.length),0,'Place names are shown as text, never as page code');
   if(process.env.CAR_MAP_SHOTS)await page.screenshot({path:process.env.CAR_MAP_SHOTS+'/search.png'});
   cmds.length=0;await page.click('#mapList .map-row');await page.waitForTimeout(200);assert(cmds.some(c=>c.a==='suggest'&&c.id==='ChIJ-brown'),'Tap a suggestion');
   const fits=await page.evaluate(()=>window.__fake.fit);
   mapState={...mapState,suggestions:[],screen:'place',routeId:300,place:{name:'Brown Coffee',address:'Street 51, Phnom Penh',lat:11.5601,lng:104.9255,rating:4.4,count:812,type:'Coffee shop',open:true,hours:'Closes 9 PM',drive:'8 min'},routes:[{time:'8 min',arrive:'14:40',dist:'2.1 km',sel:true},{time:'11 min',arrive:'14:43',dist:'2.6 km',sel:false}]};
   await page.waitForFunction(()=>!document.getElementById('mapPlace').hidden&&document.querySelector('.map-card-head b')?.textContent==='Brown Coffee',null,{timeout:5000});
   const card=await page.evaluate(()=>({label:window.__fake.label,fit:window.__fake.fit,dest:window.__fake.dest,q:document.getElementById('mapQuery').value,routes:document.querySelectorAll('.map-route').length,start:document.querySelector('.map-start').textContent,listHidden:document.getElementById('mapList').hidden}));
   assert.equal(card.label,'Brown Coffee','The place shows its name on the map');assert(card.fit>fits,'Map shows the whole route to the place');assert(Math.abs(card.dest.lat-11.5601)<1e-9);
   assert.equal(card.q,'Brown Coffee');assert.equal(card.routes,2);assert.equal(card.start,'Start · 8 min');assert(card.listHidden);
   if(process.env.CAR_MAP_SHOTS)await page.screenshot({path:process.env.CAR_MAP_SHOTS+'/place.png'});
   cmds.length=0;await page.click('.map-route:nth-child(2)');await page.click('.map-start');await page.waitForTimeout(200);
   assert(cmds.some(c=>c.a==='route'&&c.i==='1')&&cmds.some(c=>c.a==='gostart'),'Pick a route and Start from the car');
   cmds.length=0;await page.click('.map-card-x');await page.waitForTimeout(200);assert(cmds.some(c=>c.a==='close'),'Close the place');
   mapState={...mapState,screen:'drive',navigating:true,place:undefined,routes:[]};
   await page.waitForFunction(()=>document.getElementById('mapPlace').hidden&&document.getElementById('mapRecentre').hidden,null,{timeout:5000});
   mapState={...mapState,night:true,mapType:'satellite'};
   await page.waitForFunction(()=>window.__fake.builds===2&&window.__fake.scheme==='DARK'&&window.__fake.type==='hybrid',null,{timeout:6000});
   const n=await page.evaluate(()=>window.__fake);assert.equal(n.path.length,3,'Route kept after the night rebuild');assert.equal(n.traffic,true);
   assert(await page.evaluate(()=>document.getElementById('mapMini').classList.contains('map-night')),'Night cards');
   if(process.env.CAR_MAP_SHOTS)await page.screenshot({path:process.env.CAR_MAP_SHOTS+'/night.png'});
   mapState={...mapState,mapOn:false};
   await page.waitForFunction(()=>document.getElementById('mapMini').hidden,null,{timeout:5000});
   console.log('CAR_MAP_DRAWN: Google look (3D heading-up, traffic, day/night, route edge, pin), glides, reports to phone, tap swap, Car map OFF hides it.');
   console.log('CAR_MAP_TOUCH: big map is touched directly, tap a place name opens it by name, Re-centre, search with saved places and suggestions, place card, routes, Start.');
  }else if(raster){
   await page.waitForFunction(()=>!document.getElementById('mapJs').hidden&&window.__fake.marker,null,{timeout:15000});
   const f=await page.evaluate(()=>window.__fake);
   assert.equal(f.tilt,0);assert.equal(f.heading,0,'Flat map stays north up');assert.equal(f.zoom,17);assert.equal(f.rotation,90,'On a flat map the arrow turns instead');
   console.log('CAR_MAP_FLAT: when Google gives a flat map, north stays up and the arrow turns (as build 98).');
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
