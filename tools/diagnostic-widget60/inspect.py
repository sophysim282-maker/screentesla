import pathlib,plistlib,subprocess,zipfile,json
ipa=next(pathlib.Path('raw').rglob('*.ipa'));dest=pathlib.Path('build/package');dest.mkdir(parents=True)
with zipfile.ZipFile(ipa) as z:
    names=z.namelist();root=next(n[:-10] for n in names if n.startswith('Payload/') and n.count('/')==2 and n.endswith('/Info.plist'))
    print('APP_METADATA',json.dumps(plistlib.loads(z.read(root+'Info.plist')),default=str))
    for n in names:
        if n.endswith('.appex/Info.plist'):
            p=plistlib.loads(z.read(n));print('EXTENSION_METADATA',json.dumps(p,default=str))
            if p.get('NSExtension',{}).get('NSExtensionPointIdentifier')=='com.apple.widgetkit-extension':
                prefix=n[:-10]
                for entry in names:
                    if entry.startswith(prefix) and not entry.endswith('/') and '/PrivateTLS/' not in entry:
                        f=dest/entry;f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(z.read(entry))
                widget=dest/prefix;exe=widget/p['CFBundleExecutable']
                for cmd in [['file',str(exe)],['xcrun','vtool','-show-build',str(exe)],['otool','-L',str(exe)],['otool','-l',str(exe)],['codesign','-dvvv',str(widget)],['codesign','-d','--entitlements',':-',str(widget)]]:
                    r=subprocess.run(cmd,capture_output=True,text=True);print('COMMAND',cmd,'EXIT',r.returncode);print(r.stdout);print(r.stderr)
