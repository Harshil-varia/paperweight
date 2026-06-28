import XCTest
import AppKit
@testable import Paperweight

/// Regression guard for "the overlay only covers part of the screen".
///
/// The bug: the tile was assigned to `CALayer.contents` with `contentsGravity =
/// .topLeft`, which paints a single tile-sized patch in one corner instead of
/// covering the display. The fix repeats the tile via a pattern-colored
/// background. These tests render that pattern color into a region far larger
/// than one tile and assert that distant pixels are actually painted.
final class OverlayCoverageTests: XCTestCase {
    /// A small fully-opaque red tile.
    private func solidTile(_ side: Int = 8) -> TileImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                            bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let cg = ctx.makeImage()!
        return TileImage(cgImage: cg, size: CGSize(width: side, height: side))
    }

    /// Fill `rect` with the pattern color and return the RGBA bytes.
    private func render(_ color: NSColor, into side: Int) -> [UInt8] {
        let cs = CGColorSpaceCreateDeviceRGB()
        let bpr = side * 4
        var bytes = [UInt8](repeating: 0, count: bpr * side)
        bytes.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                bytesPerRow: bpr, space: cs,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = ns
            color.set()
            ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
            NSGraphicsContext.restoreGraphicsState()
        }
        return bytes
    }

    private func pixel(_ bytes: [UInt8], x: Int, y: Int, side: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        let i = (y * side + x) * 4
        return (bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3])
    }

    func testTilePatternCoversAreaFarFromOrigin() {
        let color = OverlayLayerView.tilePatternColor(for: solidTile(), scale: 1)
        let side = 600 // far larger than the 8px tile
        let bytes = render(color, into: side)

        // A pixel deep in the opposite corner must be painted red — proving the
        // tile repeats across the whole area rather than sitting in one corner.
        let (r, g, b, a) = pixel(bytes, x: side - 3, y: side - 3, side: side)
        XCTAssertGreaterThan(r, 200, "far corner should be covered by the tile")
        XCTAssertLessThan(g, 60)
        XCTAssertLessThan(b, 60)
        XCTAssertGreaterThan(a, 200, "far corner should be opaque (covered)")
    }

    func testTilePatternCoversCenterAndEdges() {
        let color = OverlayLayerView.tilePatternColor(for: solidTile(), scale: 1)
        let side = 512
        let bytes = render(color, into: side)
        for (x, y) in [(0, 0), (side / 2, side / 2), (side - 1, 0), (0, side - 1), (side - 1, side - 1)] {
            let (r, _, _, a) = pixel(bytes, x: x, y: y, side: side)
            XCTAssertGreaterThan(r, 200, "(\(x),\(y)) should be covered")
            XCTAssertGreaterThan(a, 200, "(\(x),\(y)) should be opaque")
        }
    }

    func testPointSizeHalvesAtRetinaScale() {
        // The pattern image is sized in points = pixels / scale, so a 512px tile
        // becomes 256pt on a 2x display (one tile pixel per physical pixel).
        let color = OverlayLayerView.tilePatternColor(for: solidTile(512), scale: 2)
        // NSColor pattern carries its image; assert it scaled to 256pt.
        XCTAssertEqual(color.patternImage.size.width, 256, accuracy: 0.5)
        XCTAssertEqual(color.patternImage.size.height, 256, accuracy: 0.5)
    }
}
