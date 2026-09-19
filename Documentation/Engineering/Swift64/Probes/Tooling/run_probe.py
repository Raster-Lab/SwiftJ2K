from pathlib import Path
import json, os, subprocess, sys, time
root = Path(__file__).parent.resolve()
env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer', CLANG_MODULE_CACHE_PATH=str(root/'clang-cache'), SWIFTPM_MODULECACHE_OVERRIDE=str(root/'swift-cache'))
common = ['--package-path', str(root/'Fixture'), '--scratch-path', str(root/'scratch'), '--cache-path', str(root/'cache'), '--config-path', str(root/'config'), '--security-path', str(root/'security'), '--disable-sandbox', '--build-system', 'swiftbuild']
name = sys.argv[1]
args = sys.argv[2:]
if args[0] == 'xcodebuild':
    argv = ['xcrun'] + args
else:
    argv = ['xcrun', 'swift', args[0]] + common + args[1:]
if name.startswith('mixed-failure'):
    env['PROBE_EXPECT_MIXED_FAILURE']='1'
started=time.time()
try:
    p = subprocess.run(argv, env=env, cwd=root/'Fixture', capture_output=True, text=True, timeout=55)
    output=p.stdout+p.stderr
    code=p.returncode
except subprocess.TimeoutExpired as e:
    output=(e.stdout or b'').decode()+(e.stderr or b'').decode()
    code='timeout-55s'
(root/(name+'.log')).write_text(output)
record = {'name':name, 'argv':argv, 'cwd':str(root/'Fixture'), 'exit':code, 'seconds':time.time()-started}
(root/(name+'.json')).write_text(json.dumps(record, indent=2)+'\n')
print(json.dumps(record))
print(output[-5500:])
