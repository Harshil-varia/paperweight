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

        Window("Preferences", id: "preferences") {
            PreferencesView()
                .environmentObject(appDelegate.coordinator)
        }

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
