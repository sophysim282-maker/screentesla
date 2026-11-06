/* Exercise the real animation loop without creating real background timers. */
const fs=require('fs'),vm=require('vm'),assert=require('assert');
global.self=global;let id=0,created=0,cleared=0;const animation=new Map(),intervals=new Map();
global.requestAnimationFrame=fn=>{const key=++id;animation.set(key,fn);return key;};global.cancelAnimationFrame=key=>animation.delete(key);
global.setInterval=fn=>{const key=++id;created++;intervals.set(key,fn);return key;};global.clearInterval=key=>{if(intervals.delete(key))cleared++;};
vm.runInThisContext(fs.readFileSync(process.argv[2]||'App/CanvasPlayer.js','utf8'));
for(let generation=0;generation<20;generation++){
 const p=new ScreenLinkCanvas.CanvasPlayer({getContext:()=>({})});p.paused=false;
 for(let frame=0;frame<600;frame++){const callbacks=[...animation.values()];animation.clear();assert.equal(callbacks.length,1);for(const callback of callbacks)callback();}
 assert.equal(intervals.size,1,'Exactly one audio timer after 600 Canvas frames');assert.equal(animation.size,1);
 p.destroy();assert.equal(intervals.size,0,'Destroy clears every audio timer');assert.equal(animation.size,0,'Destroy cancels animation');
}
assert.equal(created,20,'One scheduler per player, not per frame');assert.equal(cleared,20);console.log('CANVAS_LIFECYCLE_PASSED: 12000 animation frames, 20 player replacements, one audio timer each, zero timers/animations left after destruction.');
