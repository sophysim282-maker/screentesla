#!/usr/bin/env python3
"""Deterministic alternate packed-AAC HLS regression fixture (no network)."""
import subprocess, sys
from pathlib import Path
root=Path(sys.argv[1]);root.mkdir(parents=True,exist_ok=True)
subprocess.run(['ffmpeg','-y','-v','error','-f','lavfi','-i','sine=frequency=660:sample_rate=44100','-t','10','-c:a','aac','-f','segment','-segment_format','adts','-segment_time','2',str(root/'packed%02d.aac')],check=True)
# Complete 44.1 kHz frames plus authoritative continuous transport timestamps.
def synchsafe(n):return bytes([(n>>21)&127,(n>>14)&127,(n>>7)&127,n&127])
clock=0;lines=[]
for p in sorted(root.glob('packed*.aac')):
 data=p.read_bytes();at=0;count=0
 while at+7<=len(data):
  size=((data[at+3]&3)<<11)|(data[at+4]<<3)|(data[at+5]>>5)
  assert size>=7 and at+size<=len(data);at+=size;count+=1
 assert at==len(data)
 body=b'com.apple.streaming.transportStreamTimestamp\0'+round(clock*90000).to_bytes(8,'big')
 frame=b'PRIV'+len(body).to_bytes(4,'big')+b'\0\0'+body
 p.write_bytes(b'ID3\x03\0\0'+synchsafe(len(frame))+frame+data)
 duration=count*1024/44100;lines.append('#EXTINF:'+format(duration,'.6f')+',\n'+p.name+'\n');clock+=duration
(root/'packed-audio.m3u8').write_text('#EXTM3U\n#EXT-X-TARGETDURATION:3\n'+''.join(lines)+'#EXT-X-ENDLIST\n')
(root/'packed.m3u8').write_text('#EXTM3U\n#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aac",NAME="AAC",DEFAULT=YES,URI="packed-audio.m3u8"\n#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=640x360,AUDIO="aac"\nmaster.m3u8\n')
