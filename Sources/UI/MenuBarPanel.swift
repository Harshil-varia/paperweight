import SwiftUI

struct MenuBarPanel: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Paperweight")
                    .font(.system(.headline))

                Spacer()

                Toggle("", isOn: $coordinator.settings.isEnabled)
                    .labelsHidden()
            }

            Slider(value: $coordinator.settings.comfort, in: 0...1)
                .help("Adjust overlay comfort/intensity")

            Divider()

            HStack {
                Button("Preferences…") {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .font(.system(.caption))
        }
        .padding(12)
        .frame(width: 240)
    }
}

#Preview {
    MenuBarPanel()
        .environmentObject(AppCoordinator())
}
