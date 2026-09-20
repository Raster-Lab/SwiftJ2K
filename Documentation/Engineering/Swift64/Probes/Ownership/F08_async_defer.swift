
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
