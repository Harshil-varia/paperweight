import AppKit
import SwiftUI

@MainActor
protocol OverlaySink {
    func apply(_ resolved: ResolvedOverlay)
}

@MainActor
class OverlayController: OverlaySink {
    private var panels: [Int: OverlayPanel] = [:]
    private let engine: TextureProviding

    init(engine: TextureProviding = TextureEngine()) {
        self.engine = engine
    }

    func reconcile(_ screens: [NSScreen]) {
        // Create a set of current screen IDs (use index as ID)
        let currentScreenIds = Set(0..<screens.count)

        // Remove panels for screens that no longer exist
        for (screenId, panel) in panels {
            if !currentScreenIds.contains(screenId) {
                panel.close()
                panels.removeValue(forKey: screenId)
            }
        }

        // Create or update panels for current screens
        for (index, screen) in screens.enumerated() {
            if let existingPanel = panels[index] {
                // Update frame and level
                existingPanel.setFrame(screen.frame, display: true)
                existingPanel.level = NSWindow.Level.screenSaver
            } else {
                // Create new panel
                let panel = OverlayPanel(screen: screen)
                panels[index] = panel
                panel.orderFrontRegardless()
            }
        }
    }

    func apply(_ resolved: ResolvedOverlay) {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let tile = engine.tile(for: resolved.profile, scale: scale)

        // Apply per-display visibility
        for (screenId, panel) in panels {
            let displayID = String(screenId)
            let perDisplayVisible = resolved.perDisplayVisibility[displayID] ?? resolved.isVisible
            let perDisplayResolved = ResolvedOverlay(
                isVisible: perDisplayVisible,
                profile: resolved.profile,
                effectiveOpacity: resolved.effectiveOpacity,
                perDisplayVisibility: resolved.perDisplayVisibility
            )
            panel.apply(perDisplayResolved, tile: tile)
        }
    }
}
