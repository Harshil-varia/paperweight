import AppKit

class OverlayLayerView: NSView {
    private let overlayLayer = CALayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupLayer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayer() {
        wantsLayer = true
        layer?.addSublayer(overlayLayer)
        overlayLayer.frame = bounds
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        overlayLayer.frame = bounds
    }

    /// The most recently applied tile, kept so the pattern can be rebuilt at the
    /// correct density if the window moves to a display with a different scale.
    private var currentTile: TileImage?

    func apply(_ resolved: ResolvedOverlay, tile: TileImage?) {
        currentTile = resolved.isVisible ? tile : currentTile

        if resolved.isVisible {
            if let tile = tile {
                applyTileImage(tile, opacity: resolved.effectiveOpacity, blendMode: resolved.profile.blendMode)
            } else {
                // Fallback to flat matte if no tile is available.
                applyFlatMatte(opacity: resolved.effectiveOpacity)
            }
        } else {
            overlayLayer.opacity = 0.0
        }
    }

    private func applyFlatMatte(opacity: Float) {
        overlayLayer.contents = nil
        overlayLayer.backgroundColor = NSColor(
            red: 0.8,
            green: 0.8,
            blue: 0.8,
            alpha: 1.0
        ).cgColor
        overlayLayer.opacity = opacity
        overlayLayer.compositingFilter = nil
    }

    private func applyTileImage(_ tile: TileImage, opacity: Float, blendMode: BlendMode) {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0

        // Repeat the seamless tile across the ENTIRE layer via a pattern-colored
        // background. `contents` only paints one copy (any gravity), which is what
        // left the overlay covering a single tile-sized patch; a pattern fill tiles
        // the small texture on the GPU and never allocates a full-screen bitmap, so
        // memory stays flat. Sizing the NSImage in points (pixels ÷ scale) maps one
        // tile pixel to one physical pixel, keeping the grain crisp on Retina.
        overlayLayer.contents = nil
        overlayLayer.contentsScale = scale
        overlayLayer.backgroundColor = OverlayLayerView.tilePatternColor(for: tile, scale: scale).cgColor
        overlayLayer.opacity = opacity
        overlayLayer.compositingFilter = blendMode.compositingFilterName
    }

    /// A repeating pattern color built from a seamless tile. Sizing the image in
    /// points (pixels ÷ scale) maps one tile pixel to one physical pixel so the
    /// grain stays crisp, and the pattern fills any rect it is painted into —
    /// which is what makes the overlay cover the whole display.
    static func tilePatternColor(for tile: TileImage, scale: CGFloat) -> NSColor {
        let pointSize = NSSize(width: tile.size.width / max(scale, 1), height: tile.size.height / max(scale, 1))
        let patternImage = NSImage(cgImage: tile.cgImage, size: pointSize)
        return NSColor(patternImage: patternImage)
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        overlayLayer.contentsScale = window?.backingScaleFactor ?? 2.0
        // Rebuild the pattern at the new display's density so it stays crisp.
        if let tile = currentTile, overlayLayer.backgroundColor != nil {
            let scale = window?.backingScaleFactor ?? 2.0
            overlayLayer.backgroundColor = OverlayLayerView.tilePatternColor(for: tile, scale: scale).cgColor
        }
    }
}

extension BlendMode {
    var compositingFilterName: String {
        switch self {
        case .softLight:
            return "softLightBlendMode"
        case .multiply:
            return "multiplyBlendMode"
        case .screen:
            return "screenBlendMode"
        case .overlay:
            return "overlayBlendMode"
        }
    }
}
