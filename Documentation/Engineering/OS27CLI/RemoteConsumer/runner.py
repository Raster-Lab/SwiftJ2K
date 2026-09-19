import concurrent.futures,hashlib,json,os,re,shlex,subprocess,sys
from pathlib import Path
BASE=Path(__file__).resolve().parents[2]
OUT=BASE/'work/os27/url-consumers'
PINS=json.loads((BASE/'work/os27/published-source.json').read_text())
assert not OUT.exists(),'Use a fresh consumer directory'
OUT.mkdir(parents=True)
def run(name):
 repo=BASE/'outputs'/name; pin=PINS[name]['sha']; dest=OUT/('RemoteConsumer-'+name)
 source=dest/'Sources/MigrationExample';source.mkdir(parents=True)
 examples=re.findall(r'^```swift\n(.*?)^```',(repo/'MIGRATION.md').read_text(),re.M|re.S);assert len(examples)==1
 filename='Trial.swift' if '@main' in examples[0] else 'main.swift';(source/filename).write_text(examples[0])
 url=f'https://github.com/Raster-Lab/{name}.git'
 manifest='''// swift-tools-version: 6.4
import PackageDescription
let package = Package(name: "RemoteMigrationConsumer", platforms: [.macOS("27.0")],
 dependencies: [.package(url: URL, revision: REV)],
 targets: [.executableTarget(name: "MigrationExample", dependencies: [.product(name: MODULE, package: MODULE)])],
 swiftLanguageModes: [.v6])
'''.replace('URL',json.dumps(url)).replace('REV',json.dumps(pin)).replace('MODULE',json.dumps(name))
 (dest/'Package.swift').write_text(manifest)
 env=dict(os.environ,DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer',CLANG_MODULE_CACHE_PATH=str(dest/'modules'),SWIFTPM_MODULECACHE_OVERRIDE=str(dest/'modules'))
 cmd=['xcrun','swift','run','--disable-sandbox','--build-system','swiftbuild','--jobs','2','--cache-path',str(dest/'cache'),'--config-path',str(dest/'config'),'--security-path',str(dest/'security'),'MigrationExample']
 with (dest/'consumer.log').open('w') as log:r=subprocess.run(cmd,cwd=dest,env=env,stdout=log,stderr=subprocess.STDOUT)
 record=dict(repository=name,url=url,revision=pin,argv=cmd,cwd=str(dest),developer_dir=env['DEVELOPER_DIR'],exit_code=r.returncode,example_sha256=hashlib.sha256(examples[0].encode()).hexdigest(),manifest_sha256=hashlib.sha256(manifest.encode()).hexdigest())
 if r.returncode==0:
  resolved=json.loads((dest/'Package.resolved').read_text());record['resolved']=resolved
  pins=resolved['pins'];assert len(pins)==1 and pins[0]['state']['revision']==pin,(name,pins)
  checkout=next((dest/'.build/checkouts').iterdir())
  actual=subprocess.check_output(['git','rev-parse','HEAD'],cwd=checkout).decode().strip();assert actual==pin
  original=json.loads((BASE/'work/os27/final-inputs.json').read_text())[name]['final_hashes']
  hashes={k:hashlib.sha256((checkout/k).read_bytes()).hexdigest() for k in original}
  assert hashes==original,(name,'tested input drift')
  record.update(checkout_head=actual,tested_input_hashes_match=True,source_files_sha256=hashes,package_resolved_sha256=hashlib.sha256((dest/'Package.resolved').read_bytes()).hexdigest())
 (dest/'result.json').write_text(json.dumps(record,indent=2)+'\n');print(name,r.returncode,flush=True);return name,record
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:results=dict(pool.map(run,PINS))
(OUT/'results.json').write_text(json.dumps(results,indent=2)+'\n')
sys.exit(0 if all(r['exit_code']==0 for r in results.values()) else 1)
