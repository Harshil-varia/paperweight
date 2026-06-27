import SwiftUI
import AppKit

@main
struct PaperweightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Paperweight", systemImage: "circle.fill") {
            MenuBarPanel()
                .environmentObject(appDelegate.coordinator)
        }
        .menuBarExtraStyle(.window)
    }
}
