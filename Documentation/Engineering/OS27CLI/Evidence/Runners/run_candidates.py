from pathlib import Path
import concurrent.futures,json,subprocess
BASE=Path.cwd();OUT=BASE/'work/os27/candidate';OUT.mkdir(parents=True,exist_ok=True)
def run(n):
 repo=BASE/'outputs'/n;argv=['bash','Scripts/validate.sh','--checks','all','--jobs','2','--repetitions','5','--disable-package-sandbox','--output',str(OUT/n)]
 with (OUT/(n+'.log')).open('w') as log:r=subprocess.run(argv,cwd=repo,stdout=log,stderr=subprocess.STDOUT)
 result={'argv':argv,'cwd':str(repo),'exit_code':r.returncode};print(n,r.returncode,flush=True);return n,result
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:results=dict(pool.map(run,['SwiftJ2K','SwiftJLS','SwiftJXL','SwiftJLI']))
(OUT/'results.json').write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(0 if all(r['exit_code']==0 for r in results.values()) else 1)
