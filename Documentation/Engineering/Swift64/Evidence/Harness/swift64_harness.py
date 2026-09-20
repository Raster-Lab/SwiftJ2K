from pathlib import Path
import hashlib, json, os, shlex, subprocess
BASE=Path(__file__).resolve().parents[2]
OUT=BASE/'work/swift64/harness';OUT.mkdir(parents=True,exist_ok=True)
PACKAGE=BASE/'outputs/SwiftJ2K/Integration/ContractHarness'
env=dict(os.environ,DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer',
         CLANG_MODULE_CACHE_PATH=str(OUT/'modules'),SWIFTPM_MODULECACHE_OVERRIDE=str(OUT/'modules'))
records=[]
for label,extra in [('debug',[]),('release',['-c','release']),('asan',['--sanitize','address']),('tsan',['--sanitize','thread'])]:
    command=['xcrun','swift','run','--disable-sandbox','--build-system','swiftbuild','--jobs','2',
             '--cache-path',str(OUT/'cache'),'--config-path',str(OUT/'config'),'--security-path',str(OUT/'security'),
             '--scratch-path',str(OUT/label),'--package-path',str(PACKAGE),*extra,'ContractHarness']
    log=OUT/(label+'.log')
    with log.open('w') as stream:
        result=subprocess.run(command,env=env,stdout=stream,stderr=subprocess.STDOUT)
    assert result.returncode==0,(label,log)
    passes=[line for line in log.read_text().splitlines() if line.startswith('PASS:')]
    assert len(passes)==3,(label,passes)
    records.append(dict(check=label,command=shlex.join(command),exit_code=result.returncode,passes=passes))
    print(label,'passed',flush=True)
(OUT/'results.json').write_text(json.dumps(dict(records=records,source_sha256={str(p.relative_to(BASE/'outputs')):hashlib.sha256(p.read_bytes()).hexdigest() for p in PACKAGE.rglob('*.swift') if '.build' not in p.parts}),indent=2)+'\n')
