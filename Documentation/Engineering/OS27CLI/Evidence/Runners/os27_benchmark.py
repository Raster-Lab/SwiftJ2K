import concurrent.futures, hashlib, json, os, shlex, statistics, subprocess
from pathlib import Path

BASE=Path(__file__).resolve().parents[2]
OUT=BASE/'work/os27/benchmark'
OUT.mkdir(parents=True,exist_ok=True)
SOURCES={'baseline':BASE/'work/os27/baseline/SwiftJ2K','candidate':BASE/'outputs/SwiftJ2K'}
SWIFT='''import Foundation
import SwiftJ2K

func trial(_ width: Int) throws -> [String: Double] {
    let height = width - 1
    let descriptor = try SwiftJ2K.ImageDescriptor.greyscale16(width: width, height: height,
        meaningfulBits: 16, rowBytes: width * 2 + 8)
    let start = DispatchTime.now().uptimeNanoseconds
    let destination = try SwiftJ2K.ImageDestination.allocate(descriptor: descriptor)
    let allocated = DispatchTime.now().uptimeNanoseconds
    let image = try destination.writeUInt16 { x, y in UInt16((x + y * width) & 65535) }
    let written = DispatchTime.now().uptimeNanoseconds
    var sum: UInt64 = 0
    for y in 0..<height {
        for x in 0..<width { sum += UInt64(try image.sampleUInt16(x: x, y: y)) }
    }
    let read = DispatchTime.now().uptimeNanoseconds
    let count = UInt64(width * height)
    let cycles = count / 65536, remainder = count % 65536
    let expected = cycles * 65535 * 65536 / 2 + remainder * (remainder == 0 ? 0 : remainder - 1) / 2
    guard sum == expected else { throw SwiftJ2K.CodecError(.internalFailure, "Benchmark sample mismatch") }
    return ["allocate_ns": Double(allocated-start), "write_ns": Double(written-allocated),
            "read_ns": Double(read-written), "checksum": Double(sum),
            "pixel_capacity": Double(descriptor.requiredByteCount),
            "thermal_state": Double(ProcessInfo.processInfo.thermalState.rawValue)]
}
while let line = readLine() {
    guard let width = Int(line), width > 1 && width <= 2048 else { break }
    let bytes = try JSONSerialization.data(withJSONObject: trial(width), options: [.sortedKeys])
    FileHandle.standardOutput.write(bytes + Data([10]))
}
'''

def build(item):
    name,path=item
    dest=OUT/name;source=dest/'Sources/StorageBench'
    source.mkdir(parents=True,exist_ok=True)
    (source/'main.swift').write_text(SWIFT)
    manifest='''// swift-tools-version: 6.4
import PackageDescription
let package = Package(name: "StorageBench", platforms: [.macOS("27.0")],
 dependencies: [.package(name: "SwiftJ2K", path: PATH)],
 targets: [.executableTarget(name: "StorageBench", dependencies: [.product(name:"SwiftJ2K",package:"SwiftJ2K")])],
 swiftLanguageModes:[.v6])
'''.replace('PATH',json.dumps(str(path)))
    (dest/'Package.swift').write_text(manifest)
    env=dict(os.environ,DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer',
             CLANG_MODULE_CACHE_PATH=str(dest/'modules'),SWIFTPM_MODULECACHE_OVERRIDE=str(dest/'modules'))
    cmd=['xcrun','swift','build','--disable-sandbox','--build-system','swiftbuild','-c','release','--jobs','2',
         '--cache-path',str(dest/'cache'),'--config-path',str(dest/'config'),'--security-path',str(dest/'security')]
    with (dest/'build.log').open('w') as log:
        result=subprocess.run(cmd,cwd=dest,env=env,stdout=log,stderr=subprocess.STDOUT)
    assert result.returncode == 0,(name,result.returncode)
    binary=subprocess.check_output([*cmd,'--show-bin-path'],cwd=dest,env=env).decode().strip()
    exe=Path(binary)/'StorageBench'
    return name,dict(executable=str(exe),size_bytes=exe.stat().st_size,command=shlex.join(cmd),
                     source_sha256=hashlib.sha256((path/'Sources/SwiftJ2K/Image.swift').read_bytes()).hexdigest())

with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    builds=dict(pool.map(build,SOURCES.items()))
(OUT/'builds.json').write_text(json.dumps(builds,indent=2)+'\n')
processes={}
resources={}
for name,record in builds.items():
    resources[name]=(OUT/(name+'-resources.log')).open('w')
    processes[name]=subprocess.Popen(['/usr/bin/time','-l',record['executable']],stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,stderr=resources[name],text=True,bufsize=1)
def run(name,width):
    p=processes[name];p.stdin.write(str(width)+'\n');p.stdin.flush()
    line=p.stdout.readline()
    assert line,(name,p.poll())
    return json.loads(line)
records=[]
for width in [64,512,2048]:
    for _ in range(5):
        for name in processes:run(name,width)
    for iteration in range(20):
        for name in (['baseline','candidate'] if iteration%2==0 else ['candidate','baseline']):
            record=dict(name=name,width=width,iteration=iteration,**run(name,width))
            record['total_ns']=record['allocate_ns']+record['write_ns']+record['read_ns']
            records.append(record)
            (OUT/'raw-timings.json').write_text(json.dumps(records,indent=2)+'\n')
    print('Completed interleaved sample access case',width,flush=True)
exits={}
for name,p in processes.items():
    p.stdin.close();exits[name]=p.wait();resources[name].close()
summary=[]
for width in [64,512,2048]:
    for metric in ['allocate_ns','write_ns','read_ns','total_ns']:
        data={name:[r[metric] for r in records if r['name']==name and r['width']==width] for name in processes}
        medians={name:statistics.median(v) for name,v in data.items()}
        summary.append(dict(width=width,metric=metric,medians=medians,
            candidate_change_percent=(medians['candidate']/medians['baseline']-1)*100,
            p95={name:sorted(v)[18] for name,v in data.items()},
            minimum={name:min(v) for name,v in data.items()},maximum={name:max(v) for name,v in data.items()}))
result=dict(method='Same-host release executables; 5 warmups then 20 interleaved measurements per case; 5% median/peak-memory regression investigation threshold set by contract PERF-03 before execution. Shared Image.swift evaluated through SwiftJ2K, not a codec-throughput or multi-platform claim.',
            builds=builds,process_exit_codes=exits,records=records,summary=summary)
(OUT/'results.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(summary,indent=2))
raise SystemExit(0 if all(code==0 for code in exits.values()) else 1)
