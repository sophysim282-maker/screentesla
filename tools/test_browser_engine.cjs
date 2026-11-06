// Test-only override: use the pinned official Chrome build when requested.
// The packaged Chromium 140 distribution lacks the H.264 codec used by these fixtures.
const executablePath=process.env.SCREENLINK_CHROME_BIN;
if(executablePath){
 const fs=require('fs'),path=require('path');
 if(!path.isAbsolute(executablePath)||!fs.existsSync(executablePath))throw Error('Pinned test Chrome executable is missing');
 const {chromium}=require('playwright'),launch=chromium.launch.bind(chromium);
 chromium.launch=async options=>{const browser=await launch({...options,executablePath});console.log('TEST_BROWSER_VERSION: '+await browser.version());return browser;};
}
