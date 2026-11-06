const fs=require('fs'),vm=require('vm'),assert=require('assert');
let now=1000,added=0,removed=0;
const listeners={};const scope={performance:{now:()=>now},setTimeout,clearTimeout,setInterval:()=>1,clearInterval(){},requestAnimationFrame:()=>1,cancelAnimationFrame(){},document:{visibilityState:'visible',addEventListener(n,fn){added++;listeners[n]=fn;},removeEventListener(){removed++;}},console};
scope.self=scope;vm.createContext(scope);vm.runInContext(fs.readFileSync('App/CanvasPlayer.js','utf8'),scope);
const player=new scope.ScreenLinkCanvas.CanvasPlayer({getContext:()=>({drawImage(){now+=7;}})});
player.duration=100;player.position=1;
player.profileMetric('demuxMs',5,{segmentStart:0});now+=10;player.profileMetric('demuxMs',15,{segmentStart:2});
let p=player.performanceProfile();assert.equal(p.metrics.demuxMs.mean,10);assert.equal(p.metrics.demuxMs.max,15);assert.equal(p.metrics.demuxMs.count,2);assert.equal(p.events[1].atMs,10);
player.running=true;player.paused=false;player.anchor=0;player.clock=()=>1;player.videoEnd=20;player.finished=true;
player.paint();now+=100;let closed=0;player.frames.push({timestamp:1000000,displayWidth:640,displayHeight:360,close(){closed++;}});player.paint();
p=player.performanceProfile();assert.equal(p.metrics.renderCallbackGapMs.max,100);assert.equal(p.metrics.canvasDrawMs.max,7);assert.equal(closed,1);
scope.document.visibilityState='hidden';listeners.visibilitychange();now+=10000;player.paint();scope.document.visibilityState='visible';listeners.visibilitychange();now+=10000;player.paint();assert.equal(player.performanceProfile().metrics.renderCallbackGapMs.max,100,'Hidden page interval must not be attributed to foreground drawing');
for(let i=0;i<1000;i++){now+=1000;player.profileMetric('demuxMs',i);}
p=player.performanceProfile();assert(player.profileBuckets.length<=12);assert(p.events.length<=60);assert(p.metrics.demuxMs.count<=60);assert(!JSON.stringify(p).includes('http'));
now+=70000;assert.deepEqual(Object.keys(player.performanceProfile().metrics),[],'Expired measurements must leave rolling window');
player.destroy();assert.equal(added,removed,'Destroy removes visibility listener');
console.log('PASS: bounded timestamp-correlated metrics, true draw durations, hidden-page exclusion and listener cleanup');
