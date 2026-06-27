import SwiftUI

/// First-run onboarding panel: explains the benefit, points at the menu-bar glyph,
/// introduces Comfort, and offers to enable "Open at login"
struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: Theme.spacingL) {
            // Header
            VStack(spacing: Theme.spacingS) {
                Text("Welcome to Paperweight")
                    .font(Theme.monoFont(size: 16, weight: .semibold))
                    .foregroundColor(Theme.fg)

                Text("A calm paper texture overlay")
                    .font(Theme.monoFont(size: 12, weight: .regular))
                    .foregroundColor(Theme.fg2)
            }

            // Main message
            VStack(alignment: .leading, spacing: Theme.spacingM) {
                Text("Paperweight lays a soft, paper-like texture over your entire screen to reduce glare and harsh contrast. It lives quietly in your menu bar and never blocks clicks or steals focus.")
                    .font(Theme.monoFont(size: 11, weight: .regular))
                    .foregroundColor(Theme.fg)
                    .lineSpacing(2)

                HStack(spacing: Theme.spacingS) {
                    Image(systemName: "square.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.aqua)

                    Text("You can toggle it on/off from the menu bar (the icon with the texture swatch). Adjust the intensity with the Comfort slider in the menu panel.")
                        .font(Theme.monoFont(size: 11, weight: .regular))
                        .foregroundColor(Theme.fg)
                }
            }
            .padding(Theme.spacingL)
            .background(Theme.bg1)
            .cornerRadius(Theme.cornerRadiusSmall)

            // Launch at login option
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                HStack {
                    Toggle("Open at login", isOn: $coordinator.settings.launchAtLogin)
                        .font(Theme.monoFont(size: 11, weight: .regular))
                        .foregroundColor(Theme.fg)

                    Spacer()
                }
                .padding(.vertical, Theme.spacingS)
                .padding(.horizontal, Theme.spacingM)
                .background(Theme.bg1)
                .cornerRadius(Theme.cornerRadiusSmall)

                Text("Paperweight will automatically start when you log in, so the overlay is always ready.")
                    .font(Theme.monoFont(size: 10, weight: .regular))
                    .foregroundColor(Theme.fg4)
                    .lineSpacing(1.5)
            }

            Spacer()

            // Dismiss button
            Button(action: {
                var updated = coordinator.settings
                updated.hasSeenOnboarding = true
                coordinator.settings = updated
                dismiss()
            }) {
                Text("Got it")
                    .font(Theme.monoFont(size: 12, weight: .semibold))
                    .foregroundColor(Theme.fg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.spacingM)
                    .background(Theme.bg1)
                    .cornerRadius(Theme.cornerRadiusSmall)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .stroke(Theme.bg2, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.spacingXL)
        .frame(width: 380, height: 420)
        .gruvboxPanel()
        .padding(Theme.spacingL)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppCoordinator())
}
