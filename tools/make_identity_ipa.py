#!/usr/bin/env python3
"""Test fixture only: fake IPAs with a throwaway identity (never a real key)."""
import sys,zipfile
out,chain,key,mode=sys.argv[1:5]
with zipfile.ZipFile(out,'w') as z:
    z.writestr(zipfile.ZipInfo('Payload/ScreenLink.app/Info.plist'),b'plist',compress_type=zipfile.ZIP_STORED)
    z.writestr('Payload/ScreenLink.app/HLSPlayer.js',b'x'*5000,compress_type=zipfile.ZIP_DEFLATED)
    if mode!='raw':
        z.write(chain,'Payload/ScreenLink.app/PrivateTLS/fullchain.pem',compress_type=zipfile.ZIP_DEFLATED)
        z.write(key,'Payload/ScreenLink.app/PrivateTLS/private.key',compress_type=zipfile.ZIP_STORED)
        z.writestr('Payload/ScreenLink.app/PlugIns/X.appex/PrivateTLS/fullchain.pem',b'decoy',compress_type=zipfile.ZIP_STORED)
