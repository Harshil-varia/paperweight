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

    func apply(_ resolved: ResolvedOverlay, tile: TileImage?) {
        if resolved.isVisible {
            // Phase 2: use tile image directly if available, fallback to flat matte
            if let tile = tile {
                applyTileImage(tile, opacity: resolved.effectiveOpacity, blendMode: resolved.profile.blendMode)
            } else {
                // Fallback to flat matte if no tile available
                applyFlatMatte(opacity: resolved.effectiveOpacity)
            }
        } else {
            overlayLayer.opacity = 0.0
        }
    }

    private func applyFlatMatte(opacity: Float) {
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
        // Set the tile image as the layer's contents
        overlayLayer.contents = tile.cgImage

        // Configure the layer to repeat the tile
        overlayLayer.contentsGravity = .topLeft
        overlayLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0

        // Set opacity and blend mode
        overlayLayer.opacity = opacity
        overlayLayer.compositingFilter = blendMode.compositingFilterName
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        // Update contents scale when backing properties change (e.g., on external display)
        if overlayLayer.contents != nil {
            overlayLayer.contentsScale = window?.backingScaleFactor ?? 2.0
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
