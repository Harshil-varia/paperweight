import AppKit
import SwiftUI

@MainActor
protocol OverlaySink {
    func apply(_ resolved: ResolvedOverlay)
}

@MainActor
class OverlayController: OverlaySink {
    /// Panels keyed by stable display ID (NOT array index — that reorders on
    /// hot-plug and would misattribute per-display state).
    private var panels: [CGDirectDisplayID: OverlayPanel] = [:]
    /// The backing scale factor of each panel's display, captured at reconcile
    /// time so each display's tile is generated at its own pixel density.
    private var panelScales: [CGDirectDisplayID: CGFloat] = [:]
    private let engine: TextureProviding

    /// The most recently resolved state, re-applied whenever the panel set
    /// changes (hot-plug, wake) so new panels render immediately.
    private var lastResolved: ResolvedOverlay?

    init(engine: TextureProviding = TextureEngine()) {
        self.engine = engine
    }

    /// Number of live panels — exposed for tests.
    var panelCount: Int { panels.count }

    func reconcile(_ screens: [NSScreen]) {
        let currentIDs = Set(screens.map { $0.displayID })

        // Close panels for displays that are gone.
        for (id, panel) in panels where !currentIDs.contains(id) {
            panel.close()
            panels.removeValue(forKey: id)
            panelScales.removeValue(forKey: id)
        }

        // Create or re-assert a panel per current display.
        for screen in screens {
            let id = screen.displayID
            panelScales[id] = max(screen.backingScaleFactor, 1)

            if let panel = panels[id] {
                // Re-assert frame and level (classic regressions on display
                // reconfiguration and wake) and keep it on top.
                panel.setFrame(screen.frame, display: true)
                panel.level = .screenSaver
                panel.orderFrontRegardless()
            } else {
                let panel = OverlayPanel(screen: screen)
                panels[id] = panel
                panel.orderFrontRegardless()
            }
        }

        // Make freshly created/re-framed panels show the current texture.
        if let resolved = lastResolved {
            apply(resolved)
        }
    }

    func apply(_ resolved: ResolvedOverlay) {
        lastResolved = resolved

        for (id, panel) in panels {
            let scale = panelScales[id] ?? max(panel.backingScaleFactor, 1)
            // Cached by (profile, scale), so per-display scales are cheap and
            // each display gets grain at its own physical pixel density.
            let tile = engine.tile(for: resolved.profile, scale: scale)

            let key = String(id)
            let perDisplayVisible = resolved.perDisplayVisibility[key] ?? resolved.isVisible
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
