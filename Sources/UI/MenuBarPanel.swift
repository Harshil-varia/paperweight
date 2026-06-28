import SwiftUI

struct MenuBarPanel: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: Theme.spacingM) {
            // Header with title and toggle
            HStack(spacing: Theme.spacingM) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paperweight")
                        .font(Theme.monoFont(size: 15, weight: .bold))
                        .foregroundColor(Theme.fg)

                    Text(coordinator.settings.isEnabled ? "on · all displays" : "off")
                        .font(Theme.monoFont(size: 11))
                        .foregroundColor(Theme.fg4)
                }

                Spacer()

                Toggle("", isOn: $coordinator.settings.isEnabled)
                    .labelsHidden()
                    .tint(Theme.green)
            }

            // Comfort slider block
            VStack(spacing: Theme.spacingS) {
                HStack {
                    Text("COMFORT")
                        .font(Theme.monoFont(size: 12, weight: .bold))
                        .foregroundColor(Theme.fg2)
                        .tracking(0.02)

                    Spacer()

                    Text("\(Int(coordinator.settings.comfort * 100))%")
                        .font(Theme.monoFont(size: 12, weight: .bold))
                        .foregroundColor(Theme.yellow)
                }

                // Slider
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.bg2)
                        .frame(height: Theme.Slider.trackHeight)

                    Capsule()
                        .fill(Theme.yellow)
                        .frame(width: CGFloat(coordinator.settings.comfort) * 260, height: Theme.Slider.trackHeight)

                    HStack {
                        Spacer()
                            .frame(width: CGFloat(coordinator.settings.comfort) * 260 - 9)

                        Circle()
                            .fill(Theme.fg)
                            .frame(width: Theme.Slider.knobDiameter, height: Theme.Slider.knobDiameter)
                            .shadow(color: Color.black.opacity(0.5), radius: 1, x: 0, y: 1)

                        Spacer()
                    }
                }
                .frame(height: Theme.Slider.height)
                .onContinuousHover { phase in
                    // Slider hover handling
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let percent = Float(value.location.x / 280)
                            coordinator.settings.comfort = max(0, min(1, percent))
                        }
                )

                HStack {
                    Text("subtle")
                        .font(Theme.monoFont(size: 10))
                        .foregroundColor(Theme.gray)

                    Spacer()

                    Text("strong")
                        .font(Theme.monoFont(size: 10))
                        .foregroundColor(Theme.gray)
                }
            }
            .padding(Theme.spacingM)
            .background(Theme.bg0Hard)
            .border(Theme.bg1, width: 0.5)
            .cornerRadius(Theme.cornerRadiusSmall)

            // Texture swatches (4-up row — Comfort row)
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                Text("TEXTURE")
                    .font(Theme.monoFont(size: 11, weight: .bold))
                    .foregroundColor(Theme.fg4)
                    .tracking(0.04)

                HStack(spacing: Theme.spacingS) {
                    SwatchView(profile: .eInkCalm, isSelected: coordinator.settings.selectedProfileID == "eink-calm") {
                        coordinator.settings.selectedProfileID = "eink-calm"
                    }

                    SwatchView(profile: .classicMatte, isSelected: coordinator.settings.selectedProfileID == "classic-matte") {
                        coordinator.settings.selectedProfileID = "classic-matte"
                    }

                    SwatchView(profile: .vellumMist, isSelected: coordinator.settings.selectedProfileID == "vellum-mist") {
                        coordinator.settings.selectedProfileID = "vellum-mist"
                    }

                    SwatchView(profile: .blueprint, isSelected: coordinator.settings.selectedProfileID == "blueprint") {
                        coordinator.settings.selectedProfileID = "blueprint"
                    }
                }
            }
            .padding(Theme.spacingM)
            .background(Theme.bg0Hard)
            .border(Theme.bg1, width: 0.5)
            .cornerRadius(Theme.cornerRadiusSmall)

            // Snooze control
            if coordinator.isSnoozed {
                Button(action: { coordinator.endSnooze() }) {
                    HStack(spacing: Theme.spacingS) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 11))
                        Text("Snoozed — Resume now")
                            .font(Theme.monoFont(size: 11, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(Theme.bg0)
                    .padding(.vertical, Theme.spacingS)
                    .padding(.horizontal, Theme.spacingM)
                    .background(Theme.yellow)
                    .cornerRadius(Theme.cornerRadiusSmall)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: Theme.spacingS) {
                    Text("SNOOZE")
                        .font(Theme.monoFont(size: 11, weight: .bold))
                        .foregroundColor(Theme.fg4)
                        .tracking(0.04)
                    Spacer()
                    Button("20m") { coordinator.snooze(minutes: 20) }
                        .gruvboxButton()
                    Button("1h") { coordinator.snooze(minutes: 60) }
                        .gruvboxButton()
                }
            }

            // Footer buttons
            HStack(spacing: Theme.spacingS) {
                Button("Preferences…") {
                    // Handled by AppDelegate, which owns the Preferences NSWindow.
                    NotificationCenter.default.post(name: .paperweightShowPreferences, object: nil)
                }
                .gruvboxButton()

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .gruvboxButton()
                .help("Quit Paperweight")
            }
        }
        .padding(Theme.spacingL)
        .frame(width: 322)
        .background(Theme.bg0)
        .border(Theme.bg2, width: 0.5)
        .cornerRadius(Theme.cornerRadiusMedium)
    }
}

// MARK: - SwatchView

struct SwatchView: View {
    let profile: TextureProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: Theme.spacingS) {
            ZStack {
                // Light background to show what the texture would look like
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .fill(Color(red: 0.94, green: 0.94, blue: 0.93))

                // Add a subtle noise pattern based on profile type
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.05),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
            }
            .frame(height: 46)
            .border(
                isSelected ? Theme.yellow : Color.black.opacity(0.3),
                width: isSelected ? 2 : 0.5
            )
            .cornerRadius(Theme.cornerRadiusSmall)
            .shadow(
                color: isSelected ? Theme.yellow.opacity(0.22) : .clear,
                radius: 0,
                x: 0,
                y: 0
            )

            Text(profile.name)
                .font(Theme.monoFont(size: 9.5))
                .foregroundColor(isSelected ? Theme.yellow : Theme.fg4)
                .fontWeight(isSelected ? .bold : .regular)
                .lineLimit(1)
        }
        .onTapGesture(perform: action)
    }
}

#Preview {
    MenuBarPanel()
        .environmentObject(AppCoordinator())
}
