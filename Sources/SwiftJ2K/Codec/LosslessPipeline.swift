// SPDX-License-Identifier: Apache-2.0
//
// Scalar lossless JPEG 2000 Part 1 pipeline for the initial shared profile:
// one unsigned greyscale component of 1–16 bits, one tile at the origin,
// reversible 5/3 wavelet, no quantisation, default code-block style, one
// quality layer, raw codestream (no JP2 container).
//
// Provenance: new implementation for SwiftJ2K Milestone 2, fitted to the
// Milestone 1 `Image`/`ImageDestination` contract. It replaces the
// predecessor's `EncoderPipeline`/`DecoderPipeline` (Raster-Lab/J2KSwift
// 7acc9ae4), whose scalar path is interleaved with HT, GPU, ROI, multi-tile
// and rate-control code and which imports Metal unconditionally.
import Foundation

/// A validated description of a codestream the scalar path can decode.
struct LosslessProfile: Sendable {
    let width: Int
    let height: Int
    let precision: Int
    let codingStyle: CodingStyleSegment
    let quantization: QuantizationSegment
    let geometry: TileGeometry
    let magnitudeBitPlanes: [Int]         // per QCD band index
    let tileData: [Range<Int>]            // tile-part data ranges in part order
}

/// Cooperative cancellation plus the operation deadline from `ResourceLimits`.
struct WorkGuard: Sendable {
    private let deadline: ContinuousClock.Instant
    init(limits: ResourceLimits) {
        deadline = ContinuousClock.now.advanced(by: .seconds(limits.deadlineSeconds))
    }
    func check() throws {
        try Task.checkCancellation()
        guard ContinuousClock.now <= deadline else {
            throw CodecError(.resourceLimitExceeded, "Operation deadline elapsed.")
        }
    }
}

enum ScalarLosslessCodec {
    static let format = "jpeg2000-codestream"
    static let guardBits = 2

    // MARK: - Inspection

    static func inspect(_ bytes: [UInt8], limits: ResourceLimits) throws -> LosslessProfile {
        let parsed = try CodestreamSyntax.parse(bytes, limits: limits)
        let size = parsed.size
        guard size.capabilities & 0xC000 == 0 else {
            throw CodecError(.unsupportedFeature, "Rsiz signals Part 2 or Part 15 (HTJ2K) coding, which is not supported.")
        }
        guard size.components.count == 1 else {
            throw CodecError(.unsupportedFeature, "Only single-component (greyscale) codestreams are supported.")
        }
        let component = size.components[0]
        guard !component.signed else {
            throw CodecError(.unsupportedFeature, "Signed components are not supported.")
        }
        guard component.precision <= 16 else {
            throw CodecError(.unsupportedFeature, "Component precision above 16 bits is not supported.")
        }
        guard component.horizontalSeparation == 1, component.verticalSeparation == 1 else {
            throw CodecError(.unsupportedFeature, "Sub-sampled components are not supported.")
        }
        guard size.originX == 0, size.originY == 0, size.tileOriginX == 0, size.tileOriginY == 0 else {
            throw CodecError(.unsupportedFeature, "Non-zero image or tile origins are not supported.")
        }
        guard size.tileWidth >= size.width, size.tileHeight >= size.height else {
            throw CodecError(.unsupportedFeature, "Multi-tile codestreams are not supported.")
        }
        let cod = parsed.codingStyle
        guard cod.reversible else {
            throw CodecError(.unsupportedFeature, "The irreversible 9/7 wavelet is not supported.")
        }
        guard cod.layers == 1 else {
            throw CodecError(.unsupportedFeature, "Multiple quality layers are not supported.")
        }
        guard cod.codeBlockStyle == 0 else {
            throw CodecError(.unsupportedFeature, "Code-block style bits (bypass, reset, termination, causal, segmentation) are not supported.")
        }
        guard cod.componentTransform == 0 else {
            throw CodecError(.malformedInput, "A component transform is signalled for a single component.")
        }
        let qcd = parsed.quantization
        guard qcd.style == .none else {
            throw CodecError(.unsupportedFeature, "Quantised (lossy) codestreams are not supported.")
        }
        let bandCount = 3 * cod.decompositionLevels + 1
        guard qcd.exponents.count >= bandCount else {
            throw CodecError(.malformedInput, "QCD lists fewer bands than the decomposition needs.")
        }
        var magnitudeBitPlanes: [Int] = []
        for exponent in qcd.exponents.prefix(bandCount) {
            let mb = qcd.guardBits + exponent - 1
            guard mb >= 1, mb <= BitPlaneCoder.maximumMagnitudeBitPlanes else {
                throw CodecError(.malformedInput, "Band exponent and guard bits give an unusable bit-plane count.")
            }
            magnitudeBitPlanes.append(mb)
        }
        // Exactly one tile: every tile-part must belong to tile 0, in order.
        let parts = parsed.tileParts.sorted { $0.partIndex < $1.partIndex }
        guard parts.allSatisfy({ $0.tileIndex == 0 }) else {
            throw CodecError(.malformedInput, "Tile-parts reference a tile the SIZ grid does not contain.")
        }
        for (expected, part) in parts.enumerated() {
            guard part.partIndex == expected, part.partCount == 0 || part.partCount == parts.count else {
                throw CodecError(.malformedInput, "Tile-part indices are not contiguous.")
            }
        }
        let geometry = try Tier2.makeTileGeometry(width: size.width, height: size.height, codingStyle: cod)
        return LosslessProfile(width: size.width, height: size.height, precision: component.precision,
                               codingStyle: cod, quantization: qcd, geometry: geometry,
                               magnitudeBitPlanes: magnitudeBitPlanes, tileData: parts.map(\.dataRange))
    }

    /// Bound on algorithm workspace for a `width × height` plane (MEM-10):
    /// one `Int32` coefficient plane plus per-block coder scratch.
    static func workspaceBytes(width: Int, height: Int) throws -> Int {
        let plane = try checkedMultiply(checkedMultiply(width, height), 4)
        let blockScratch = BitPlaneCoder.maximumCoefficients * (4 + 4 + 1) + 66 * 66 + 4096
        return try checkedAdd(plane, blockScratch)
    }

    // MARK: - Decoding

    /// Decodes into `destination`, which must already match the codestream.
    /// Returns the sealed image and the workspace bound that was admitted.
    static func decode(bytes: [UInt8], profile: LosslessProfile, into destination: ImageDestination,
                       limits: ResourceLimits, progress: (@Sendable (ProgressUpdate) -> Void)?) throws -> (Image, Int) {
        let descriptor = destination.descriptor
        guard descriptor.width == profile.width, descriptor.height == profile.height,
              descriptor.sampleType == .unsignedInteger, descriptor.storageBits == 16,
              descriptor.components == [.grey], descriptor.planes.count == 1,
              descriptor.meaningfulBits == profile.precision else {
            throw CodecError(.incompatibleImageLayout, "Destination descriptor does not match the codestream geometry or precision.")
        }
        let workspace = try workspaceBytes(width: profile.width, height: profile.height)
        guard workspace <= limits.maximumWorkspaceBytes else {
            throw CodecError(.resourceLimitExceeded, "Decoder workspace exceeds the operation limit.")
        }
        guard try checkedAdd(checkedAdd(bytes.count, destination.storage.byteCount), workspace) <= limits.maximumMemoryBytes else {
            throw CodecError(.resourceLimitExceeded, "Compressed input, destination and workspace exceed the memory budget.")
        }
        let work = WorkGuard(limits: limits)
        try work.check()
        do {
            return try decodeAdmitted(bytes: bytes, profile: profile, into: destination, workspace: workspace,
                                      work: work, progress: progress)
        } catch {
            // Admission passed, so this is a failed decode: the destination
            // must not remain publishable.
            destination.invalidateAfterFailure()
            throw error
        }
    }

    private static func decodeAdmitted(bytes: [UInt8], profile: LosslessProfile, into destination: ImageDestination,
                                       workspace: Int, work: WorkGuard,
                                       progress: (@Sendable (ProgressUpdate) -> Void)?) throws -> (Image, Int) {
        let descriptor = destination.descriptor
        // Concatenate tile-part data only when there is more than one part.
        let tileBytes: [UInt8]
        let tileRange: Range<Int>
        if profile.tileData.count == 1 {
            tileBytes = bytes
            tileRange = profile.tileData[0]
        } else {
            var joined: [UInt8] = []
            joined.reserveCapacity(profile.tileData.reduce(0) { $0 + $1.count })
            for range in profile.tileData { joined.append(contentsOf: bytes[range]) }
            tileBytes = joined
            tileRange = 0..<joined.count
            StorageTelemetry.recordWorkspaceAllocation(bytes: joined.count)
        }

        let geometry = profile.geometry
        let contributions = try Tier2.decodePackets(geometry: geometry, codingStyle: profile.codingStyle,
                                                    bytes: tileBytes, range: tileRange, cancellation: work.check)
        let total = geometry.codeBlockCount
        var completed = 0
        progress?(try ProgressUpdate(phase: .processing, completedUnits: 0, totalUnits: total))

        let stride = profile.width
        var plane = [Int32](repeating: 0, count: profile.width * profile.height)
        StorageTelemetry.recordWorkspaceAllocation(bytes: plane.count * 4)
        for resolution in geometry.resolutions {
            for (p, precinct) in resolution.precincts.enumerated() {
                for (b, precinctBand) in precinct.bands.enumerated() {
                    let band = resolution.bands[precinctBand.bandIndex]
                    let mb = profile.magnitudeBitPlanes[band.quantizationIndex]
                    for (k, block) in precinctBand.blocks.enumerated() {
                        try work.check()
                        let contribution = contributions[resolution.index][p][b][k]
                        completed += 1
                        guard contribution.included, contribution.passes > 0 else { continue }
                        let coefficients = try BitPlaneCoder.decode(
                            bytes: tileBytes, start: contribution.dataStart, end: contribution.dataEnd,
                            width: block.width, height: block.height, orientation: band.orientation,
                            zeroBitPlanes: contribution.zeroBitPlanes, passCount: contribution.passes,
                            magnitudeBitPlanes: mb)
                        for row in 0..<block.height {
                            let planeRow = (band.planeY + block.y0 + row) * stride + band.planeX + block.x0
                            for column in 0..<block.width {
                                plane[planeRow + column] = coefficients[row * block.width + column]
                            }
                        }
                        if completed & 7 == 0 {
                            progress?(try ProgressUpdate(phase: .processing, completedUnits: completed, totalUnits: total))
                        }
                    }
                }
            }
        }
        try Wavelet53.inverse(plane: &plane, stride: stride, width: profile.width, height: profile.height,
                              levels: profile.codingStyle.decompositionLevels, cancellation: work.check)

        // Final-output stage: DC shift, clamp, write straight into the destination.
        let shift = Int32(1) << Int32(profile.precision - 1)
        let maximum = Int32((1 << profile.precision) - 1)
        let layout = descriptor.planes[0]
        let mutation = SharedPathMutation.active
        let rowBytes = mutation == .ignoreRowStride ? profile.width * layout.pixelStride : layout.rowBytes
        let order = mutation == .wrongByteOrder ? descriptor.byteOrder.opposite : descriptor.byteOrder
        let image = try destination.write { bytes in
            for y in 0..<profile.height {
                try work.check()
                let rowOffset = layout.offset + y * rowBytes
                let planeRow = y * stride
                for x in 0..<profile.width {
                    let value = min(max(plane[planeRow + x] + shift, 0), maximum)
                    try storeUInt16(UInt16(value), into: bytes, at: rowOffset + x * layout.pixelStride, order: order)
                }
            }
        }
        return (image, workspace)
    }

    // MARK: - Encoding

    struct EncodeParameters: Sendable {
        let decompositionLevels: Int
        let codeBlockWidthExponent: Int
        let codeBlockHeightExponent: Int
    }

    /// Reads the sealed image directly (MEM-10) and returns the codestream and
    /// the workspace bound that was admitted.
    static func encode(image: Image, parameters: EncodeParameters, limits: ResourceLimits,
                       progress: (@Sendable (ProgressUpdate) -> Void)?) throws -> ([UInt8], Int) {
        let descriptor = image.descriptor
        guard descriptor.sampleType == .unsignedInteger, descriptor.storageBits == 16,
              descriptor.components == [.grey], descriptor.planes.count == 1, descriptor.alpha == .absent else {
            throw CodecError(.unsupportedFeature, "Only unsigned 16-bit single-plane greyscale images can be encoded.")
        }
        guard descriptor.iccProfile == nil, image.metadata.entries.isEmpty else {
            throw CodecError(.unsupportedFeature, "Raw codestream output cannot carry ICC or metadata; none is silently dropped.")
        }
        let width = descriptor.width, height = descriptor.height, precision = descriptor.meaningfulBits
        let workspace = try workspaceBytes(width: width, height: height)
        guard workspace <= limits.maximumWorkspaceBytes else {
            throw CodecError(.resourceLimitExceeded, "Encoder workspace exceeds the operation limit.")
        }
        guard try checkedAdd(image.storage.byteCount, workspace) <= limits.maximumMemoryBytes else {
            throw CodecError(.resourceLimitExceeded, "Image and workspace exceed the memory budget.")
        }
        let work = WorkGuard(limits: limits)
        try work.check()

        let cod = CodingStyleSegment(usesPrecincts: false, usesSOP: false, usesEPH: false, progression: 0,
                                     layers: 1, componentTransform: 0,
                                     decompositionLevels: parameters.decompositionLevels,
                                     codeBlockWidthExponent: parameters.codeBlockWidthExponent,
                                     codeBlockHeightExponent: parameters.codeBlockHeightExponent,
                                     codeBlockStyle: 0, reversible: true, precinctExponents: [])
        let geometry = try Tier2.makeTileGeometry(width: width, height: height, codingStyle: cod)
        var exponents: [Int] = []
        for resolution in geometry.resolutions {
            for band in resolution.bands { exponents.append(precision + band.gain) }
        }
        let qcd = QuantizationSegment(style: .none, guardBits: guardBits, exponents: exponents, mantissas: [])

        // Input stage: read caller samples in place, validate the declared range.
        let shift = Int32(1) << Int32(precision - 1)
        let maximum = UInt16((1 << precision) - 1)
        let layout = descriptor.planes[0]
        let stride = width
        var plane = [Int32](repeating: 0, count: width * height)
        StorageTelemetry.recordWorkspaceAllocation(bytes: plane.count * 4)
        let mutation = SharedPathMutation.active
        let rowBytes = mutation == .ignoreRowStride ? width * layout.pixelStride : layout.rowBytes
        let order = mutation == .wrongByteOrder ? descriptor.byteOrder.opposite : descriptor.byteOrder
        try image.storage.withUnsafeBytes { bytes in
            guard bytes.count >= descriptor.requiredByteCount else {
                throw CodecError(.storageUnavailable, "Provider returned insufficient capacity.")
            }
            for y in 0..<height {
                try work.check()
                let rowOffset = layout.offset + y * rowBytes
                for x in 0..<width {
                    let sample = try loadUInt16(bytes, at: rowOffset + x * layout.pixelStride, order: order)
                    guard sample <= maximum else {
                        throw CodecError(.invalidArgument, "A sample exceeds the declared meaningful precision.")
                    }
                    plane[y * stride + x] = Int32(sample) - shift
                }
            }
        }
        try Wavelet53.forward(plane: &plane, stride: stride, width: width, height: height,
                              levels: cod.decompositionLevels, cancellation: work.check)

        let total = geometry.codeBlockCount
        var completed = 0
        progress?(try ProgressUpdate(phase: .processing, completedUnits: 0, totalUnits: total))
        var encodings: [[[[CodeBlockEncoding]]]] = []
        var coefficients: [Int32] = []
        for resolution in geometry.resolutions {
            var perPrecinct: [[[CodeBlockEncoding]]] = []
            for precinct in resolution.precincts {
                var perBand: [[CodeBlockEncoding]] = []
                for precinctBand in precinct.bands {
                    let band = resolution.bands[precinctBand.bandIndex]
                    let mb = guardBits + precision + band.gain - 1
                    var perBlock: [CodeBlockEncoding] = []
                    for block in precinctBand.blocks {
                        try work.check()
                        coefficients.removeAll(keepingCapacity: true)
                        for row in 0..<block.height {
                            let planeRow = (band.planeY + block.y0 + row) * stride + band.planeX + block.x0
                            coefficients.append(contentsOf: plane[planeRow..<planeRow + block.width])
                        }
                        perBlock.append(try BitPlaneCoder.encode(coefficients: coefficients, width: block.width,
                                                                 height: block.height, orientation: band.orientation,
                                                                 magnitudeBitPlanes: mb))
                        completed += 1
                        if completed & 7 == 0 {
                            progress?(try ProgressUpdate(phase: .processing, completedUnits: completed, totalUnits: total))
                        }
                    }
                    perBand.append(perBlock)
                }
                perPrecinct.append(perBand)
            }
            encodings.append(perPrecinct)
        }

        // Codestream assembly.
        var tile = ByteWriter(capacity: width * height / 2)
        try Tier2.encodePackets(geometry: geometry, encodings: encodings, into: &tile, cancellation: work.check)
        var out = ByteWriter(capacity: tile.count + 64)
        out.writeUInt16(Marker.soc)
        let size = ImageSizeSegment(capabilities: 0, width: width, height: height, originX: 0, originY: 0,
                                    tileWidth: width, tileHeight: height, tileOriginX: 0, tileOriginY: 0,
                                    components: [ComponentSignalling(precision: precision, signed: false,
                                                                     horizontalSeparation: 1, verticalSeparation: 1)])
        try CodestreamSyntax.writeSIZ(size, into: &out)
        try CodestreamSyntax.writeCOD(cod, into: &out)
        try CodestreamSyntax.writeQCD(qcd, into: &out)
        let psot = 12 + 2 + tile.count
        guard psot <= Int(UInt32.max) else { throw CodecError(.resourceLimitExceeded, "Tile-part exceeds the Psot field.") }
        out.writeUInt16(Marker.sot)
        out.writeUInt16(10)
        out.writeUInt16(0)
        out.writeUInt32(UInt32(psot))
        out.writeUInt8(0)
        out.writeUInt8(1)
        out.writeUInt16(Marker.sod)
        out.writeBytes(tile.bytes)
        out.writeUInt16(Marker.eoc)
        return (out.bytes, workspace)
    }
}
