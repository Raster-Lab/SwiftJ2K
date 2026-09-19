import concurrent.futures,hashlib,json,os,subprocess
from pathlib import Path
BASE=Path.cwd();OUT=BASE/'work/os27/cli-sbom';OUT.mkdir(exist_ok=True)
def run(n):
 repo=BASE/'outputs'/n;dest=OUT/n;dest.mkdir();prior=BASE/'work/os27/candidate'/n
 env=dict(os.environ,DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer',CLANG_MODULE_CACHE_PATH=str(prior/'clang-cache'),SWIFTPM_MODULECACHE_OVERRIDE=str(prior/'swift-cache'))
 records=[]
 for spec in ['spdx','cyclonedx']:
  cmd=['xcrun','swift','build','--package-path',str(repo),'--scratch-path',str(prior/'build/release'),'--cache-path',str(prior/'cache'),'--config-path',str(prior/'config'),'--security-path',str(prior/'security'),'--disable-sandbox','--build-system','swiftbuild','--jobs','2','-c','release','--product',n.lower(),'--sbom-spec',spec,'--sbom-output-dir',str(dest/spec)]
  with (dest/(spec+'.log')).open('w') as log:r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT)
  files=list((dest/spec).glob('*.json'));assert r.returncode==0 and files,(n,spec,r.returncode)
  for p in files:json.loads(p.read_text())
  records.append({'argv':cmd,'exit_code':r.returncode,'product':n.lower(),'files':{str(p.relative_to(dest)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},'conformance':'unqualified; installed schema bundle absent; see existing field-audit limitations'})
 (dest/'results.json').write_text(json.dumps(records,indent=2)+'\n');print(n,'CLI SBOM generation passed',flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(run,['SwiftJ2K','SwiftJLS','SwiftJXL','SwiftJLI']))
