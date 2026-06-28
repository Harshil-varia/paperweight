import SwiftUI
import AppKit

@main
struct PaperweightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Paperweight", image: "MenuBarGlyph") {
            MenuBarPanel()
                .environmentObject(appDelegate.coordinator)
        }
        .menuBarExtraStyle(.window)

        // Preferences and first-run Onboarding are AppKit windows owned by
        // AppDelegate (reliable from a menu-bar/accessory app); see
        // AppDelegate.showPreferences() and showOnboardingIfNeeded().
    }
}
