#!/usr/bin/env python3
"""Real source resolutions for testing quality selection, not Canvas upscaling."""
from pathlib import Path
import subprocess,sys
root=Path(sys.argv[1]);root.mkdir(parents=True,exist_ok=True)
for name,width,height,bitrate in [('low',256,144,250000),('high',1920,1080,3000000)]:
    subprocess.run(['ffmpeg','-y','-v','error','-f','lavfi','-i',f'testsrc2=size={width}x{height}:rate=30','-f','lavfi','-i','sine=frequency=440:sample_rate=48000','-t','10','-c:v','libx264','-preset','ultrafast','-tune','zerolatency','-pix_fmt','yuv420p','-profile:v','baseline','-g','60','-b:v',str(bitrate),'-maxrate',str(bitrate),'-bufsize',str(bitrate*2),'-c:a','aac','-b:a','96k','-hls_time','2','-hls_playlist_type','vod','-hls_segment_filename',str(root/f'{name}%02d.ts'),str(root/f'{name}.m3u8')],check=True)
(root/'quality.m3u8').write_text('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=400000,RESOLUTION=256x144\nlow.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=3300000,RESOLUTION=1920x1080\nhigh.m3u8\n')
