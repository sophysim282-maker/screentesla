#!/usr/bin/env python3
"""Pinned WebRTC community binary, compiled from upstream WebRTC; verify before use."""
import hashlib,urllib.request,zipfile,io,tempfile,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parent.parent
url='https://github.com/stasel/WebRTC/releases/download/156.0.0/WebRTC-M156.xcframework.zip'
digest='43c2a6f7a650185bbc911d7605a979589671886e8fc0ac283f54fdf3f511dc46'
archive=urllib.request.urlopen(url,timeout=120).read()
assert hashlib.sha256(archive).hexdigest()==digest,'WebRTC archive integrity mismatch'
with zipfile.ZipFile(io.BytesIO(archive)) as z:
    for member in z.infolist():
        target=(root/'Vendor'/member.filename).resolve()
        assert target.is_relative_to((root/'Vendor').resolve()),'Invalid archive path'
    (root/'Vendor').mkdir(exist_ok=True)
    if sys.platform=='darwin':
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'WebRTC.zip';path.write_bytes(archive)
            subprocess.run(['ditto','-x','-k',str(path),str(root/'Vendor')],check=True)
    else:
        z.extractall(root/'Vendor')
notice='WebRTC M156.0.0, community binary distribution by https://github.com/stasel/WebRTC . Source: https://webrtc.googlesource.com/src/ . Archive SHA-256: '+digest+'\n\n'
(root/'App'/'WebRTC-ThirdParty.txt').write_text(notice+(root/'Vendor'/'WebRTC.xcframework'/'LICENSE').read_text())
print('WebRTC M156 archive integrity and license verified')
