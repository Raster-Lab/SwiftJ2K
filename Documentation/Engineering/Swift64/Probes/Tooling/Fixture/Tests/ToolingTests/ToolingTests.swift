import Foundation
import Testing
import XCTest
@testable import ToolingLibrary

@Test func resourceRoundTrip() throws {
    #expect(try resourceText() == "synthetic resource")
}
@Test(arguments: [1, 2]) func targetedRepetition(_ value: Int) async throws {
    try Task.checkCancellation()
    #expect(value > 0)
}
@Test func mixedFrameworkAssertion() {
    let expected = ProcessInfo.processInfo.environment["PROBE_EXPECT_MIXED_FAILURE"] == "1" ? 0 : 42
    XCTAssertEqual(answer(), expected)
}
final class MixedXCTest: XCTestCase {
    func testTestingAssertion() {
        let expected = ProcessInfo.processInfo.environment["PROBE_EXPECT_MIXED_FAILURE"] == "1" ? 0 : 42
        #expect(answer() == expected)
    }
}
