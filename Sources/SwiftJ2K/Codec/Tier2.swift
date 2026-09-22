// SPDX-License-Identifier: Apache-2.0
//
// Tile geometry (ISO/IEC 15444-1 Annex B: resolutions, subbands, precincts
// and code-blocks) and tier-2 packet header coding (B.10) for one tile
// anchored at the origin.
//
// Provenance: new implementation for SwiftJ2K Milestone 2. The predecessor's
// packet writer/reader (Raster-Lab/J2KSwift 7acc9ae4, `writePacket` in
// J2KEncoderPipeline.swift and the packet loop in J2KDecoderPipeline.swift
// `extractTileData`) were read for their recorded length-decoding defects
// but are inseparable from HT and multi-layer state; the standalone
// `J2KTier2Coding.swift` in the predecessor MQ-codes packet headers, which
// B.10 does not permit, and was deliberately not migrated.

struct CodeBlockGeometry: Sendable {
    let x0: Int, y0: Int, width: Int, height: Int   // band coordinates
}

struct PrecinctBandGeometry: Sendable {
    let bandIndex: Int
    let blocksWide: Int
    let blocksHigh: Int
    let blocks: [CodeBlockGeometry]   // raster order inside the precinct
}

struct PrecinctGeometry: Sendable {
    let bands: [PrecinctBandGeometry]
    var blockCount: Int { bands.reduce(0) { $0 + $1.blocks.count } }
}

struct BandGeometry: Sendable {
    let orientation: BandOrientation
    let width: Int, height: Int
    let planeX: Int, planeY: Int      // origin of the band inside the nested coefficient plane
    let gain: Int                     // log2 gain: LL 0, HL/LH 1, HH 2
    let quantizationIndex: Int        // index into the QCD exponent list
}

struct ResolutionGeometry: Sendable {
    let index: Int
    let width: Int, height: Int
    let bands: [BandGeometry]
    let precincts: [PrecinctGeometry]
}

struct TileGeometry: Sendable {
    let width: Int, height: Int, levels: Int
    let resolutions: [ResolutionGeometry]
    var codeBlockCount: Int { resolutions.reduce(0) { $0 + $1.precincts.reduce(0) { $0 + $1.blockCount } } }
    var maximumPrecinctsPerResolution: Int { resolutions.map(\.precincts.count).max() ?? 0 }
}

/// What one packet contributed to one code-block.
struct CodeBlockContribution: Sendable {
    var included = false
    var lblock = 3
    var zeroBitPlanes = 0
    var passes = 0
    var dataStart = 0
    var dataEnd = 0
}

enum Tier2 {
    // MARK: - Geometry

    static func makeTileGeometry(width: Int, height: Int, codingStyle cod: CodingStyleSegment) throws -> TileGeometry {
        let levels = cod.decompositionLevels
        var resolutions: [ResolutionGeometry] = []
        for r in 0...levels {
            let wr = Wavelet53.ceilDivPowerOfTwo(width, levels - r)
            let hr = Wavelet53.ceilDivPowerOfTwo(height, levels - r)
            var bands: [BandGeometry] = []
            if r == 0 {
                bands.append(BandGeometry(orientation: .ll, width: wr, height: hr, planeX: 0, planeY: 0,
                                          gain: 0, quantizationIndex: 0))
            } else {
                let lowW = Wavelet53.ceilDivPowerOfTwo(width, levels - r + 1)
                let lowH = Wavelet53.ceilDivPowerOfTwo(height, levels - r + 1)
                let base = 3 * (r - 1) + 1
                bands.append(BandGeometry(orientation: .hl, width: wr - lowW, height: lowH, planeX: lowW, planeY: 0,
                                          gain: 1, quantizationIndex: base))
                bands.append(BandGeometry(orientation: .lh, width: lowW, height: hr - lowH, planeX: 0, planeY: lowH,
                                          gain: 1, quantizationIndex: base + 1))
                bands.append(BandGeometry(orientation: .hh, width: wr - lowW, height: hr - lowH, planeX: lowW, planeY: lowH,
                                          gain: 2, quantizationIndex: base + 2))
            }
            let (ppx, ppy) = cod.precinctExponents(resolution: r)
            let bandPPX = r == 0 ? ppx : ppx - 1, bandPPY = r == 0 ? ppy : ppy - 1
            let xcb = min(cod.codeBlockWidthExponent, bandPPX), ycb = min(cod.codeBlockHeightExponent, bandPPY)
            let precinctsWide = wr == 0 ? 0 : Wavelet53.ceilDivPowerOfTwo(wr, ppx)
            let precinctsHigh = hr == 0 ? 0 : Wavelet53.ceilDivPowerOfTwo(hr, ppy)
            var precincts: [PrecinctGeometry] = []
            for py in 0..<precinctsHigh {
                for px in 0..<precinctsWide {
                    var precinctBands: [PrecinctBandGeometry] = []
                    for (bandIndex, band) in bands.enumerated() {
                        let bx0 = px << bandPPX, by0 = py << bandPPY
                        let bx1 = min((px + 1) << bandPPX, band.width), by1 = min((py + 1) << bandPPY, band.height)
                        var blocks: [CodeBlockGeometry] = []
                        var blocksWide = 0, blocksHigh = 0
                        if bx0 < bx1, by0 < by1 {
                            let firstColumn = bx0 >> xcb, lastColumn = (bx1 - 1) >> xcb
                            let firstRow = by0 >> ycb, lastRow = (by1 - 1) >> ycb
                            blocksWide = lastColumn - firstColumn + 1
                            blocksHigh = lastRow - firstRow + 1
                            for row in firstRow...lastRow {
                                for column in firstColumn...lastColumn {
                                    let x0 = max(bx0, column << xcb), x1 = min(bx1, (column + 1) << xcb)
                                    let y0 = max(by0, row << ycb), y1 = min(by1, (row + 1) << ycb)
                                    blocks.append(CodeBlockGeometry(x0: x0, y0: y0, width: x1 - x0, height: y1 - y0))
                                }
                            }
                        }
                        precinctBands.append(PrecinctBandGeometry(bandIndex: bandIndex, blocksWide: blocksWide,
                                                                  blocksHigh: blocksHigh, blocks: blocks))
                    }
                    precincts.append(PrecinctGeometry(bands: precinctBands))
                }
            }
            resolutions.append(ResolutionGeometry(index: r, width: wr, height: hr, bands: bands, precincts: precincts))
        }
        return TileGeometry(width: width, height: height, levels: levels, resolutions: resolutions)
    }

    // MARK: - Pass-count codeword (Table B.4)

    static func readPassCount(_ reader: inout PacketBitReader) throws -> Int {
        if try !reader.readBit() { return 1 }
        if try !reader.readBit() { return 2 }
        let two = try reader.readBits(2)
        if two < 3 { return 3 + two }
        let five = try reader.readBits(5)
        if five < 31 { return 6 + five }
        return 37 + (try reader.readBits(7))
    }

    static func writePassCount(_ passes: Int, _ writer: inout PacketBitWriter) throws {
        switch passes {
        case 1: writer.writeBit(false)
        case 2: writer.writeBits(0b10, count: 2)
        case 3...5: writer.writeBits(0b11, count: 2); writer.writeBits(passes - 3, count: 2)
        case 6...36: writer.writeBits(0b1111, count: 4); writer.writeBits(passes - 6, count: 5)
        case 37...164: writer.writeBits(0b1_1111_1111, count: 9); writer.writeBits(passes - 37, count: 7)
        default: throw CodecError(.internalFailure, "Coding pass count \(passes) is not representable.")
        }
    }

    private static func floorLog2(_ value: Int) -> Int { Int.bitWidth - 1 - value.leadingZeroBitCount }

    // MARK: - Decoding

    /// Reads every packet of the single-layer tile in the codestream's
    /// progression order. Returns contributions indexed
    /// `[resolution][precinct][band][block]`.
    static func decodePackets(geometry: TileGeometry, codingStyle cod: CodingStyleSegment,
                              bytes: [UInt8], range: Range<Int>,
                              cancellation: () throws -> Void) throws -> [[[[CodeBlockContribution]]]] {
        guard cod.layers == 1 else {
            throw CodecError(.unsupportedFeature, "Only single-layer codestreams are supported.")
        }
        if cod.progression >= 3, geometry.maximumPrecinctsPerResolution > 1 {
            throw CodecError(.unsupportedFeature, "Position-major progression orders with several precincts are not supported.")
        }
        var result: [[[[CodeBlockContribution]]]] = geometry.resolutions.map { resolution in
            resolution.precincts.map { precinct in
                precinct.bands.map { [CodeBlockContribution](repeating: CodeBlockContribution(), count: $0.blocks.count) }
            }
        }
        var cursor = range.lowerBound
        let end = range.upperBound
        for resolution in geometry.resolutions {
            for (p, precinct) in resolution.precincts.enumerated() {
                try cancellation()
                if cod.usesSOP, cursor + 6 <= end, bytes[cursor] == 0xFF, bytes[cursor + 1] == 0x91 {
                    cursor += 6
                }
                var reader = PacketBitReader(bytes: bytes, start: cursor, end: end)
                var order: [(band: Int, block: Int, length: Int)] = []
                if try reader.readBit() {
                    for (b, precinctBand) in precinct.bands.enumerated() {
                        guard !precinctBand.blocks.isEmpty else { continue }
                        var inclusion = TagTree(width: precinctBand.blocksWide, height: precinctBand.blocksHigh)
                        var msb = TagTree(width: precinctBand.blocksWide, height: precinctBand.blocksHigh)
                        for k in 0..<precinctBand.blocks.count {
                            var state = result[resolution.index][p][b][k]
                            let included = try inclusion.decode(reader: &reader, leaf: k, threshold: 1)
                            guard included else { continue }
                            var threshold: Int32 = 1
                            while try !msb.decode(reader: &reader, leaf: k, threshold: threshold) {
                                threshold += 1
                                guard threshold <= 80 else {
                                    throw CodecError(.malformedInput, "Zero bit-plane count is not representable.")
                                }
                            }
                            state.included = true
                            state.zeroBitPlanes = Int(msb.value(leaf: k))
                            state.passes = try readPassCount(&reader)
                            while try reader.readBit() {
                                state.lblock += 1
                                guard state.lblock <= 40 else {
                                    throw CodecError(.malformedInput, "Lblock signalling is not representable.")
                                }
                            }
                            let length = try reader.readBits(state.lblock + floorLog2(state.passes))
                            order.append((b, k, length))
                            result[resolution.index][p][b][k] = state
                        }
                    }
                }
                try reader.alignToByte()
                cursor = reader.position
                if cod.usesEPH {
                    guard cursor + 2 <= end, bytes[cursor] == 0xFF, bytes[cursor + 1] == 0x92 else {
                        throw CodecError(.malformedInput, "EPH marker is missing after a packet header.")
                    }
                    cursor += 2
                }
                for entry in order {
                    guard cursor + entry.length <= end else {
                        throw CodecError(.malformedInput, "Code-block data length exceeds the tile-part data.")
                    }
                    result[resolution.index][p][entry.band][entry.block].dataStart = cursor
                    result[resolution.index][p][entry.band][entry.block].dataEnd = cursor + entry.length
                    cursor += entry.length
                }
            }
        }
        return result
    }

    // MARK: - Encoding

    /// Writes one single-layer packet per precinct in LRCP order.
    /// `encodings` is indexed `[resolution][precinct][band][block]`.
    static func encodePackets(geometry: TileGeometry, encodings: [[[[CodeBlockEncoding]]]],
                              into out: inout ByteWriter, cancellation: () throws -> Void) throws {
        for resolution in geometry.resolutions {
            for (p, precinct) in resolution.precincts.enumerated() {
                try cancellation()
                var header = PacketBitWriter()
                var bodies: [[UInt8]] = []
                let anyIncluded = precinct.bands.enumerated().contains { b, band in
                    band.blocks.indices.contains { encodings[resolution.index][p][b][$0].passCount > 0 }
                }
                header.writeBit(anyIncluded)
                if anyIncluded {
                    for (b, precinctBand) in precinct.bands.enumerated() {
                        guard !precinctBand.blocks.isEmpty else { continue }
                        var inclusion = TagTree(width: precinctBand.blocksWide, height: precinctBand.blocksHigh)
                        var msb = TagTree(width: precinctBand.blocksWide, height: precinctBand.blocksHigh)
                        for k in 0..<precinctBand.blocks.count {
                            let encoding = encodings[resolution.index][p][b][k]
                            try inclusion.setValue(leaf: k, value: encoding.passCount > 0 ? 0 : 1)
                            try msb.setValue(leaf: k, value: Int32(encoding.zeroBitPlanes))
                        }
                        for k in 0..<precinctBand.blocks.count {
                            let encoding = encodings[resolution.index][p][b][k]
                            try inclusion.encode(writer: &header, leaf: k, threshold: 1)
                            guard encoding.passCount > 0 else { continue }
                            try msb.encode(writer: &header, leaf: k, threshold: Int32(encoding.zeroBitPlanes) + 1)
                            try writePassCount(encoding.passCount, &header)
                            var lblock = 3
                            let needed = max(1, Int.bitWidth - encoding.data.count.leadingZeroBitCount)
                            while lblock + floorLog2(encoding.passCount) < needed {
                                header.writeBit(true)
                                lblock += 1
                            }
                            header.writeBit(false)
                            header.writeBits(encoding.data.count, count: lblock + floorLog2(encoding.passCount))
                            bodies.append(encoding.data)
                        }
                    }
                }
                out.writeBytes(header.finish())
                for body in bodies { out.writeBytes(body) }
            }
        }
    }
}
