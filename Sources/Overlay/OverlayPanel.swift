import AppKit

class OverlayPanel: NSPanel {
    private let layerView: OverlayLayerView

    init(screen: NSScreen) {
        let frame = screen.frame
        self.layerView = OverlayLayerView(frame: frame)

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true

        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]

        displaysWhenScreenProfileChanges = true
        contentView = layerView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ resolved: ResolvedOverlay, tile: TileImage?) {
        layerView.apply(resolved, tile: tile)
    }
}
