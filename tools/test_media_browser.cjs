const http=require('http'),fs=require('fs'),path=require('path'),assert=require('assert'),{chromium}=require('playwright');
const root=process.argv[2],fixtures=process.argv[3];let command=0,paused=false,kind='rate',seek=0,reports=[];
const server=http.createServer((req,res)=>{const u=new URL(req.url,'http://localhost');res.setHeader('Cache-Control','no-store');
 if(u.pathname==='/'){res.setHeader('Content-Type','text/html');return res.end(fs.readFileSync(path.join(root,'MediaPlayer.html')));}
 if(u.pathname==='/media/hls.js'){res.setHeader('Content-Type','application/javascript');return res.end(fs.readFileSync(path.join(root,'HLSPlayer.js')));}
 if(u.pathname==='/media/state'){res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({active:true,epoch:'native-fixture',url:'/media/fixture/master.m3u8',command,commandKind:kind,seek,paused,start:0,fraction:0}));}
 if(u.pathname==='/media/report'){let body='';req.on('data',d=>body+=d);req.on('end',()=>{reports.push(JSON.parse(body));res.end('{}');});return;}
 if(u.pathname.startsWith('/media/fixture/')){const file=path.basename(u.pathname);res.setHeader('Content-Type',file.endsWith('.m3u8')?'application/vnd.apple.mpegurl':'video/mp2t');return res.end(fs.readFileSync(path.join(fixtures,file)));}
 res.statusCode=404;res.end();
});
(async()=>{await new Promise(r=>server.listen(0,'127.0.0.1',r));const browser=await chromium.launch({headless:true,args:['--no-sandbox']});const page=await browser.newPage();page.on('pageerror',e=>console.error(e));await page.goto('http://127.0.0.1:'+server.address().port+'/?token=fixture');
 await page.waitForFunction(()=>document.getElementById('player').currentTime>2,{timeout:15000});
 const started=await page.evaluate(()=>({time:player.currentTime,frames:player.getVideoPlaybackQuality().totalVideoFrames,audio:hls.levels[0].audioCodec,muted:player.muted}));assert(started.frames>30);assert(started.audio.startsWith('mp4a.'));assert(started.muted);console.log('Native video fixture playing:',started);
 command=1;paused=true;await page.waitForFunction(()=>document.getElementById('player').paused,{timeout:5000});const before=await page.evaluate(()=>player.currentTime);await page.waitForTimeout(1000);assert(Math.abs(await page.evaluate(()=>player.currentTime)-before)<0.1);console.log('Native pause command passed');
 command=2;paused=false;kind='seek';seek=6;await page.waitForFunction(()=>document.getElementById('player').currentTime>6.2,{timeout:7000});assert(reports.some(r=>r.ready&&r.duration>9&&r.position>0));
 await page.click('#sound');assert.equal(await page.evaluate(()=>player.muted),false);assert(!await page.evaluate(()=>player.error));console.log('Native seek, playback feedback and sound activation passed');await browser.close();server.close();
})().catch(e=>{console.error(e);server.close();process.exit(1)});
