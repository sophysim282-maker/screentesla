// Build 78: Auto/1080p never pick ultra-wide variants larger than 1920x1088 pixels.
const fs=require('fs'),vm=require('vm'),assert=require('assert');
const scope={self:{}};scope.self=scope;vm.createContext(scope);vm.runInContext(fs.readFileSync(process.argv[2]||'App/CanvasPlayer.js','utf8'),scope);
const pick=(levels,q)=>scope.ScreenLinkCanvas.chooseVariant(levels.map(r=>({RESOLUTION:r,BANDWIDTH:String(r.split('x').reduce((a,b)=>a*b))})),q).RESOLUTION;
const wide=['256x108','640x268','854x358','1280x536','1920x804','2560x1072','3840x1608'];
assert.equal(pick(wide,'auto'),'1920x804','Auto skips 2560x1072');
assert.equal(pick(wide,'1080'),'1920x804','1080p skips 2560x1072');
assert.equal(pick(wide,'720'),'1280x536','720p stays within 1280x720 pixels');
const normal=['256x144','640x360','1280x720','1920x1080','2560x1440'];
assert.equal(pick(normal,'auto'),'1920x1080');assert.equal(pick(normal,'720'),'1280x720');assert.equal(pick(normal,'1080'),'1920x1080');
assert.equal(pick(['1920x1080','2560x1080'],'auto'),'1920x1080');
console.log('PASS: Auto/1080p cap at 1920x1088 pixels; 720p at 1280x720; normal 16:9 unchanged');
