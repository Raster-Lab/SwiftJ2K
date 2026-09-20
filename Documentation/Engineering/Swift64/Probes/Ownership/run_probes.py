from pathlib import Path
import json, os, subprocess

root = Path(__file__).resolve().parent
env = os.environ.copy()
env['DEVELOPER_DIR'] = '/Applications/Xcode.app/Contents/Developer'
cache = root / 'module-cache'
cache.mkdir(exist_ok=True)
sources = {
    'F03_containers_import': 'import Containers\n',
    'F03_rigid_array': 'let array = RigidArray<Int>(capacity: 4)\n',
    'F03_F06_unique_iteration': '''
struct Element: ~Copyable { var number: Int }
func run() {
    var array = UniqueArray<Element>(capacity: 3)
    array.append(Element(number: 1))
    array.append(Element(number: 2))
    var total = 0
    for element in array { total += element.number }
    precondition(total == 3 && array.count == 2)
    print("F03/F06: noncopyable element iteration passed")
}
run()
''',
    'F04_unique_box': '''
struct Element: ~Copyable { var number: Int }
func run() {
    var box = UniqueBox(Element(number: 3))
    box.value.number += 1
    let value = box.consume()
    precondition(value.number == 4)
    print("F04: unique box mutation and consume passed")
}
run()
''',
    'F05_accessors': '''
struct Element: ~Copyable { var number: Int }
struct Wrapper: ~Copyable {
    var storage: Element
    var element: Element {
        borrow { storage }
        mutate { &storage }
    }
}
func run() {
    var wrapper = Wrapper(storage: Element(number: 3))
    wrapper.element.number += 1
    precondition(wrapper.element.number == 4)
    print("F05: value-type borrow/mutate passed")
}
run()
''',
    'F07_references': '''
func run() {
    var number = 3
    do {
        var reference = MutableRef(&number)
        reference.value += 1
    }
    let reference = Ref(number)
    precondition(reference.value == 4)
    print("F07: scoped mutable and read references passed")
}
run()
''',
    'F08_async_defer': '''
enum ProbeError: Error { case requested }
actor Recorder {
    var count = 0
    func finish() { count += 1 }
}
func operation(_ recorder: Recorder, mode: Int) async throws {
    defer { await recorder.finish() }
    if mode == 0 { return }
    if mode == 1 { throw ProbeError.requested }
    try Task.checkCancellation()
}
@main struct Probe {
    static func main() async throws {
        let recorder = Recorder()
        try await operation(recorder, mode: 0)
        do { try await operation(recorder, mode: 1) }
        catch ProbeError.requested { }
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            do { try await operation(recorder, mode: 2) }
            catch is CancellationError { return }
            catch { preconditionFailure("Unexpected error") }
            preconditionFailure("Cancellation not propagated")
        }
        await cancelled.value
        let count = await recorder.count
        precondition(count == 3)
        print("F08: async defer completed on return, throw and cancellation")
    }
}
''',
    'F09_cancellation_shield': '''
@main struct Probe {
    static func main() async throws {
        let operation = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            precondition(Task.isCancelled)
            try await withTaskCancellationShield {
                await Task.yield()
                precondition(!Task.isCancelled)
                try Task.checkCancellation()
            }
            precondition(Task.isCancelled)
        }
        try await operation.value
        print("F09: shield masks observation only inside scoped cleanup")
    }
}
''',
    'F10_optional_ref': '''
struct Element: ~Copyable { var number: Int }
func trial(_ optional: borrowing Element?) -> Int? {
    optional.ref.map { $0.value.number }
}
''',
    'F10_optional_put': '''
struct Element: ~Copyable { var number: Int }
func trial(_ optional: inout Element?) {
    var reference = optional.put(Element(number: 3))
    reference.value.number += 1
}
''',
    'F10_optional_map': '''
struct Element: ~Copyable { var number: Int }
func trial(_ optional: consuming Element?) -> Int? {
    optional.map { $0.number }
}
''',
    'F13_diagnose_error': '''
@available(*, deprecated, message: "probe only")
func oldFunction() { }
@diagnose(DeprecatedDeclaration, as: error, reason: "Test local elevation")
func caller() { oldFunction() }
''',
    'F13_warning_baseline': '''
@available(*, deprecated, message: "probe only")
func oldFunction() { }
func caller() { oldFunction() }
''',
}

records = []
def execute(name, command, expected):
    process = subprocess.run(command, env=env, capture_output=True, text=True)
    output = process.stdout + process.stderr
    (root / (name + '.log')).write_text(output)
    record = {'name': name, 'command': command, 'exit_code': process.returncode,
              'expected': expected, 'output': output}
    records.append(record)
    print(name, 'exit', process.returncode, output[:450].replace('\n', ' | '), flush=True)
    return process.returncode

for name, source in sources.items():
    path = root / (name + '.swift')
    path.write_text(source)
    versions = ['26', '27'] if name.startswith(('F03_F06', 'F04_', 'F07_', 'F09_')) else ['26']
    if name.startswith('F10_'):
        versions = ['27']
    for version in versions:
        command = ['xcrun', 'swiftc', '-swift-version', '6', '-strict-concurrency=complete',
                   '-target', 'arm64-apple-macos' + version + '.0',
                   '-module-cache-path', str(cache), str(path)]
        if '@main' in source:
            command += ['-parse-as-library']
        runnable = name.startswith(('F03_F06', 'F04_', 'F05_', 'F07_', 'F08_', 'F09_'))
        binary = root / (name + '_os' + version)
        command += ['-o', str(binary)] if runnable else ['-typecheck']
        result = execute(name + '_os' + version + '_compile', command, 'record actual result')
        if result == 0 and runnable:
            execute(name + '_os' + version + '_run', [str(binary)], 'zero')

(root / 'results.json').write_text(json.dumps(records, indent=2) + '\n')
