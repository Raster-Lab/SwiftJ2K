from pathlib import Path
import subprocess,os,json,shlex
root=Path(__file__).resolve().parent
cache=root/'module-cache'
env=os.environ.copy();env['DEVELOPER_DIR']='/Applications/Xcode.app/Contents/Developer';env['CLANG_MODULE_CACHE_PATH']=str(cache)
records=[]
def run(label,args):
    result=subprocess.run(args,env=env,capture_output=True,text=True)
    records.append({'label':label,'argv':args,'command':shlex.join(args),'exit':result.returncode,'stdout':result.stdout,'stderr':result.stderr})
    (root/(label+'.log')).write_text('$ '+shlex.join(args)+'\nexit: '+str(result.returncode)+'\n'+result.stdout+result.stderr)
    print(label,result.returncode,(result.stdout+result.stderr)[-1800:])
    return result.returncode
for name in ['F01Portable','F02Temporary']:
    binary=root/(name+'-release-macos26.0')
    args=['xcrun','swiftc','-v','-swift-version','6','-strict-concurrency=complete','-module-cache-path',str(cache),'-target','arm64-apple-macosx26.0','-O','-parse-as-library',str(root/(name+'.swift')),'-o',str(binary)]
    if run(name+'-release-macos26.0-compile',args)==0: run(name+'-release-macos26.0-run',[str(binary)])
    run(name+'-strict-memory-safety-macos26.0',['xcrun','swiftc','-swift-version','6','-strict-memory-safety','-warnings-as-errors','-module-cache-path',str(cache),'-target','arm64-apple-macosx26.0','-parse-as-library','-typecheck',str(root/(name+'.swift'))])
    run(name+'-x86_64-macos26.0-typecheck',['xcrun','swiftc','-swift-version','6','-module-cache-path',str(cache),'-target','x86_64-apple-macosx26.0','-parse-as-library','-typecheck',str(root/(name+'.swift'))])
    run(name+'-linkage',['xcrun','otool','-L',str(binary)])
run('compiler',['xcrun','swiftc','--version'])
run('xcode',['xcodebuild','-version'])
run('host',['sw_vers'])
run('target26-info',['xcrun','swiftc','-target','arm64-apple-macosx26.0','-print-target-info'])
(root/'qualification-results.json').write_text(json.dumps(records,indent=2))
