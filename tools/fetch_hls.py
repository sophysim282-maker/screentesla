#!/usr/bin/env python3
"""Fetch the pinned MIT-licensed browser HLS player and include its license."""
import base64,hashlib,io,tarfile,urllib.request
from pathlib import Path
root=Path(__file__).resolve().parent.parent
version='1.6.13'
integrity='hNEzjZNHf5bFrUNvdS4/1RjIanuJ6szpWNfTaX5I6WfGynWXGT7K/YQLYtemSvFExzeMdgdE4SsyVLJbd5PcZA=='
archive=urllib.request.urlopen(f'https://registry.npmjs.org/hls.js/-/hls.js-{version}.tgz',timeout=60).read()
assert base64.b64encode(hashlib.sha512(archive).digest()).decode()==integrity,'hls.js package integrity mismatch'
with tarfile.open(fileobj=io.BytesIO(archive),mode='r:gz') as package:
    for source,destination in [('package/dist/hls.min.js','HLSPlayer.js'),('package/LICENSE','HLSPlayer-LICENSE.txt')]:
        (root/'App'/destination).write_bytes(package.extractfile(source).read())
print('Bundled hls.js',version,'with verified package integrity and MIT license')
