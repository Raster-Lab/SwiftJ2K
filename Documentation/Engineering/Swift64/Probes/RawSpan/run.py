from pathlib import Path
import subprocess, os, json, shlex
root=Path(__file__).resolve().parent
cache=root/'module-cache'; cache.mkdir(exist_ok=True)
env=os.environ.copy(); env['DEVELOPER_DIR']='/Applications/Xcode.app/Contents/Developer'
env['CLANG_MODULE_CACHE_PATH']=str(cache)
records=[]
def run(label,args):
    result=subprocess.run(args,env=env,capture_output=True,text=True)
    records.append({'label':label,'argv':args,'command':shlex.join(args),'exit':result.returncode,'stdout':result.stdout,'stderr':result.stderr})
    (root/(label+'.log')).write_text('$ '+shlex.join(args)+'\nexit: '+str(result.returncode)+'\n'+result.stdout+result.stderr)
    print(label,result.returncode, (result.stdout+result.stderr)[-2400:])
    return result.returncode
for name in ['F01Portable','F01ByteOrder','F02Temporary']:
    for target in ['26.0','27.0']:
        stem=f'{name}-macos{target}'
        executable=root/stem
        args=['xcrun','swiftc','-swift-version','6','-strict-concurrency=complete','-module-cache-path',str(cache),'-target',f'arm64-apple-macosx{target}','-parse-as-library',str(root/(name+'.swift')),'-o',str(executable)]
        if run(stem+'-compile',args)==0:
            run(stem+'-run',[str(executable)])
(root/'results.json').write_text(json.dumps(records,indent=2))
