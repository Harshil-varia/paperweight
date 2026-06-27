import XCTest
import AppKit
@testable import Paperweight

class OverlayControllerTests: XCTestCase {
    @MainActor
    func testReconcileCreatesOnePanel() {
        let controller = OverlayController()
        let screen = FakeScreen(displayID: 1, frame: NSRect(x: 0, y: 0, width: 1920, height: 1080))

        controller.reconcile([screen])

        // Verify panel was created
        XCTAssertEqual(controller.getPanelCount(), 1)
    }

    @MainActor
    func testReconcileHandleMultipleScreens() {
        let controller = OverlayController()
        let screen1 = FakeScreen(displayID: 1, frame: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        let screen2 = FakeScreen(displayID: 2, frame: NSRect(x: 1920, y: 0, width: 1920, height: 1080))

        controller.reconcile([screen1, screen2])

        XCTAssertEqual(controller.getPanelCount(), 2)
    }

    @MainActor
    func testReconcileRemovesPanelsForDisconnectedScreens() {
        let controller = OverlayController()
        let screen1 = FakeScreen(displayID: 1, frame: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        let screen2 = FakeScreen(displayID: 2, frame: NSRect(x: 1920, y: 0, width: 1920, height: 1080))

        // First reconcile with 2 screens
        controller.reconcile([screen1, screen2])
        XCTAssertEqual(controller.getPanelCount(), 2)

        // Then reconcile with 1 screen (screen2 disconnected)
        controller.reconcile([screen1])
        XCTAssertEqual(controller.getPanelCount(), 1)
    }

    @MainActor
    func testReconcileHandlesScreenReordering() {
        let controller = OverlayController()
        let screen1 = FakeScreen(displayID: 1, frame: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        let screen2 = FakeScreen(displayID: 2, frame: NSRect(x: 1920, y: 0, width: 1920, height: 1080))

        controller.reconcile([screen1, screen2])
        XCTAssertEqual(controller.getPanelCount(), 2)

        // Reorder and add a third screen
        let screen3 = FakeScreen(displayID: 3, frame: NSRect(x: 3840, y: 0, width: 1920, height: 1080))
        controller.reconcile([screen2, screen1, screen3])

        XCTAssertEqual(controller.getPanelCount(), 3)
    }

    @MainActor
    func testApplyUpdatesAllPanels() {
        let controller = OverlayController()
        let screen = FakeScreen(displayID: 1, frame: NSRect(x: 0, y: 0, width: 1920, height: 1080))

        controller.reconcile([screen])

        let resolved = ResolvedOverlay(
            isVisible: true,
            profileID: "test",
            effectiveOpacity: 0.2
        )

        // This should not crash; panels should apply the resolved state
        controller.apply(resolved)
    }
}

// MARK: - Fake Screen

class FakeScreen: NSScreen {
    let screenFrame: NSRect

    init(displayID: Int, frame: NSRect) {
        self.screenFrame = frame
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var frame: NSRect {
        screenFrame
    }
}

// MARK: - Controller Test Helper

extension OverlayController {
    func getPanelCount() -> Int {
        // Access private panels via reflection for testing
        let mirror = Mirror(reflecting: self)
        if let panelsChild = mirror.children.first(where: { $0.label == "panels" }),
           let panels = panelsChild.value as? [Int: OverlayPanel] {
            return panels.count
        }
        return 0
    }
}
