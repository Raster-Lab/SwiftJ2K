import Foundation
public func answer() -> Int { 42 }
public func resourceText() throws -> String {
    guard let url = Bundle.module.url(forResource: "fixture", withExtension: "txt") else {
        throw CocoaError(.fileNoSuchFile)
    }
    return try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
}
