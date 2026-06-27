import SwiftUI

#if DEBUG

/// Debug-only Lab panel for live texture tuning
struct LabPanelContent: View {
    @EnvironmentObject var coordinator: AppCoordinator
    let profile: TextureProfile

    @State private var noiseTypeIndex: Int = 0
    @State private var tint: Float = 0.0
    @State private var matteLift: Float = 0.15
    @State private var seed: Float = 42.0

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingM) {
            Text("Lab (Debug)")
                .font(Theme.monoFont(size: 12, weight: .bold))
                .foregroundColor(Theme.orange)
                .tracking(0.02)

            // Noise Type Picker
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                Text("Noise Type:")
                    .font(Theme.monoFont(size: 11))
                    .foregroundColor(Theme.fg4)

                Picker("", selection: $noiseTypeIndex) {
                    Text("White").tag(0)
                    Text("Value").tag(1)
                    Text("Perlin").tag(2)
                    Text("Simplex").tag(3)
                    Text("fBm").tag(4)
                    Text("Ridged").tag(5)
                    Text("Worley").tag(6)
                }
                .pickerStyle(.segmented)
                .font(Theme.monoFont(size: 10))
            }

            // Tint slider
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                HStack {
                    Text("Tint:")
                        .font(Theme.monoFont(size: 11))
                        .foregroundColor(Theme.fg4)

                    Spacer()

                    Text(String(format: "%.2f", tint))
                        .font(Theme.monoFont(size: 10))
                        .foregroundColor(Theme.yellow)
                }

                Slider(value: $tint, in: -0.5 ... 0.5, step: 0.01)
                    .tint(Theme.yellow)
            }

            // Matte Lift slider
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                HStack {
                    Text("Matte Lift:")
                        .font(Theme.monoFont(size: 11))
                        .foregroundColor(Theme.fg4)

                    Spacer()

                    Text(String(format: "%.2f", matteLift))
                        .font(Theme.monoFont(size: 10))
                        .foregroundColor(Theme.yellow)
                }

                Slider(value: $matteLift, in: 0.0 ... 1.0, step: 0.01)
                    .tint(Theme.yellow)
            }

            // Seed slider
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                HStack {
                    Text("Seed:")
                        .font(Theme.monoFont(size: 11))
                        .foregroundColor(Theme.fg4)

                    Spacer()

                    Text(String(format: "%.0f", seed))
                        .font(Theme.monoFont(size: 10))
                        .foregroundColor(Theme.yellow)
                }

                Slider(value: $seed, in: 0.0 ... 4096.0, step: 1.0)
                    .tint(Theme.yellow)
            }

            HStack(spacing: Theme.spacingS) {
                Button("Reset") {
                    noiseTypeIndex = 1
                    tint = 0.0
                    matteLift = 0.15
                    seed = 42.0
                }
                .gruvboxButton()
                .font(Theme.monoFont(size: 10))

                Button("Apply") {
                    // Create new profile and apply
                    let noiseTypes: [NoiseType] = [.white, .value, .perlin, .simplex, .fbm, .ridged, .worley]
                    let newProfile = TextureProfile(
                        id: "lab-test-\(Date().timeIntervalSince1970)",
                        name: "Lab Test",
                        noiseType: noiseTypes[min(noiseTypeIndex, 6)],
                        tint: tint,
                        matteLift: matteLift,
                        blendMode: profile.blendMode,
                        opacityRange: profile.opacityRange,
                        tileSize: profile.tileSize,
                        seed: UInt32(seed)
                    )
                    coordinator.settings.selectedProfileID = newProfile.id
                }
                .gruvboxButton()
                .font(Theme.monoFont(size: 10))
            }
        }
        .padding(Theme.spacingM)
        .background(Theme.bg1)
        .border(Theme.bg2, width: 0.5)
        .cornerRadius(Theme.cornerRadiusSmall)
        .onAppear {
            noiseTypeIndex = Int(profile.noiseType.stableCode)
            tint = profile.tint
            matteLift = profile.matteLift
            seed = Float(profile.seed)
        }
    }
}

#endif
