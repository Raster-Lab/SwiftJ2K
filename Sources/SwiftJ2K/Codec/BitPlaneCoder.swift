// SPDX-License-Identifier: Apache-2.0
//
// EBCOT tier-1 block coder (ISO/IEC 15444-1 Annex D): three coding passes per
// bit-plane, default code-block style only (no bypass, reset, termination on
// each pass, vertically causal contexts, predictable termination or
// segmentation symbols).
//
// Provenance: adapted from Raster-Lab/J2KSwift at commit
// 7acc9ae415e7d0bc7d441e0f0277d5e150bd19ca,
// Sources/J2KCodec/J2KBitPlaneCoder.swift (MIT; relicensed Apache-2.0 under
// POL-07). Retained: the stripe-oriented scan, the significance-propagation,
// magnitude-refinement and cleanup pass rules including run-length coding
// with the two uniform-context position bits, the sign XOR prediction and
// the visited/refined flag handling. Not migrated: selective bypass and
// per-pass segment handling, rate-control distortion accounting, MQ
// checkpoints, SIMD magnitude splitting, scratch-buffer pools, debug tracing
// and half-LSB reconstruction of truncated code-blocks. Those belong to lossy
// and accelerated milestones; this file is the scalar lossless reference.

/// Result of coding one code-block: the codeword segment, the number of
/// coding passes it contains, and the number of missing most-significant
/// bit-planes relative to the band's `Mb`.
struct CodeBlockEncoding: Sendable {
    let data: [UInt8]
    let passCount: Int
    let zeroBitPlanes: Int
}

enum BitPlaneCoder {
    /// Code-block dimensions and coefficient magnitudes the coder accepts
    /// (Table A.18 bounds the block at 4096 coefficients; `Mb` is bounded so
    /// magnitudes stay inside `UInt32`).
    static let maximumCoefficients = 4096
    static let maximumMagnitudeBitPlanes = 30

    // MARK: - Encoder

    static func encode(coefficients: [Int32], width: Int, height: Int,
                       orientation: BandOrientation, magnitudeBitPlanes mb: Int) throws -> CodeBlockEncoding {
        let count = width * height
        guard width > 0, height > 0, count <= maximumCoefficients, coefficients.count == count,
              mb >= 1, mb <= maximumMagnitudeBitPlanes else {
            throw CodecError(.internalFailure, "Code-block geometry or bit-plane count is outside the coder's range.")
        }
        var magnitudes = [UInt32](repeating: 0, count: count)
        var negatives = [Bool](repeating: false, count: count)
        var maximum: UInt32 = 0
        for i in 0..<count {
            let value = coefficients[i]
            let magnitude = value < 0 ? UInt32(bitPattern: 0 &- value) : UInt32(value)
            magnitudes[i] = magnitude
            negatives[i] = value < 0
            if magnitude > maximum { maximum = magnitude }
        }
        let bitPlanes = maximum == 0 ? 0 : UInt32.bitWidth - maximum.leadingZeroBitCount
        guard bitPlanes <= mb else {
            throw CodecError(.invalidArgument, "A coefficient exceeds the precision the band can represent.")
        }
        if bitPlanes == 0 {
            return CodeBlockEncoding(data: [], passCount: 0, zeroBitPlanes: mb)
        }

        let tables = ContextTables(orientation: orientation)
        var states = StatePlane(width: width, height: height)
        var contexts = ContextSet()
        var encoder = MQEncoder(capacityHint: count / 2)
        var passCount = 0

        for plane in stride(from: bitPlanes - 1, through: 0, by: -1) {
            let mask = UInt32(1) << UInt32(plane)
            if plane != bitPlanes - 1 {
                encodeSignificancePass(mask: mask, magnitudes: magnitudes, negatives: negatives,
                                       states: &states, tables: tables, contexts: &contexts, encoder: &encoder)
                passCount += 1
                encodeRefinementPass(mask: mask, magnitudes: magnitudes,
                                     states: &states, contexts: &contexts, encoder: &encoder)
                passCount += 1
            }
            encodeCleanupPass(mask: mask, magnitudes: magnitudes, negatives: negatives,
                              states: &states, tables: tables, contexts: &contexts, encoder: &encoder)
            passCount += 1
            states.clearVisited()
        }
        return CodeBlockEncoding(data: encoder.finish(), passCount: passCount, zeroBitPlanes: mb - bitPlanes)
    }

    private static func encodeSignificancePass(mask: UInt32, magnitudes: [UInt32], negatives: [Bool],
                                               states: inout StatePlane, tables: ContextTables,
                                               contexts: inout ContextSet, encoder: inout MQEncoder) {
        let w = states.width, h = states.height
        for stripe in stride(from: 0, to: h, by: 4) {
            let stripeEnd = min(stripe + 4, h)
            for x in 0..<w {
                for y in stripe..<stripeEnd {
                    let i = states.index(x: x, y: y)
                    let flags = states.flags[i]
                    if flags & (CoefficientFlag.significant | CoefficientFlag.visited) != 0 { continue }
                    let key = states.significanceKey(at: i)
                    if key == 0 { continue }
                    let j = y * w + x
                    let becomesSignificant = magnitudes[j] & mask != 0
                    encoder.encode(becomesSignificant, context: &contexts.contexts[Int(tables.significance[key])])
                    if becomesSignificant {
                        encodeSign(negative: negatives[j], at: i, states: &states, contexts: &contexts, encoder: &encoder)
                    } else {
                        states.flags[i] = flags | CoefficientFlag.visited
                    }
                }
            }
        }
    }

    private static func encodeRefinementPass(mask: UInt32, magnitudes: [UInt32],
                                             states: inout StatePlane, contexts: inout ContextSet,
                                             encoder: inout MQEncoder) {
        let w = states.width, h = states.height
        for stripe in stride(from: 0, to: h, by: 4) {
            let stripeEnd = min(stripe + 4, h)
            for x in 0..<w {
                for y in stripe..<stripeEnd {
                    let i = states.index(x: x, y: y)
                    let flags = states.flags[i]
                    guard flags & (CoefficientFlag.significant | CoefficientFlag.visited) == CoefficientFlag.significant else { continue }
                    let label = refinementLabel(flags: flags, at: i, states: states)
                    encoder.encode(magnitudes[y * w + x] & mask != 0, context: &contexts.contexts[Int(label)])
                    states.flags[i] = flags | CoefficientFlag.visited | CoefficientFlag.refined
                }
            }
        }
    }

    private static func encodeCleanupPass(mask: UInt32, magnitudes: [UInt32], negatives: [Bool],
                                          states: inout StatePlane, tables: ContextTables,
                                          contexts: inout ContextSet, encoder: inout MQEncoder) {
        let w = states.width, h = states.height
        for stripe in stride(from: 0, to: h, by: 4) {
            let stripeEnd = min(stripe + 4, h)
            for x in 0..<w {
                var y = stripe
                if stripeEnd - stripe == 4, runLengthEligible(x: x, stripe: stripe, states: states) {
                    var first = -1
                    for k in 0..<4 where magnitudes[(stripe + k) * w + x] & mask != 0 {
                        first = k
                        break
                    }
                    encoder.encode(first >= 0, context: &contexts.contexts[Int(ContextLabel.runLength)])
                    if first < 0 { continue }
                    encoder.encode(first & 2 != 0, context: &contexts.contexts[Int(ContextLabel.uniform)])
                    encoder.encode(first & 1 != 0, context: &contexts.contexts[Int(ContextLabel.uniform)])
                    let i = states.index(x: x, y: stripe + first)
                    encodeSign(negative: negatives[(stripe + first) * w + x], at: i,
                               states: &states, contexts: &contexts, encoder: &encoder)
                    y = stripe + first + 1
                }
                while y < stripeEnd {
                    let i = states.index(x: x, y: y)
                    let flags = states.flags[i]
                    if flags & (CoefficientFlag.significant | CoefficientFlag.visited) == 0 {
                        let key = states.significanceKey(at: i)
                        let j = y * w + x
                        let becomesSignificant = magnitudes[j] & mask != 0
                        encoder.encode(becomesSignificant, context: &contexts.contexts[Int(tables.significance[key])])
                        if becomesSignificant {
                            encodeSign(negative: negatives[j], at: i, states: &states, contexts: &contexts, encoder: &encoder)
                        }
                    }
                    y += 1
                }
            }
        }
    }

    @inline(__always)
    private static func encodeSign(negative: Bool, at i: Int, states: inout StatePlane,
                                   contexts: inout ContextSet, encoder: inout MQEncoder) {
        let entry = states.signEntry(at: i)
        encoder.encode(negative != (entry & 1 == 1), context: &contexts.contexts[Int(entry >> 1)])
        states.flags[i] = CoefficientFlag.significant | CoefficientFlag.visited | (negative ? CoefficientFlag.negative : 0)
    }

    // MARK: - Decoder

    /// Decodes one code-block into sign-magnitude integer coefficients.
    /// `passCount` passes are consumed from `bytes[start..<end]`.
    static func decode(bytes: [UInt8], start: Int, end: Int, width: Int, height: Int,
                       orientation: BandOrientation, zeroBitPlanes: Int, passCount: Int,
                       magnitudeBitPlanes mb: Int) throws -> [Int32] {
        let count = width * height
        guard width > 0, height > 0, count <= maximumCoefficients,
              mb >= 1, mb <= maximumMagnitudeBitPlanes else {
            throw CodecError(.internalFailure, "Code-block geometry or bit-plane count is outside the coder's range.")
        }
        if passCount == 0 { return [Int32](repeating: 0, count: count) }
        let bitPlanes = mb - zeroBitPlanes
        guard zeroBitPlanes >= 0, bitPlanes >= 1, passCount <= 3 * bitPlanes - 2 else {
            throw CodecError(.malformedInput, "Code-block signals more coding passes or missing bit-planes than its band allows.")
        }

        let tables = ContextTables(orientation: orientation)
        var states = StatePlane(width: width, height: height)
        var contexts = ContextSet()
        var decoder = try MQDecoder(bytes: bytes, start: start, end: end)
        var magnitudes = [UInt32](repeating: 0, count: count)
        var remaining = passCount

        planes: for plane in stride(from: bitPlanes - 1, through: 0, by: -1) {
            let mask = UInt32(1) << UInt32(plane)
            if plane != bitPlanes - 1 {
                if remaining == 0 { break planes }
                decodeSignificancePass(mask: mask, magnitudes: &magnitudes, states: &states,
                                       tables: tables, contexts: &contexts, decoder: &decoder)
                remaining -= 1
                if remaining == 0 { break planes }
                decodeRefinementPass(mask: mask, magnitudes: &magnitudes, states: &states,
                                     contexts: &contexts, decoder: &decoder)
                remaining -= 1
            }
            if remaining == 0 { break planes }
            decodeCleanupPass(mask: mask, magnitudes: &magnitudes, states: &states,
                              tables: tables, contexts: &contexts, decoder: &decoder)
            remaining -= 1
            states.clearVisited()
        }

        var coefficients = [Int32](repeating: 0, count: count)
        for y in 0..<height {
            for x in 0..<width {
                let j = y * width + x
                let magnitude = Int32(magnitudes[j])   // mb <= 30 keeps this in range
                coefficients[j] = states.flags[states.index(x: x, y: y)] & CoefficientFlag.negative != 0 ? -magnitude : magnitude
            }
        }
        return coefficients
    }

    private static func decodeSignificancePass(mask: UInt32, magnitudes: inout [UInt32],
                                               states: inout StatePlane, tables: ContextTables,
                                               contexts: inout ContextSet, decoder: inout MQDecoder) {
        let w = states.width, h = states.height
        for stripe in stride(from: 0, to: h, by: 4) {
            let stripeEnd = min(stripe + 4, h)
            for x in 0..<w {
                for y in stripe..<stripeEnd {
                    let i = states.index(x: x, y: y)
                    let flags = states.flags[i]
                    if flags & (CoefficientFlag.significant | CoefficientFlag.visited) != 0 { continue }
                    let key = states.significanceKey(at: i)
                    if key == 0 { continue }
                    if decoder.decode(context: &contexts.contexts[Int(tables.significance[key])]) {
                        magnitudes[y * w + x] |= mask
                        decodeSign(at: i, states: &states, contexts: &contexts, decoder: &decoder)
                    } else {
                        states.flags[i] = flags | CoefficientFlag.visited
                    }
                }
            }
        }
    }

    private static func decodeRefinementPass(mask: UInt32, magnitudes: inout [UInt32],
                                             states: inout StatePlane, contexts: inout ContextSet,
                                             decoder: inout MQDecoder) {
        let w = states.width, h = states.height
        for stripe in stride(from: 0, to: h, by: 4) {
            let stripeEnd = min(stripe + 4, h)
            for x in 0..<w {
                for y in stripe..<stripeEnd {
                    let i = states.index(x: x, y: y)
                    let flags = states.flags[i]
                    guard flags & (CoefficientFlag.significant | CoefficientFlag.visited) == CoefficientFlag.significant else { continue }
                    let label = refinementLabel(flags: flags, at: i, states: states)
                    if decoder.decode(context: &contexts.contexts[Int(label)]) { magnitudes[y * w + x] |= mask }
                    states.flags[i] = flags | CoefficientFlag.visited | CoefficientFlag.refined
                }
            }
        }
    }

    private static func decodeCleanupPass(mask: UInt32, magnitudes: inout [UInt32],
                                          states: inout StatePlane, tables: ContextTables,
                                          contexts: inout ContextSet, decoder: inout MQDecoder) {
        let w = states.width, h = states.height
        for stripe in stride(from: 0, to: h, by: 4) {
            let stripeEnd = min(stripe + 4, h)
            for x in 0..<w {
                var y = stripe
                if stripeEnd - stripe == 4, runLengthEligible(x: x, stripe: stripe, states: states) {
                    guard decoder.decode(context: &contexts.contexts[Int(ContextLabel.runLength)]) else { continue }
                    let high = decoder.decode(context: &contexts.contexts[Int(ContextLabel.uniform)]) ? 2 : 0
                    let low = decoder.decode(context: &contexts.contexts[Int(ContextLabel.uniform)]) ? 1 : 0
                    let first = high + low
                    magnitudes[(stripe + first) * w + x] |= mask
                    decodeSign(at: states.index(x: x, y: stripe + first), states: &states, contexts: &contexts, decoder: &decoder)
                    y = stripe + first + 1
                }
                while y < stripeEnd {
                    let i = states.index(x: x, y: y)
                    if states.flags[i] & (CoefficientFlag.significant | CoefficientFlag.visited) == 0 {
                        let key = states.significanceKey(at: i)
                        if decoder.decode(context: &contexts.contexts[Int(tables.significance[key])]) {
                            magnitudes[y * w + x] |= mask
                            decodeSign(at: i, states: &states, contexts: &contexts, decoder: &decoder)
                        }
                    }
                    y += 1
                }
            }
        }
    }

    @inline(__always)
    private static func decodeSign(at i: Int, states: inout StatePlane,
                                   contexts: inout ContextSet, decoder: inout MQDecoder) {
        let entry = states.signEntry(at: i)
        let negative = decoder.decode(context: &contexts.contexts[Int(entry >> 1)]) != (entry & 1 == 1)
        states.flags[i] = CoefficientFlag.significant | CoefficientFlag.visited | (negative ? CoefficientFlag.negative : 0)
    }

    // MARK: - Shared rules

    /// Table D.4: first refinement distinguishes "no significant neighbours"
    /// from "some"; later refinements share one context.
    @inline(__always)
    private static func refinementLabel(flags: UInt8, at i: Int, states: StatePlane) -> UInt8 {
        if flags & CoefficientFlag.refined != 0 { return ContextLabel.refinementSubsequent }
        return states.hasSignificantNeighbour(at: i)
            ? ContextLabel.refinementFirstWithNeighbours : ContextLabel.refinementFirstNoNeighbours
    }

    /// D.3.4: a full four-row column enters run-length mode when every
    /// coefficient is insignificant, unvisited and has an all-zero context.
    @inline(__always)
    private static func runLengthEligible(x: Int, stripe: Int, states: StatePlane) -> Bool {
        for k in 0..<4 {
            let i = states.index(x: x, y: stripe + k)
            if states.flags[i] & (CoefficientFlag.significant | CoefficientFlag.visited) != 0 { return false }
            if states.hasSignificantNeighbour(at: i) { return false }
        }
        return true
    }
}
