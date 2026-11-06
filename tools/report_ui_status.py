import base64,json,os,pathlib,subprocess,time
repo=os.environ['GITHUB_REPOSITORY'];branch='previews/ui-status-'+os.environ['GITHUB_RUN_ID'];source=os.environ['GITHUB_SHA']
def call(method,path,data=None):
    command=['gh','api','--method',method,'repos/'+repo+'/'+path]
    if data is not None:command+=['--input','-']
    result=subprocess.run(command,input=json.dumps(data) if data is not None else None,text=True,capture_output=True,timeout=15)
    if result.returncode:return None
    try:return json.loads(result.stdout)
    except ValueError:return {}
call('POST','git/refs',{'ref':'refs/heads/'+branch,'sha':source})
last=None;deadline=time.monotonic()+1200
while time.monotonic()<deadline:
    file=pathlib.Path('build/dashboard-ui.log')
    content='Source '+source+'\n'+(file.read_text(errors='replace')[-14000:] if file.exists() else 'Preparing iOS simulator')
    if content!=last:
        try:
            existing=call('GET','contents/ui-status.txt?ref='+branch)
            data={'message':'Simulator progress for '+source[:12],'content':base64.b64encode(content.encode()).decode(),'branch':branch,'author':{'name':'ScreenLink CI','email':'screenlink-ci@users.noreply.github.com'},'committer':{'name':'ScreenLink CI','email':'screenlink-ci@users.noreply.github.com'}}
            if existing and existing.get('sha'):data['sha']=existing['sha']
            if call('PUT','contents/ui-status.txt',data) is not None:last=content
        except Exception:pass
    time.sleep(20)
