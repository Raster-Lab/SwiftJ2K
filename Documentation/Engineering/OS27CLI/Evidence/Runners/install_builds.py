import concurrent.futures,hashlib,json,os,subprocess
from pathlib import Path
BASE=Path.cwd();OUT=BASE/'work/os27/install-builds';OUT.mkdir(exist_ok=True)
def run(n):
 dest=OUT/n;dest.mkdir();repo=BASE/'outputs'/n
 env=dict(os.environ,DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer',CLANG_MODULE_CACHE_PATH=str(dest/'modules'),SWIFTPM_MODULECACHE_OVERRIDE=str(dest/'modules'))
 argv=[str(repo/'Scripts/install-cli.sh'),'--prefix','/usr/local','--destdir',str(dest/'stage'),'--scratch-path',str(dest/'build'),'--disable-package-sandbox']
 with (dest/'install.log').open('w') as log:r=subprocess.run(argv,env=env,stdout=log,stderr=subprocess.STDOUT)
 record={'argv':argv,'environment':{k:env[k] for k in ['DEVELOPER_DIR','CLANG_MODULE_CACHE_PATH','SWIFTPM_MODULECACHE_OVERRIDE']},'exit_code':r.returncode}
 (dest/'result.json').write_text(json.dumps(record,indent=2)+'\n');assert r.returncode==0,n
 exe=dest/'stage/usr/local/bin'/n.lower();page=dest/'stage/usr/local/share/man/man1'/(n.lower()+'.1')
 assert page.read_bytes()==(repo/'ManPages'/(n.lower()+'.1')).read_bytes()
 v=subprocess.run([str(exe),'--version'],text=True,capture_output=True);assert v.returncode==0
 record.update(binary_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),manual_sha256=hashlib.sha256(page.read_bytes()).hexdigest(),version_stdout=v.stdout,version_exit_code=0)
 (dest/'result.json').write_text(json.dumps(record,indent=2)+'\n');print(n,'built and installed binary + manual into staging',flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(run,['SwiftJ2K','SwiftJLS','SwiftJXL','SwiftJLI']))
