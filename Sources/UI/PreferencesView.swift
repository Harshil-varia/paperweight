import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var selectedTab: Tab = .textures

    enum Tab: String, CaseIterable {
        case general = "General"
        case textures = "Textures"
        case schedule = "Schedule"
        case exclusions = "Exclusions"
        case about = "About"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(Theme.spacingL)

            Divider()
                .foregroundColor(Theme.bg2)

            // Tab content
            TabContentView(selectedTab: selectedTab)
                .environmentObject(coordinator)

            Spacer()
        }
        .frame(width: 600, height: 500)
        .background(Theme.bg0)
    }
}

// MARK: - TabContentView

struct TabContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    let selectedTab: PreferencesView.Tab

    var body: some View {
        Group {
            switch selectedTab {
            case .general:
                GeneralTab()
            case .textures:
                TexturesTab()
            case .schedule:
                ScheduleTab()
            case .exclusions:
                ExclusionsTab()
            case .about:
                AboutTab()
            }
        }
        .padding(Theme.spacingL)
    }
}

// MARK: - GeneralTab

struct GeneralTab: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingL) {
            Text("General Settings")
                .font(Theme.monoFont(size: 16, weight: .bold))
                .foregroundColor(Theme.fg)

            VStack(alignment: .leading, spacing: Theme.spacingM) {
                Toggle("Launch at Login", isOn: .constant(false))
                    .tint(Theme.green)

                Toggle("Pause on Battery", isOn: .constant(false))
                    .tint(Theme.green)
            }

            Spacer()
        }
    }
}

// MARK: - TexturesTab

struct TexturesTab: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var selectedPresetID: String = "eink-calm"

    var body: some View {
        HStack(spacing: Theme.spacingL) {
            // Gallery
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                Text("Comfort")
                    .font(Theme.monoFont(size: 12, weight: .bold))
                    .foregroundColor(Theme.fg2)
                    .tracking(0.02)

                // Comfort row presets
                VStack(spacing: Theme.spacingM) {
                    HStack(spacing: Theme.spacingM) {
                        TextureGalleryItem(profile: .eInkCalm, isSelected: selectedPresetID == "eink-calm") {
                            selectedPresetID = "eink-calm"
                            coordinator.settings.selectedProfileID = "eink-calm"
                        }

                        TextureGalleryItem(profile: .classicMatte, isSelected: selectedPresetID == "classic-matte") {
                            selectedPresetID = "classic-matte"
                            coordinator.settings.selectedProfileID = "classic-matte"
                        }
                    }

                    HStack(spacing: Theme.spacingM) {
                        TextureGalleryItem(profile: .vellumMist, isSelected: selectedPresetID == "vellum-mist") {
                            selectedPresetID = "vellum-mist"
                            coordinator.settings.selectedProfileID = "vellum-mist"
                        }

                        TextureGalleryItem(profile: .blueprint, isSelected: selectedPresetID == "blueprint") {
                            selectedPresetID = "blueprint"
                            coordinator.settings.selectedProfileID = "blueprint"
                        }
                    }
                }

                Divider()
                    .foregroundColor(Theme.bg2)

                Text("Character")
                    .font(Theme.monoFont(size: 12, weight: .bold))
                    .foregroundColor(Theme.fg2)
                    .tracking(0.02)

                // Character row presets (8 presets in 4x2 grid)
                VStack(spacing: Theme.spacingM) {
                    HStack(spacing: Theme.spacingM) {
                        TextureGalleryItem(profile: .whisperWeave, isSelected: selectedPresetID == "whisper-weave") {
                            selectedPresetID = "whisper-weave"
                            coordinator.settings.selectedProfileID = "whisper-weave"
                        }

                        TextureGalleryItem(profile: .sunbakedParchment, isSelected: selectedPresetID == "sunbaked-parchment") {
                            selectedPresetID = "sunbaked-parchment"
                            coordinator.settings.selectedProfileID = "sunbaked-parchment"
                        }
                    }

                    HStack(spacing: Theme.spacingM) {
                        TextureGalleryItem(profile: .saddleLinen, isSelected: selectedPresetID == "saddle-linen") {
                            selectedPresetID = "saddle-linen"
                            coordinator.settings.selectedProfileID = "saddle-linen"
                        }

                        TextureGalleryItem(profile: .paintersPress, isSelected: selectedPresetID == "painters-press") {
                            selectedPresetID = "painters-press"
                            coordinator.settings.selectedProfileID = "painters-press"
                        }
                    }

                    HStack(spacing: Theme.spacingM) {
                        TextureGalleryItem(profile: .mulberryVeil, isSelected: selectedPresetID == "mulberry-veil") {
                            selectedPresetID = "mulberry-veil"
                            coordinator.settings.selectedProfileID = "mulberry-veil"
                        }

                        TextureGalleryItem(profile: .monasticFelt, isSelected: selectedPresetID == "monastic-felt") {
                            selectedPresetID = "monastic-felt"
                            coordinator.settings.selectedProfileID = "monastic-felt"
                        }
                    }

                    HStack(spacing: Theme.spacingM) {
                        TextureGalleryItem(profile: .carbonLedger, isSelected: selectedPresetID == "carbon-ledger") {
                            selectedPresetID = "carbon-ledger"
                            coordinator.settings.selectedProfileID = "carbon-ledger"
                        }

                        TextureGalleryItem(profile: .risoGrain, isSelected: selectedPresetID == "riso-grain") {
                            selectedPresetID = "riso-grain"
                            coordinator.settings.selectedProfileID = "riso-grain"
                        }
                    }
                }

                Spacer()
            }

            Divider()
                .foregroundColor(Theme.bg2)

            // Inspector
            TextureInspector(profile: TextureProfile.preset(withID: selectedPresetID) ?? .eInkCalm)
        }
    }
}

// MARK: - TextureGalleryItem

struct TextureGalleryItem: View {
    let profile: TextureProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: Theme.spacingS) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .fill(Color(red: 0.94, green: 0.94, blue: 0.93))

                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.05),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
            }
            .frame(height: 80)
            .border(
                isSelected ? Theme.yellow : Color.black.opacity(0.3),
                width: isSelected ? 2 : 0.5
            )
            .cornerRadius(Theme.cornerRadiusSmall)

            Text(profile.name)
                .font(Theme.monoFont(size: 11))
                .foregroundColor(isSelected ? Theme.yellow : Theme.fg4)
                .fontWeight(isSelected ? .bold : .regular)
                .lineLimit(1)
        }
        .onTapGesture(perform: action)
    }
}

// MARK: - TextureInspector

struct TextureInspector: View {
    let profile: TextureProfile

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingL) {
            Text("Preview & Settings")
                .font(Theme.monoFont(size: 14, weight: .bold))
                .foregroundColor(Theme.fg)

            // Large preview
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)
                    .fill(Color(red: 0.94, green: 0.94, blue: 0.93))

                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.08),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
            }
            .frame(height: 160)
            .border(Theme.bg2, width: 0.5)
            .cornerRadius(Theme.cornerRadiusMedium)

            // Info
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                HStack {
                    Text("Name:")
                        .font(Theme.monoFont(size: 11))
                        .foregroundColor(Theme.fg4)
                    Spacer()
                    Text(profile.name)
                        .font(Theme.monoFont(size: 11))
                        .foregroundColor(Theme.fg)
                }

                HStack {
                    Text("Noise Type:")
                        .font(Theme.monoFont(size: 11))
                        .foregroundColor(Theme.fg4)
                    Spacer()
                    Text(profile.noiseType.rawValue)
                        .font(Theme.monoFont(size: 11))
                        .foregroundColor(Theme.fg)
                }

                HStack {
                    Text("Blend Mode:")
                        .font(Theme.monoFont(size: 11))
                        .foregroundColor(Theme.fg4)
                    Spacer()
                    Text(profile.blendMode.rawValue)
                        .font(Theme.monoFont(size: 11))
                        .foregroundColor(Theme.fg)
                }
            }
            .padding(Theme.spacingM)
            .background(Theme.bg0Hard)
            .border(Theme.bg1, width: 0.5)
            .cornerRadius(Theme.cornerRadiusSmall)

            #if DEBUG
            Divider()
                .foregroundColor(Theme.bg2)

            LabPanelContent(profile: profile)
            #endif

            Spacer()
        }
    }
}

// MARK: - ScheduleTab

struct ScheduleTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingL) {
            Text("Schedule")
                .font(Theme.monoFont(size: 16, weight: .bold))
                .foregroundColor(Theme.fg)

            Text("Schedule support coming in Phase 4")
                .font(Theme.monoFont(size: 12))
                .foregroundColor(Theme.fg4)

            Spacer()
        }
    }
}

// MARK: - ExclusionsTab

struct ExclusionsTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingL) {
            Text("Exclusions")
                .font(Theme.monoFont(size: 16, weight: .bold))
                .foregroundColor(Theme.fg)

            Text("Exclusion management coming in Phase 5")
                .font(Theme.monoFont(size: 12))
                .foregroundColor(Theme.fg4)

            Spacer()
        }
    }
}

// MARK: - AboutTab

struct AboutTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingL) {
            Text("About Paperweight")
                .font(Theme.monoFont(size: 16, weight: .bold))
                .foregroundColor(Theme.fg)

            VStack(alignment: .leading, spacing: Theme.spacingM) {
                HStack {
                    Text("Version:")
                        .font(Theme.monoFont(size: 11))
                        .foregroundColor(Theme.fg4)
                    Spacer()
                    Text("0.1")
                        .font(Theme.monoFont(size: 11))
                        .foregroundColor(Theme.fg)
                }

                Text("No network calls. No telemetry. No tracking.")
                    .font(Theme.monoFont(size: 11))
                    .foregroundColor(Theme.fg4)
                    .lineLimit(3)
            }

            Spacer()
        }
    }
}

#Preview {
    PreferencesView()
        .environmentObject(AppCoordinator())
}
