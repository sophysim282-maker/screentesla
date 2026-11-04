#!/usr/bin/env python3
"""Add a private local-server identity to an unsigned IPA after public CI."""
import argparse, hashlib, plistlib, subprocess, zipfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('input');p.add_argument('output');p.add_argument('identity_directory');a=p.parse_args()
source=Path(a.input).resolve();target=Path(a.output).resolve();identity=Path(a.identity_directory).resolve()
if source==target:raise SystemExit('Use a separate output path.')
cert=identity/'certificate.crt';key=identity/'private.key';chain=identity/'ca_bundle.crt'
def command(args):return subprocess.run(args,check=True,capture_output=True).stdout
command(['openssl','verify','-purpose','sslserver','-verify_hostname','car.tesla4khmer.com','-untrusted',str(chain),str(cert)])
public_cert=command(['openssl','x509','-in',str(cert),'-pubkey','-noout'])
public_key=command(['openssl','pkey','-in',str(key),'-pubout'])
if public_cert!=public_key:raise SystemExit('Certificate and key do not match.')
command(['openssl','x509','-in',str(cert),'-checkend','86400','-noout'])
fullchain=cert.read_bytes().rstrip()+b'\n'+chain.read_bytes().rstrip()+b'\n'
with zipfile.ZipFile(source) as src:
 roots=[]
 for name in src.namelist():
  if name.endswith('/Info.plist') and (name.count('/')==2 or '.appex/Info.plist' in name):
   info=plistlib.loads(src.read(name))
   if info.get('CFBundleVersion')!='38':raise SystemExit('Expected build 38 app and extensions.')
   if name.count('/')==2 or info.get('NSExtension',{}).get('NSExtensionPointIdentifier')=='com.apple.broadcast-services-upload':roots.append(name[:-len('Info.plist')])
 if len(roots)!=2:raise SystemExit('App and broadcast bundles not found.')
 if any('/PrivateTLS/' in n for n in src.namelist()):raise SystemExit('Input already contains an identity.')
 with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as out:
  for item in src.infolist():out.writestr(item,src.read(item.filename))
  for root in roots:
   for name,data in [('fullchain.pem',fullchain),('private.key',key.read_bytes())]:
    info=zipfile.ZipInfo(root+'PrivateTLS/'+name);info.external_attr=0o100600<<16;info.compress_type=zipfile.ZIP_DEFLATED;out.writestr(info,data)
target.chmod(0o600)
print('Private HTTPS identity packaged into app and broadcast only.')
print('SHA256',hashlib.sha256(target.read_bytes()).hexdigest())
