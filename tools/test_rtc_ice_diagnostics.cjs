const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync('docs/webrtc-youtube-viewer.html','utf8');
const source=html.split('\n').find(line=>line.startsWith('function candidateSummary('));assert(source);
const context={};vm.createContext(context);vm.runInContext(source,context);
const sdp='v=0\r\na=ice-ufrag:DO-NOT-EXPORT\r\na=ice-pwd:DO-NOT-EXPORT\r\n'+
'a=candidate:1 1 udp 123 127.0.0.1 50000 typ host\r\n'+
'a=candidate:2 1 tcp 123 172.20.10.1 50001 typ host tcptype passive\r\n'+
'a=candidate:3 1 udp 123 192.168.90.2 50002 typ host\r\n'+
'a=candidate:4 1 udp 123 203.0.113.42 50003 typ host\r\n'+
'a=candidate:5 1 udp 123 private-device.local 50004 typ host\r\n';
const result=context.candidateSummary(sdp);assert.equal(result.udp,4);assert.equal(result.tcp,1);
assert(result.details.some(c=>c.address==='127.0.0.1'));assert(result.details.some(c=>c.address==='172.20.10.1'));assert(result.details.some(c=>c.address==='192.168.90.2'));
assert(!JSON.stringify(result).includes('203.0.113.42'));assert(!JSON.stringify(result).includes('private-device.local'));assert(!JSON.stringify(result).includes('DO-NOT-EXPORT'));
assert.equal(context.candidateSummary(sdp.repeat(20)).details.length,16);
console.log('ICE diagnostics passed: loopback/hotspot/other private interfaces distinguishable; credentials, public addresses and mDNS names omitted; bounded details.');
