// SPDX-License-Identifier: Apache-2.0
//
// Reversible 5/3 discrete wavelet transform (ISO/IEC 15444-1 Annex F, F.3.8.2
// and F.4.8.2, lifting form with periodic symmetric extension).
//
// Provenance: the one-dimensional lifting kernels are adapted from
// Raster-Lab/J2KSwift at commit 7acc9ae415e7d0bc7d441e0f0277d5e150bd19ca,
// Sources/J2KCodec/J2KDWT1D.swift (`forwardTransform53`, `inverseTransform53`
// and the symmetric extension helper; MIT, relicensed Apache-2.0 under
// POL-07). The two-dimensional driver is new: it works in place on the
// standard nested subband layout (LL top-left, HL top-right, LH bottom-left,
// HH bottom-right) for a tile anchored at the origin, applying VER_SD then
// HOR_SD on analysis and HOR_SR then VER_SR on synthesis, in the order the
// standard fixes so that other decoders reconstruct the same integers.

enum Wavelet53 {
    /// Splits one signal of length `n` (origin 0) into `ceil(n/2)` low-pass
    /// and `floor(n/2)` high-pass coefficients.
    static func analyse(_ x: [Int32], count n: Int, into low: inout [Int32], _ high: inout [Int32]) {
        let lowCount = (n + 1) / 2, highCount = n / 2
        if n == 1 {
            low[0] = x[0]
            return
        }
        // Y(2n+1) = X(2n+1) - floor((X(2n) + X(2n+2)) / 2)
        for i in 0..<highCount {
            let left = x[2 * i]
            let right = 2 * i + 2 < n ? x[2 * i + 2] : x[2 * i]   // X(n) mirrors X(n-2)
            high[i] = x[2 * i + 1] - ((left + right) >> 1)
        }
        // Y(2n) = X(2n) + floor((Y(2n-1) + Y(2n+1) + 2) / 4)
        for i in 0..<lowCount {
            let left = i > 0 ? high[i - 1] : high[0]
            let right = i < highCount ? high[i] : high[highCount - 1]
            low[i] = x[2 * i] + ((left + right + 2) >> 2)
        }
    }

    /// Inverse of `analyse`: reconstructs `n` samples from `ceil(n/2)` low-pass
    /// and `floor(n/2)` high-pass coefficients.
    static func synthesise(low: [Int32], high: [Int32], count n: Int, into x: inout [Int32]) {
        let lowCount = (n + 1) / 2, highCount = n / 2
        if n == 1 {
            x[0] = low[0]
            return
        }
        // X(2n) = Y(2n) - floor((Y(2n-1) + Y(2n+1) + 2) / 4)
        for i in 0..<lowCount {
            let left = i > 0 ? high[i - 1] : high[0]
            let right = i < highCount ? high[i] : high[highCount - 1]
            x[2 * i] = low[i] - ((left + right + 2) >> 2)
        }
        // X(2n+1) = Y(2n+1) + floor((X(2n) + X(2n+2)) / 2)
        for i in 0..<highCount {
            let left = x[2 * i]
            let right = 2 * i + 2 < n ? x[2 * i + 2] : x[2 * i]
            x[2 * i + 1] = high[i] + ((left + right) >> 1)
        }
    }

    /// Forward transform of the top-left `width × height` region of `plane`
    /// (row stride `stride`) for `levels` levels, leaving the nested subband
    /// layout in place. Coefficient magnitudes grow by at most two bits, so
    /// 16-bit samples never approach the `Int32` range.
    static func forward(plane: inout [Int32], stride: Int, width: Int, height: Int,
                        levels: Int, cancellation: () throws -> Void) throws {
        var w = width, h = height
        var line = [Int32](repeating: 0, count: max(width, height))
        var low = [Int32](repeating: 0, count: (max(width, height) + 1) / 2)
        var high = [Int32](repeating: 0, count: max(width, height) / 2)
        for _ in 0..<levels {
            guard w > 0, h > 0 else { break }
            // VER_SD on every column, then HOR_SD on every row (F.4.8.2).
            if h > 1 {
                for x in 0..<w {
                    for y in 0..<h { line[y] = plane[y * stride + x] }
                    analyse(line, count: h, into: &low, &high)
                    let lowCount = (h + 1) / 2
                    for i in 0..<lowCount { plane[i * stride + x] = low[i] }
                    for i in 0..<(h / 2) { plane[(lowCount + i) * stride + x] = high[i] }
                    if x & 63 == 63 { try cancellation() }
                }
            }
            if w > 1 {
                for y in 0..<h {
                    for x in 0..<w { line[x] = plane[y * stride + x] }
                    analyse(line, count: w, into: &low, &high)
                    let lowCount = (w + 1) / 2
                    for i in 0..<lowCount { plane[y * stride + i] = low[i] }
                    for i in 0..<(w / 2) { plane[y * stride + lowCount + i] = high[i] }
                    if y & 63 == 63 { try cancellation() }
                }
            }
            w = (w + 1) / 2; h = (h + 1) / 2
            try cancellation()
        }
    }

    /// Inverse transform: reverses `forward` for the same geometry.
    static func inverse(plane: inout [Int32], stride: Int, width: Int, height: Int,
                        levels: Int, cancellation: () throws -> Void) throws {
        var line = [Int32](repeating: 0, count: max(width, height))
        var low = [Int32](repeating: 0, count: (max(width, height) + 1) / 2)
        var high = [Int32](repeating: 0, count: max(width, height) / 2)
        for level in Swift.stride(from: levels, through: 1, by: -1) {
            // Resolution r = levels - level + 1 has dimensions ceil(size / 2^(level-1)).
            let w = ceilDivPowerOfTwo(width, level - 1), h = ceilDivPowerOfTwo(height, level - 1)
            guard w > 0, h > 0 else { continue }
            // HOR_SR on every row, then VER_SR on every column (F.3.8).
            if w > 1 {
                let lowCount = (w + 1) / 2
                for y in 0..<h {
                    for i in 0..<lowCount { low[i] = plane[y * stride + i] }
                    for i in 0..<(w / 2) { high[i] = plane[y * stride + lowCount + i] }
                    synthesise(low: low, high: high, count: w, into: &line)
                    for x in 0..<w { plane[y * stride + x] = line[x] }
                    if y & 63 == 63 { try cancellation() }
                }
            }
            if h > 1 {
                let lowCount = (h + 1) / 2
                for x in 0..<w {
                    for i in 0..<lowCount { low[i] = plane[i * stride + x] }
                    for i in 0..<(h / 2) { high[i] = plane[(lowCount + i) * stride + x] }
                    synthesise(low: low, high: high, count: h, into: &line)
                    for y in 0..<h { plane[y * stride + x] = line[y] }
                    if x & 63 == 63 { try cancellation() }
                }
            }
            try cancellation()
        }
    }

    /// ceil(value / 2^power) for non-negative values.
    static func ceilDivPowerOfTwo(_ value: Int, _ power: Int) -> Int {
        guard power > 0 else { return value }
        return (value + (1 << power) - 1) >> power
    }
}
