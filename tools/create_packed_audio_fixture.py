#!/usr/bin/env python3
"""Deterministic alternate packed-AAC HLS regression fixture (no network)."""
import subprocess, sys
from pathlib import Path
root=Path(sys.argv[1]);root.mkdir(parents=True,exist_ok=True)
subprocess.run(['ffmpeg','-y','-v','error','-f','lavfi','-i','sine=frequency=660:sample_rate=48000','-t','10','-c:a','aac','-f','segment','-segment_format','adts','-segment_time','2',str(root/'packed%02d.aac')],check=True)
# A timestamp PRIV frame as specified for packed HLS audio; no URLs or user media.
body=b'com.apple.streaming.transportStreamTimestamp\0'+(0).to_bytes(8,'big')
frame=b'PRIV'+len(body).to_bytes(4,'big')+b'\0\0'+body
size=len(frame);synchsafe=bytes([(size>>21)&127,(size>>14)&127,(size>>7)&127,size&127])
id3=b'ID3\x03\0\0'+synchsafe+frame
files=sorted(root.glob('packed*.aac'))
for p in files:p.write_bytes(id3+p.read_bytes())
(root/'packed-audio.m3u8').write_text('#EXTM3U\n#EXT-X-TARGETDURATION:3\n'+''.join('#EXTINF:2.0,\n'+p.name+'\n' for p in files)+'#EXT-X-ENDLIST\n')
(root/'packed.m3u8').write_text('#EXTM3U\n#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aac",NAME="AAC",DEFAULT=YES,URI="packed-audio.m3u8"\n#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=640x360,AUDIO="aac"\nmaster.m3u8\n')
