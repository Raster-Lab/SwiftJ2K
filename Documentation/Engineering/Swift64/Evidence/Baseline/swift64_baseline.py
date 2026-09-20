import concurrent.futures, hashlib, io, json, os, re, shlex, subprocess, tarfile
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]
OUT = BASE / 'work/swift64/baseline'
NAMES = ['SwiftJ2K', 'SwiftJLS', 'SwiftJXL', 'SwiftJLI']
OUT.mkdir(parents=True, exist_ok=True)

def execute(name):
    source = BASE / 'outputs' / name
    dest = OUT / name
    repo = dest / 'source'
    repo.mkdir(parents=True, exist_ok=True)
    sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=source).decode().strip()
    archive = subprocess.check_output(['git', 'archive', sha], cwd=source)
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        for member in tar.getmembers():
            assert not member.name.startswith('/') and '..' not in Path(member.name).parts
            assert member.isfile() or member.isdir()
        tar.extractall(repo)
    env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer',
               CLANG_MODULE_CACHE_PATH=str(dest/'module-cache'),
               SWIFTPM_MODULECACHE_OVERRIDE=str(dest/'module-cache'))
    opts = ['--disable-sandbox', '--build-system', 'swiftbuild', '--jobs', '2',
            '--cache-path', str(dest/'cache'), '--config-path', str(dest/'config'),
            '--security-path', str(dest/'security'), '--scratch-path', str(dest/'build')]
    steps = [
        ('clean-debug', ['build', *opts]),
        ('incremental-debug', ['build', *opts]),
        ('discover', ['test', 'list', *opts, '--disable-xctest']),
        ('debug', ['test', *opts, '--disable-xctest', '--xunit-output', str(dest/'debug.xml')]),
        ('release', ['test', *opts, '-c', 'release', '--disable-xctest', '--xunit-output', str(dest/'release.xml')])
    ]
    records = []
    for label, arguments in steps:
        cmd = ['xcrun', 'swift', *arguments]
        log = dest/(label+'.log')
        with log.open('w') as stream:
            result = subprocess.run(cmd, cwd=repo, env=env, stdout=stream, stderr=subprocess.STDOUT)
        text = log.read_text()
        count = re.search(r'Test run with (\d+) tests.*passed', text)
        record = dict(check=label, command=shlex.join(cmd), cwd=str(repo), exit_code=result.returncode,
                      tests=int(count.group(1)) if count else None, log=str(log.relative_to(BASE)))
        records.append(record)
        (dest/'results.json').write_text(json.dumps(dict(source_sha=sha, records=records), indent=2)+'\n')
        print(name, label, result.returncode, record['tests'], flush=True)
        if result.returncode:
            break
    return name, dict(source_sha=sha, records=records)

with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    results = dict(pool.map(execute, NAMES))
(OUT/'results.json').write_text(json.dumps(results, indent=2)+'\n')
raise SystemExit(0 if all(len(r['records']) == 5 and all(v['exit_code'] == 0 for v in r['records']) for r in results.values()) else 1)
