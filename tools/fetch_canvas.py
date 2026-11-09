#!/usr/bin/env python3
"""Bundle integrity-pinned BSD/Apache demuxers and their licenses; no runtime CDN."""
import base64,hashlib,io,tarfile,urllib.request
from pathlib import Path

def fetch(url,timeout=60,tries=6):
    """Retry temporary registry/network errors (e.g. HTTP 504) with backoff; integrity is still checked."""
    import time,urllib.error
    for attempt in range(tries):
        try: return urllib.request.urlopen(url,timeout=timeout).read()
        except (urllib.error.URLError,TimeoutError,ConnectionError) as error:
            if attempt==tries-1: raise
            print(f'Download retry {attempt+1} after: {error}',flush=True);time.sleep(5*(attempt+1))

root=Path(__file__).resolve().parent.parent/'App'
packages=[
 ('mp4box','0.5.4','GcCH0fySxBurJtvr0dfhz0IxHZjc1RP+F+I8xw+LIwkU1a+7HJx8NCDiww1I5u4Hz6g4eR1JlGADEGJ9r4lSfA==','package/dist/mp4box.all.min.js','MP4Demux.js','MP4Demux-LICENSE.txt'),
 ('mux.js','6.3.0','/QTkbSAP2+w1nxV+qTcumSDN5PA98P0tjrADijIzQHe85oBK3Akhy9AHlH0ne/GombLMz1rLyvVsmrgRxoPDrQ==','package/dist/mux.min.js','TSDemux.js','TSDemux-LICENSE.txt')]
for name,version,digest,source,dest,license_name in packages:
 archive=fetch(f'https://registry.npmjs.org/{name}/-/{name}-{version}.tgz')
 assert base64.b64encode(hashlib.sha512(archive).digest()).decode()==digest, name+' integrity mismatch'
 with tarfile.open(fileobj=io.BytesIO(archive),mode='r:gz') as package:
  (root/dest).write_bytes(package.extractfile(source).read())
  (root/license_name).write_bytes(package.extractfile('package/LICENSE').read())
 print('Bundled',name,version,'with verified integrity and license')
