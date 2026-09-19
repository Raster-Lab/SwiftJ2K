from pathlib import Path
import concurrent.futures,json,subprocess
BASE=Path.cwd();OUT=BASE/'work/os27/cli-final';OUT.mkdir(exist_ok=True)
def test(n):
 binary=BASE/'work/os27/candidate'/n/'build/release/out/Products/Release'/n.lower()
 argv=['python3',str(BASE/'outputs'/n/'Scripts/test-cli.py'),'--binary',str(binary),'--output',str(OUT/n)]
 with (OUT/(n+'.log')).open('w') as log:r=subprocess.run(argv,stdout=log,stderr=subprocess.STDOUT)
 print(n,r.returncode,flush=True);return n,{'argv':argv,'exit_code':r.returncode}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:results=dict(pool.map(test,['SwiftJ2K','SwiftJLS','SwiftJXL','SwiftJLI']))
(OUT/'results.json').write_text(json.dumps(results,indent=2)+'\n');raise SystemExit(0 if all(r['exit_code']==0 for r in results.values()) else 1)
