#!/usr/bin/env python3
"""Fetch the pinned MIT-licensed browser HLS player and include its license."""
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

root=Path(__file__).resolve().parent.parent
version='1.6.13'
integrity='hNEzjZNHf5bFrUNvdS4/1RjIanuJ6szpWNfTaX5I6WfGynWXGT7K/YQLYtemSvFExzeMdgdE4SsyVLJbd5PcZA=='
archive=fetch(f'https://registry.npmjs.org/hls.js/-/hls.js-{version}.tgz')
assert base64.b64encode(hashlib.sha512(archive).digest()).decode()==integrity,'hls.js package integrity mismatch'
with tarfile.open(fileobj=io.BytesIO(archive),mode='r:gz') as package:
    for source,destination in [('package/dist/hls.min.js','HLSPlayer.js'),('package/LICENSE','HLSPlayer-LICENSE.txt')]:
        (root/'App'/destination).write_bytes(package.extractfile(source).read())
print('Bundled hls.js',version,'with verified package integrity and MIT license')
