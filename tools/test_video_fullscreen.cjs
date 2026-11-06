const fs=require('fs'),assert=require('assert'),{chromium}=require('playwright');
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 try{
  const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
  const html=fs.readFileSync('App/CanvasShell.html','utf8').replace(/<script[\s\S]*?<\/script>/g,'');
  await page.setContent(html);
  await page.evaluate(()=>{window.ScreenLinkScreen={CanvasScreen:class{constructor(){this.framesDrawn=0;}hide(){}destroy(){}}};});
  await page.addScriptTag({content:fs.readFileSync('App/CanvasShell.js','utf8')});
  await page.evaluate(()=>{document.getElementById('mediaStage').requestFullscreen=()=>Promise.reject(new Error('Unavailable'));});
  await page.click('#videoFull');
  let box=await page.locator('#mediaStage').boundingBox();const viewport=page.viewportSize();
  assert.equal(Math.round(box.width),viewport.width);assert.equal(Math.round(box.height),viewport.height);
  assert(await page.locator('#exitVideoFull').isVisible());
  assert.equal(await page.locator('#mediaStage canvas').count(),1);
  assert.equal(await page.locator('#mediaStage header').count(),0);
  await page.click('#exitVideoFull');
  assert(!(await page.locator('#mediaStage').evaluate(e=>e.classList.contains('video-fullscreen'))));
  await page.click('#videoFull');await page.keyboard.press('Escape');
  assert(!(await page.locator('#mediaStage').evaluate(e=>e.classList.contains('video-fullscreen'))));
  assert.deepEqual(errors,[]);console.log('PASS: video-only fullscreen CSS fallback fills viewport; exit and Escape restore layout');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
