import concurrent.futures
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]
OUT = BASE / 'work/swift64/migration-examples'
OUT.mkdir(exist_ok=True)
NAMES = ['SwiftJ2K', 'SwiftJLS', 'SwiftJXL', 'SwiftJLI']


def validate(name):
    repo = BASE / 'outputs' / name
    markdown = (repo / 'MIGRATION.md').read_text()
    examples = re.findall(r'^```swift\n(.*?)^```', markdown, re.M | re.S)
    assert len(examples) == 1, (name, len(examples))
    consumer = OUT / ('Consumer-' + name)
    source = consumer / 'Sources/MigrationExample'
    source.mkdir(parents=True, exist_ok=True)
    filename = 'Trial.swift' if '@main' in examples[0] else 'main.swift'
    (source / filename).write_text(examples[0])
    manifest = '''// swift-tools-version: 6.4
import PackageDescription
let package = Package(
    name: "MigrationDocConsumer",
    platforms: [.macOS("26.0")],
    dependencies: [.package(path: REPO_PATH)],
    targets: [.executableTarget(name: "MigrationExample", dependencies: [
        .product(name: MODULE, package: MODULE)
    ])],
    swiftLanguageModes: [.v6]
)
'''.replace('REPO_PATH', json.dumps(str(repo))).replace('MODULE', json.dumps(name))
    (consumer / 'Package.swift').write_text(manifest)
    env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer',
               CLANG_MODULE_CACHE_PATH=str(consumer / 'module-cache'),
               SWIFTPM_MODULECACHE_OVERRIDE=str(consumer / 'module-cache'))
    args = ['xcrun', 'swift', 'run', '--disable-sandbox', '--build-system', 'swiftbuild',
            '--jobs', '2', '--cache-path', str(consumer / 'cache'),
            '--config-path', str(consumer / 'config'),
            '--security-path', str(consumer / 'security'), 'MigrationExample']
    log = OUT / (name + '.log')
    with log.open('w') as output:
        result = subprocess.run(args, cwd=consumer, env=env, stdout=output, stderr=subprocess.STDOUT)
    checked = subprocess.run(['git', 'diff', '--check'], cwd=repo, capture_output=True, text=True)
    changed = subprocess.check_output(['git', 'diff', '--name-only', 'HEAD'], cwd=repo).decode().splitlines()
    changed += subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard'], cwd=repo).decode().splitlines()
    changed = [p for p in changed if p.endswith('.md') and not p.startswith('Documentation/Engineering/Swift64/')]
    missing = []
    link_count = 0
    for filename in changed:
        path = repo / filename
        for link in re.findall(r'\]\(([^)\s]+)\)', path.read_text()):
            if re.match(r'[A-Za-z][A-Za-z0-9+.-]*:', link) or link.startswith('#'):
                continue
            link_count += 1
            if not (path.parent / link.split('#')[0]).exists():
                missing.append((filename, link))
    record = dict(exit_code=result.returncode, command=shlex.join(args), cwd=str(consumer),
                  toolchain=env['DEVELOPER_DIR'], example_sha256=hashlib.sha256(examples[0].encode()).hexdigest(),
                  diff_check_exit=checked.returncode, relative_links=link_count, missing_links=missing,
                  files=sorted(changed), log=str(log.relative_to(BASE)))
    print(name, json.dumps(record), flush=True)
    return name, record


with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    results = dict(pool.map(validate, NAMES))
(OUT / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
sys.exit(0 if all(r['exit_code'] == 0 and r['diff_check_exit'] == 0 and not r['missing_links']
                  for r in results.values()) else 1)
