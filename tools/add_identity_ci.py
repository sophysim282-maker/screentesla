#!/usr/bin/env python3
"""Private-repo CI only: add the website certificate from GitHub Secrets to the IPA.

Reads PEM text from SCREENLINK_TLS_FULLCHAIN and SCREENLINK_TLS_KEY, checks that it is
for car.tesla4khmer.com, not expiring within a day, and that the key matches, then
writes PrivateTLS/ into the main app and the broadcast extension. Never prints keys.
"""
import os, plistlib, subprocess, sys, tempfile, zipfile
source, target = sys.argv[1], sys.argv[2]
chain = os.environ.get('SCREENLINK_TLS_FULLCHAIN', '').strip().replace('\r\n', '\n')
key = os.environ.get('SCREENLINK_TLS_KEY', '').strip().replace('\r\n', '\n')
if 'BEGIN CERTIFICATE' not in chain: sys.exit('SCREENLINK_TLS_FULLCHAIN secret is missing or not a certificate.')
if 'PRIVATE KEY' not in key: sys.exit('SCREENLINK_TLS_KEY secret is missing or not a private key.')
with tempfile.TemporaryDirectory() as temp:
    c, k = os.path.join(temp, 'fullchain.pem'), os.path.join(temp, 'private.key')
    open(c, 'w').write(chain + '\n'); open(k, 'w').write(key + '\n'); os.chmod(k, 0o600)
    openssl = os.environ.get('OPENSSL', 'openssl')
    run = lambda *a: subprocess.run((openssl,) + a[1:] if a[0] == 'openssl' else a, check=True, capture_output=True).stdout
    try:
        if b'does match' not in run('openssl', 'x509', '-in', c, '-noout', '-checkhost', 'car.tesla4khmer.com'):
            sys.exit('The certificate is not for car.tesla4khmer.com.')
        run('openssl', 'x509', '-in', c, '-noout', '-checkend', '86400')
    except subprocess.CalledProcessError:
        sys.exit('The certificate is invalid or expires within a day.')
    if run('openssl', 'x509', '-in', c, '-noout', '-pubkey') != run('openssl', 'pkey', '-in', k, '-pubout'):
        sys.exit('The private key does not belong to this certificate.')
    print('Website certificate:', run('openssl', 'x509', '-in', c, '-noout', '-enddate').decode().strip())
    files = [('fullchain.pem', (chain + '\n').encode()), ('private.key', (key + '\n').encode())]
with zipfile.ZipFile(source) as src:
    names = src.namelist()
    if any('/PrivateTLS/' in n for n in names): sys.exit('Input already contains a certificate.')
    roots = []
    for n in names:
        parts = n.split('/')
        if len(parts) == 3 and parts[0] == 'Payload' and parts[1].endswith('.app') and parts[2] == 'Info.plist':
            roots.append(n[:-len('Info.plist')])
        elif n.endswith('.appex/Info.plist') and '/PlugIns/' in n:
            info = plistlib.loads(src.read(n))
            if info.get('NSExtension', {}).get('NSExtensionPointIdentifier') == 'com.apple.broadcast-services-upload':
                roots.append(n[:-len('Info.plist')])
    if len(roots) != 2: sys.exit('App and broadcast extension not found in IPA.')
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as out:
        for item in src.infolist(): out.writestr(item, src.read(item.filename))
        for root in roots:
            for name, data in files:
                info = zipfile.ZipInfo(root + 'PrivateTLS/' + name); info.external_attr = 0o100600 << 16
                info.compress_type = zipfile.ZIP_DEFLATED; out.writestr(info, data)
print('Added website certificate to', len(roots), 'bundles.')
