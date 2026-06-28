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
            // Top header — app identity and a prominent, always-available Quit.
            VStack(spacing: Theme.spacingS) {
                Text("Paperweight")
                    .font(Theme.monoFont(size: 15, weight: .bold))
                    .foregroundColor(Theme.fg)

                Button(action: { NSApp.terminate(nil) }) {
                    HStack(spacing: Theme.spacingXS) {
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Quit Paperweight")
                            .font(Theme.monoFont(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Theme.bg0)
                    .padding(.vertical, Theme.spacingS)
                    .padding(.horizontal, Theme.spacingL)
                    .background(Theme.orange)
                    .cornerRadius(Theme.cornerRadiusSmall)
                }
                .buttonStyle(.plain)
                .help("Quit Paperweight")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.spacingL)
            .padding(.bottom, Theme.spacingM)

            Divider()
                .foregroundColor(Theme.bg2)

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
    private let launchAtLoginService = LaunchAtLoginService()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingL) {
            Text("General Settings")
                .font(Theme.monoFont(size: 16, weight: .bold))
                .foregroundColor(Theme.fg)

            VStack(alignment: .leading, spacing: Theme.spacingM) {
                Toggle("Launch at Login", isOn: Binding(
                    get: { coordinator.settings.launchAtLogin },
                    set: { newValue in
                        // Only persist the intent if the system registration
                        // actually succeeded, so the toggle never shows "on"
                        // while the app isn't really registered.
                        do {
                            try launchAtLoginService.setLaunchAtLogin(newValue)
                            coordinator.settings.launchAtLogin = newValue
                        } catch {
                            Log.lifecycle.error("Failed to set launch at login: \(String(describing: error))")
                        }
                    }
                ))
                    .tint(Theme.green)

                Toggle("Pause on Battery", isOn: Binding(
                    get: { coordinator.settings.pauseOnBattery },
                    set: { newValue in
                        coordinator.settings.pauseOnBattery = newValue
                    }
                ))
                    .tint(Theme.green)
            }

            Divider()
                .foregroundColor(Theme.bg2)

            // Default Comfort
            VStack(alignment: .leading, spacing: Theme.spacingM) {
                Text("Default Comfort")
                    .font(Theme.monoFont(size: 12, weight: .bold))
                    .foregroundColor(Theme.fg2)
                    .tracking(0.02)

                HStack(spacing: Theme.spacingM) {
                    Slider(
                        value: Binding(
                            get: { coordinator.settings.comfort },
                            set: { newValue in
                                coordinator.settings.comfort = newValue
                            }
                        ),
                        in: 0.0...1.0
                    )
                    .tint(Theme.blue)

                    Text(String(format: "%.0f%%", coordinator.settings.comfort * 100))
                        .font(Theme.monoFont(size: 11))
                        .foregroundColor(Theme.fg4)
                        .frame(width: 40)
                }
            }

            Divider()
                .foregroundColor(Theme.bg2)

            // Reduce Transparency Response
            VStack(alignment: .leading, spacing: Theme.spacingM) {
                Text("When Reduce Transparency is On")
                    .font(Theme.monoFont(size: 12, weight: .bold))
                    .foregroundColor(Theme.fg2)
                    .tracking(0.02)

                Picker("Response", selection: Binding(
                    get: { coordinator.settings.reduceTransparencyResponse },
                    set: { newValue in
                        coordinator.settings.reduceTransparencyResponse = newValue
                    }
                )) {
                    Text("Step Down Comfort by 50%").tag(ReduceTransparencyResponse.stepDown)
                    Text("Switch to Flat Matte").tag(ReduceTransparencyResponse.flatMatte)
                }
                .pickerStyle(.radioGroup)
            }

            Divider()
                .foregroundColor(Theme.bg2)

            // Per-Display Settings
            VStack(alignment: .leading, spacing: Theme.spacingM) {
                Text("Displays")
                    .font(Theme.monoFont(size: 12, weight: .bold))
                    .foregroundColor(Theme.fg2)
                    .tracking(0.02)

                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    ForEach(Array(NSScreen.screens.enumerated()), id: \.element) { index, screen in
                        // Key by the STABLE display ID, not the array index, so a
                        // toggle always maps to the same physical monitor even if
                        // displays are added/removed/reordered.
                        let displayID = String(screen.displayID)
                        let displaySetting = coordinator.settings.perDisplay[displayID] ?? DisplaySetting()

                        HStack {
                            Text("Display \(index + 1)")
                                .font(Theme.monoFont(size: 11))
                                .foregroundColor(Theme.fg4)

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { displaySetting.isEnabled },
                                set: { newValue in
                                    var updated = coordinator.settings
                                    var displaySettings = updated.perDisplay
                                    displaySettings[displayID] = DisplaySetting(isEnabled: newValue)
                                    updated.perDisplay = displaySettings
                                    coordinator.settings = updated
                                }
                            ))
                            .tint(Theme.green)
                        }
                    }
                }
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
    @EnvironmentObject var coordinator: AppCoordinator

    private enum Mode: Hashable { case off, manual, solar }

    private var mode: Mode {
        switch coordinator.settings.schedule {
        case .off: return .off
        case .manual: return .manual
        case .solar: return .solar
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingL) {
            Text("Schedule")
                .font(Theme.monoFont(size: 16, weight: .bold))
                .foregroundColor(Theme.fg)

            Text("Choose when the overlay is active. No location permission is required — solar mode computes sunrise and sunset from a latitude/longitude you enter.")
                .font(Theme.monoFont(size: 11))
                .foregroundColor(Theme.fg4)
                .fixedSize(horizontal: false, vertical: true)

            Picker("", selection: Binding(get: { mode }, set: { setMode($0) })) {
                Text("Always on").tag(Mode.off)
                Text("Time of day").tag(Mode.manual)
                Text("Sunrise / Sunset").tag(Mode.solar)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch coordinator.settings.schedule {
            case .off:
                Text("The overlay follows the on/off toggle only.")
                    .font(Theme.monoFont(size: 11))
                    .foregroundColor(Theme.fg4)
            case .manual:
                manualEditor
            case .solar:
                solarEditor
            }

            Spacer()
        }
    }

    // MARK: Mode switching

    private func setMode(_ newMode: Mode) {
        switch newMode {
        case .off:
            update(.off)
        case .manual:
            if case .manual = coordinator.settings.schedule { return }
            // Sensible default: on through the evening into the morning.
            update(.manual(fromHour: 20, fromMinute: 0, toHour: 7, toMinute: 0))
        case .solar:
            if case .solar = coordinator.settings.schedule { return }
            update(.solar(latitude: 37.7749, longitude: -122.4194))
        }
    }

    private func update(_ schedule: ScheduleConfig) {
        coordinator.settings.schedule = schedule
    }

    // MARK: Manual editor

    @ViewBuilder
    private var manualEditor: some View {
        if case let .manual(fromHour, fromMinute, toHour, toMinute) = coordinator.settings.schedule {
            VStack(alignment: .leading, spacing: Theme.spacingM) {
                HStack {
                    Text("On from")
                        .font(Theme.monoFont(size: 12))
                        .foregroundColor(Theme.fg2)
                        .frame(width: 70, alignment: .leading)
                    DatePicker("", selection: timeBinding(hour: fromHour, minute: fromMinute) { h, m in
                        update(.manual(fromHour: h, fromMinute: m, toHour: toHour, toMinute: toMinute))
                    }, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                }
                HStack {
                    Text("Off at")
                        .font(Theme.monoFont(size: 12))
                        .foregroundColor(Theme.fg2)
                        .frame(width: 70, alignment: .leading)
                    DatePicker("", selection: timeBinding(hour: toHour, minute: toMinute) { h, m in
                        update(.manual(fromHour: fromHour, fromMinute: fromMinute, toHour: h, toMinute: m))
                    }, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                }
                Text("Overnight windows are fine — e.g. 20:00 to 07:00.")
                    .font(Theme.monoFont(size: 10))
                    .foregroundColor(Theme.fg4)
            }
        }
    }

    private func timeBinding(hour: Int, minute: Int, set: @escaping (Int, Int) -> Void) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: max(0, min(23, hour)),
                                      minute: max(0, min(59, minute)),
                                      second: 0, of: Date()) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                set(comps.hour ?? 0, comps.minute ?? 0)
            }
        )
    }

    // MARK: Solar editor

    @ViewBuilder
    private var solarEditor: some View {
        if case let .solar(latitude, longitude) = coordinator.settings.schedule {
            VStack(alignment: .leading, spacing: Theme.spacingM) {
                HStack {
                    Text("Latitude")
                        .font(Theme.monoFont(size: 12))
                        .foregroundColor(Theme.fg2)
                        .frame(width: 80, alignment: .leading)
                    TextField("", value: Binding(
                        get: { latitude },
                        set: { update(.solar(latitude: clampLatitude($0), longitude: longitude)) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                }
                HStack {
                    Text("Longitude")
                        .font(Theme.monoFont(size: 12))
                        .foregroundColor(Theme.fg2)
                        .frame(width: 80, alignment: .leading)
                    TextField("", value: Binding(
                        get: { longitude },
                        set: { update(.solar(latitude: latitude, longitude: clampLongitude($0))) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                }
                Text("The overlay is active between sunrise and sunset for this location.")
                    .font(Theme.monoFont(size: 10))
                    .foregroundColor(Theme.fg4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func clampLatitude(_ value: Double) -> Double { max(-90, min(90, value)) }
    private func clampLongitude(_ value: Double) -> Double { max(-180, min(180, value)) }
}

// MARK: - ExclusionsTab

struct ExclusionsTab: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var bundleIDInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingL) {
            Text("Exclusions")
                .font(Theme.monoFont(size: 16, weight: .bold))
                .foregroundColor(Theme.fg)

            Text("Hide overlay when these apps are frontmost.")
                .font(Theme.monoFont(size: 11))
                .foregroundColor(Theme.fg4)
                .lineLimit(2)

            // Input section
            HStack(spacing: Theme.spacingM) {
                TextField("com.example.app", text: $bundleIDInput)
                    .font(Theme.monoFont(size: 11))
                    .textFieldStyle(.roundedBorder)
                    .padding(Theme.spacingS)
                    .background(Theme.bg1)
                    .cornerRadius(Theme.cornerRadiusSmall)

                Button(action: {
                    let trimmed = bundleIDInput.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    var updated = coordinator.settings
                    if !updated.exclusions.contains(trimmed) {
                        updated.exclusions.append(trimmed)
                        coordinator.settings = updated
                    }
                    bundleIDInput = ""
                }) {
                    Text("Add")
                        .font(Theme.monoFont(size: 11, weight: .semibold))
                        .foregroundColor(Theme.bg0)
                        .frame(minWidth: 50)
                        .padding(.vertical, Theme.spacingS)
                        .background(Theme.green)
                        .cornerRadius(Theme.cornerRadiusSmall)
                }
            }

            Divider()
                .foregroundColor(Theme.bg2)

            // List of exclusions
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                if coordinator.settings.exclusions.isEmpty {
                    Text("No exclusions. All apps show the overlay.")
                        .font(Theme.monoFont(size: 11))
                        .foregroundColor(Theme.fg4)
                        .italic()
                } else {
                    ForEach(coordinator.settings.exclusions, id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                                .font(Theme.monoFont(size: 10))
                                .foregroundColor(Theme.fg2)
                                .truncationMode(.tail)
                                .lineLimit(1)

                            Spacer()

                            Button(action: {
                                var updated = coordinator.settings
                                updated.exclusions.removeAll { $0 == bundleID }
                                coordinator.settings = updated
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.orange)
                            }
                            .buttonStyle(.plain)
                            .help("Remove exclusion")
                        }
                        .padding(Theme.spacingM)
                        .background(Theme.bg1)
                        .cornerRadius(Theme.cornerRadiusSmall)
                    }
                }
            }

            Spacer()
        }
    }
}

// MARK: - AboutTab

struct AboutTab: View {
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "0.1.0"
    }

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
                    Text(appVersion)
                        .font(Theme.monoFont(size: 11))
                        .foregroundColor(Theme.fg)
                }

                Divider()
                    .foregroundColor(Theme.bg2)

                Text("No network calls. No telemetry. No tracking.")
                    .font(Theme.monoFont(size: 11))
                    .foregroundColor(Theme.fg)
                    .lineSpacing(1.5)

                Divider()
                    .foregroundColor(Theme.bg2)

                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    Text("Credits & Licenses")
                        .font(Theme.monoFont(size: 11, weight: .semibold))
                        .foregroundColor(Theme.fg)

                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("Paperweight")
                            .font(Theme.monoFont(size: 10))
                            .foregroundColor(Theme.fg2)
                        Text("Copyright © 2026 AI-First Consulting")
                            .font(Theme.monoFont(size: 9))
                            .foregroundColor(Theme.fg4)

                        Text("JetBrains Mono")
                            .font(Theme.monoFont(size: 10))
                            .foregroundColor(Theme.fg2)
                            .padding(.top, Theme.spacingXS)
                        Text("Licensed under the OFL 1.1 License")
                            .font(Theme.monoFont(size: 9))
                            .foregroundColor(Theme.fg4)
                    }
                }
            }

            Spacer()
        }
    }
}

#Preview {
    PreferencesView()
        .environmentObject(AppCoordinator())
}
