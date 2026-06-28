import SwiftUI
import AppKit

@main
struct PaperweightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showOnboarding = false

    var body: some Scene {
        MenuBarExtra("Paperweight", image: "MenuBarGlyph") {
            MenuBarPanel()
                .environmentObject(appDelegate.coordinator)
        }
        .menuBarExtraStyle(.window)

        // Preferences is an AppKit window owned by AppDelegate (reliable from a
        // menu-bar/accessory app); see AppDelegate.showPreferences().

        Window("Onboarding", id: "onboarding") {
            OnboardingView()
                .environmentObject(appDelegate.coordinator)
                .onAppear {
                    showOnboarding = !appDelegate.coordinator.settings.hasSeenOnboarding
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}
