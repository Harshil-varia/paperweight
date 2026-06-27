import AppKit
import SwiftUI

@MainActor
protocol OverlaySink {
    func apply(_ resolved: ResolvedOverlay)
}

@MainActor
class OverlayController: OverlaySink {
    private var panels: [Int: OverlayPanel] = [:]

    init() {}

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
        for panel in panels.values {
            panel.apply(resolved)
        }
    }
}
