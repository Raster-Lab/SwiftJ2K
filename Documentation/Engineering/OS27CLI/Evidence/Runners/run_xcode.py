import concurrent.futures,hashlib,json,os,subprocess
from pathlib import Path
BASE=Path(__file__).resolve().parents[2];OUT=BASE/'work/os27/xcode-final';OUT.mkdir(parents=True,exist_ok=True)
ENV=dict(os.environ,DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
def check(n):
 repo=BASE/'outputs'/n;dest=OUT/n;dest.mkdir();records=[]
 def run(label,argv):
  with (dest/(label+'.log')).open('w') as log:r=subprocess.run(argv,cwd=repo,env=ENV,stdout=log,stderr=subprocess.STDOUT)
  records.append({'label':label,'argv':argv,'cwd':str(repo),'exit_code':r.returncode,'log':label+'.log','outside_sandbox':True})
  (dest/'commands.json').write_text(json.dumps(records,indent=2)+'\n');assert r.returncode==0,(n,label);return (dest/(label+'.log')).read_text()
 common=['-destination','platform=macOS,arch=arm64','-jobs','2','CODE_SIGNING_ALLOWED=NO']
 run('tests',['xcodebuild','test','-scheme',n+'-Package',*common,'-derivedDataPath',str(dest/'DerivedData'),'-resultBundlePath',str(dest/'Tests.xcresult'),'-parallel-testing-enabled','NO'])
 run('summary',['xcrun','xcresulttool','get','test-results','summary','--path',str(dest/'Tests.xcresult')])
 data=json.loads((dest/'summary.log').read_text());assert data['failedTests']==0 and data['skippedTests']==0 and data['passedTests']>0
 (dest/'summary.json').write_text(json.dumps(data,indent=2)+'\n')
 run('cli-release',['xcodebuild','build','-scheme',n.lower(),'-configuration','Release',*common,'-derivedDataPath',str(dest/'DerivedDataCLI')])
 exe=dest/'DerivedDataCLI/Build/Products/Release'/n.lower()
 run('cli-version',[str(exe),'--version']);payload=run('cli-capabilities',[str(exe),'capabilities','--json'])
 assert json.loads(payload)['minimumAppleOS']=='27.0'
 print(n,data['passedTests'],'tests, Xcode CLI built and ran',flush=True)
 return n,{'passed_tests':data['passedTests'],'failed_tests':0,'skipped_tests':0,'cli_exit_code':0,'cli_sha256':hashlib.sha256(exe.read_bytes()).hexdigest()}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:results=dict(pool.map(check,['SwiftJ2K','SwiftJLS','SwiftJXL','SwiftJLI']))
(OUT/'results.json').write_text(json.dumps(results,indent=2)+'\n')
