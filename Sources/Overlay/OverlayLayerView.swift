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

    func apply(_ resolved: ResolvedOverlay) {
        if resolved.isVisible {
            // Phase 1: flat solid matte at the resolved opacity
            overlayLayer.backgroundColor = NSColor(
                red: 0.8,
                green: 0.8,
                blue: 0.8,
                alpha: CGFloat(resolved.effectiveOpacity)
            ).cgColor
            overlayLayer.opacity = 1.0
        } else {
            overlayLayer.opacity = 0.0
        }
    }
}
