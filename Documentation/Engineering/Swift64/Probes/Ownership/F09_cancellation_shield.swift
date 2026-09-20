
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
