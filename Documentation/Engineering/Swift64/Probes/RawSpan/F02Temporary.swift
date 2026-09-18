enum ScratchError: Error { case rejectedCapacity, expectedFailure, mismatch }
final class DestructionCounter { var count = 0 }
final class Element {
    let counter: DestructionCounter
    init(_ counter: DestructionCounter) { self.counter = counter }
    deinit { counter.count += 1 }
}
func checkedScratchCount(_ count: Int) throws -> Int {
    guard count >= 0, count <= 64 else { throw ScratchError.rejectedCapacity }
    return count
}
@main struct F02Temporary {
    static func main() throws {
        let capacity = try checkedScratchCount(8)
        let counter = DestructionCounter()
        do {
            try withTemporaryAllocation(of: Element.self, capacity: capacity) { scratch in
                scratch.append(Element(counter))
                scratch.append(Element(counter))
                guard scratch.count == 2 else { throw ScratchError.mismatch }
                throw ScratchError.expectedFailure
            }
            throw ScratchError.mismatch
        } catch ScratchError.expectedFailure { }
        guard counter.count == 2 else { throw ScratchError.mismatch }
        withTemporaryAllocation(of: Element.self, capacity: capacity) { scratch in
            scratch.append(Element(counter))
        }
        guard counter.count == 3 else { throw ScratchError.mismatch }
        let total = withTemporaryAllocation(of: UInt16.self, capacity: capacity) { scratch in
            for value in 0..<capacity { scratch.append(UInt16(value)) }
            var total: UInt16 = 0
            for index in 0..<scratch.count { total += scratch.span[index] }
            return total
        }
        guard total == 28 else { throw ScratchError.mismatch }
        let rawValue = withTemporaryAllocation(byteCount: 8, alignment: 1) { scratch in
            scratch.append(UInt16(0xabcd).bigEndian, as: UInt16.self)
            return UInt16(bigEndian: scratch.bytes.load(fromByteOffset: 0, as: UInt16.self))
        }
        guard rawValue == 0xabcd else { throw ScratchError.mismatch }
        let empty = withTemporaryAllocation(of: UInt16.self, capacity: 0) { $0.count }
        guard empty == 0 else { throw ScratchError.mismatch }
        for invalid in [-1, 65, Int.max] {
            do { _ = try checkedScratchCount(invalid); throw ScratchError.mismatch }
            catch ScratchError.rejectedCapacity { }
        }
        print("F02 passed: typed/raw scratch, 3 exact destructions including partial initialisation throw, empty and bounded capacities")
    }
}
