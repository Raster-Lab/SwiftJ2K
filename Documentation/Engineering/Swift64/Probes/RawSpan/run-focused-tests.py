from pathlib import Path
import os,subprocess,shlex,json,concurrent.futures
root=Path(__file__).resolve().parent
workspace=root.parents[2]
repos=['SwiftJ2K','SwiftJLS','SwiftJXL','SwiftJLI']
logs=root/'focused-tests';logs.mkdir(exist_ok=True)
env=os.environ.copy();env['DEVELOPER_DIR']='/Applications/Xcode.app/Contents/Developer'
cache=logs/'module-cache';cache.mkdir(exist_ok=True);env['CLANG_MODULE_CACHE_PATH']=str(cache)
def test(name):
 scratch=logs/name/'scratch';cachepath=logs/name/'cache';cachepath.mkdir(parents=True,exist_ok=True)
 args=['xcrun','swift','test','--package-path',str(workspace/'outputs'/name),'--scratch-path',str(scratch),'--cache-path',str(cachepath),'--manifest-cache','local','--disable-sandbox','--build-system','swiftbuild','--jobs','2','--filter','Swift64SampleAccessTests']
 result=subprocess.run(args,env=env,text=True,capture_output=True)
 (logs/(name+'.log')).write_text('$ '+shlex.join(args)+'\nexit: '+str(result.returncode)+'\n'+result.stdout+result.stderr)
 print(name,result.returncode,(result.stdout+result.stderr)[-5000:],flush=True)
 return {'repository':name,'command':shlex.join(args),'argv':args,'exit':result.returncode,'log':str(logs/(name+'.log'))}
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 results=list(pool.map(test,repos))
(logs/'results.json').write_text(json.dumps(results,indent=2))
