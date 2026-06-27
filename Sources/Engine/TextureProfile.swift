import Foundation

// MARK: - TextureProfile

/// A complete noise texture configuration including noise type, blend, and comfort settings
struct TextureProfile: Codable, Equatable {
    var id: String
    var name: String
    var noiseType: NoiseType
    var tint: Float  // 0.0-1.0, where 0.0 is neutral gray and 1.0 is a warm tint
    var matteLift: Float  // 0.0-1.0, how much to brighten the darkest values
    var blendMode: BlendMode
    var opacityRange: OpacityRange  // The band the comfort slider maps into
    var tileSize: Int  // 256, 512, or 1024
    var seed: UInt32

    init(
        id: String,
        name: String,
        noiseType: NoiseType,
        tint: Float,
        matteLift: Float,
        blendMode: BlendMode,
        opacityRange: OpacityRange,
        tileSize: Int,
        seed: UInt32
    ) {
        self.id = id
        self.name = name
        self.noiseType = noiseType
        self.tint = max(0.0, min(1.0, tint))
        self.matteLift = max(0.0, min(1.0, matteLift))
        self.blendMode = blendMode
        self.opacityRange = opacityRange
        self.tileSize = tileSize
        self.seed = seed
    }

    /// Content hash for cache keying: combines profile config and scale factor
    func contentHash(scale: CGFloat) -> String {
        let hashInput = "\(id):\(noiseType):\(tint):\(matteLift):\(blendMode):\(tileSize):\(seed):\(scale)"
        return hashInput.hashValue.description
    }
}

// MARK: - NoiseType

enum NoiseType: String, Codable, Equatable {
    case white      // Pure white noise
    case value      // Value noise / Voronoi with value
    case perlin     // Perlin noise
    case simplex    // Simplex noise
    case fbm        // Fractional Brownian Motion
    case ridged     // Ridged multifractal
    case worley     // Worley/Cellular noise

    var requiresOctaves: Bool {
        self == .fbm || self == .ridged
    }

    /// Stable code for deterministic shader mapping (independent of String.hashValue)
    var stableCode: UInt32 {
        switch self {
        case .white: return 0
        case .value: return 1
        case .perlin: return 2
        case .simplex: return 3
        case .fbm: return 4
        case .ridged: return 5
        case .worley: return 6
        }
    }
}

// MARK: - BlendMode

enum BlendMode: String, Codable, Equatable {
    case softLight     // CISoftLightBlendMode
    case multiply      // CIMultiplyBlendMode
    case screen        // CIScreenBlendMode
    case overlay       // CIOverlayBlendMode
}

// MARK: - OpacityRange

/// The band that the comfort slider (0.0-1.0) maps into for this profile
struct OpacityRange: Codable, Equatable {
    var minOpacity: Float
    var maxOpacity: Float

    init(_ minOpacity: Float, _ maxOpacity: Float) {
        self.minOpacity = Swift.max(0.0, minOpacity)
        self.maxOpacity = Swift.min(1.0, maxOpacity)
    }

    /// Map a comfort value (0.0-1.0) to the opacity band
    func clamp(_ comfort: Float) -> Float {
        let clamped = Swift.max(0.0, Swift.min(1.0, comfort))
        return minOpacity + (clamped * (maxOpacity - minOpacity))
    }
}

// MARK: - Preset Library

extension TextureProfile {
    // MARK: - Comfort Row (Functional Presets)

    /// E-Ink Calm: minimal grain, no weave, neutral #F2F1EC, lift 0.12, Soft light, 0.20 (ours, DEFAULT)
    static let eInkCalm = TextureProfile(
        id: "eink-calm",
        name: "E-Ink Calm",
        noiseType: .white,
        tint: 0.0,
        matteLift: 0.12,
        blendMode: .softLight,
        opacityRange: OpacityRange(0.15, 0.25),
        tileSize: 256,
        seed: 128
    )

    /// Classic Matte: fBm (mid octaves), no weave, neutral faint-warm tint, lift 0.06, Soft light, 0.18
    static let classicMatte = TextureProfile(
        id: "classic-matte",
        name: "Classic Matte",
        noiseType: .fbm,
        tint: 0.01,
        matteLift: 0.06,
        blendMode: .softLight,
        opacityRange: OpacityRange(0.15, 0.21),
        tileSize: 512,
        seed: 42
    )

    /// Vellum Mist: fBm (low octaves), no weave, warm haze #F6F4EF, lift 0.05, Soft light, 0.12
    static let vellumMist = TextureProfile(
        id: "vellum-mist",
        name: "Vellum Mist",
        noiseType: .fbm,
        tint: 0.02,
        matteLift: 0.05,
        blendMode: .softLight,
        opacityRange: OpacityRange(0.10, 0.14),
        tileSize: 256,
        seed: 256
    )

    /// Blueprint: value + faint grid, cool cyan #DCE6EC, lift 0.05, Overlay, 0.16 (ours)
    static let blueprint = TextureProfile(
        id: "blueprint",
        name: "Blueprint",
        noiseType: .value,
        tint: -0.10,
        matteLift: 0.05,
        blendMode: .overlay,
        opacityRange: OpacityRange(0.12, 0.20),
        tileSize: 512,
        seed: 512
    )

    // MARK: - Character Row (Decorative Presets)

    /// Whisper Weave: value + fine grain, HIGH fine weave/anisotropy, cool neutral #F4F4F2, lift 0.05, Soft light, 0.16
    static let whisperWeave = TextureProfile(
        id: "whisper-weave",
        name: "Whisper Weave",
        noiseType: .value,
        tint: -0.01,
        matteLift: 0.05,
        blendMode: .softLight,
        opacityRange: OpacityRange(0.13, 0.19),
        tileSize: 256,
        seed: 1001
    )

    /// Sunbaked Parchment: fBm (heavy grain), no weave, amber #E8C893, lift 0.08, Multiply, 0.22
    static let sunbakedParchment = TextureProfile(
        id: "sunbaked-parchment",
        name: "Sunbaked Parchment",
        noiseType: .fbm,
        tint: 0.15,
        matteLift: 0.08,
        blendMode: .multiply,
        opacityRange: OpacityRange(0.18, 0.26),
        tileSize: 512,
        seed: 1002
    )

    /// Saddle Linen: value, coarse linen weave, earthy #C7A26A, lift 0.07, Overlay, 0.20
    static let saddleLinen = TextureProfile(
        id: "saddle-linen",
        name: "Saddle Linen",
        noiseType: .value,
        tint: 0.12,
        matteLift: 0.07,
        blendMode: .overlay,
        opacityRange: OpacityRange(0.16, 0.24),
        tileSize: 512,
        seed: 1003
    )

    /// Painter's Press: worley + value tooth, no weave, cool paper #EDEBE6, lift 0.06, Soft light, 0.18
    static let paintersPress = TextureProfile(
        id: "painters-press",
        name: "Painter's Press",
        noiseType: .worley,
        tint: -0.01,
        matteLift: 0.06,
        blendMode: .softLight,
        opacityRange: OpacityRange(0.15, 0.21),
        tileSize: 512,
        seed: 1004
    )

    /// Mulberry Veil: perlin (sparse), no weave, plum #6E4A6B, lift 0.04, Screen, 0.14
    static let mulberryVeil = TextureProfile(
        id: "mulberry-veil",
        name: "Mulberry Veil",
        noiseType: .perlin,
        tint: -0.05,
        matteLift: 0.04,
        blendMode: .screen,
        opacityRange: OpacityRange(0.11, 0.17),
        tileSize: 256,
        seed: 1005
    )

    /// Monastic Felt: worley (dense), no weave, muted warm #B7AE9E, lift 0.07, Multiply, 0.18
    static let monasticFelt = TextureProfile(
        id: "monastic-felt",
        name: "Monastic Felt",
        noiseType: .worley,
        tint: 0.05,
        matteLift: 0.07,
        blendMode: .multiply,
        opacityRange: OpacityRange(0.15, 0.21),
        tileSize: 512,
        seed: 1006
    )

    /// Carbon Ledger: value (fine) + faint horizontal ruling, graphite #8A8F98, lift 0.05, Overlay, 0.16
    static let carbonLedger = TextureProfile(
        id: "carbon-ledger",
        name: "Carbon Ledger",
        noiseType: .value,
        tint: -0.02,
        matteLift: 0.05,
        blendMode: .overlay,
        opacityRange: OpacityRange(0.13, 0.19),
        tileSize: 256,
        seed: 1007
    )

    /// Riso Grain: white (coarse), no weave, faint duotone, lift 0.06, Multiply, 0.18 (ours)
    static let risoGrain = TextureProfile(
        id: "riso-grain",
        name: "Riso Grain",
        noiseType: .white,
        tint: 0.03,
        matteLift: 0.06,
        blendMode: .multiply,
        opacityRange: OpacityRange(0.15, 0.21),
        tileSize: 512,
        seed: 1008
    )

    // MARK: - Library Access

    /// All 12 presets organized by category: Comfort row leading with E-Ink Calm (default)
    static let allPresets: [[TextureProfile]] = [
        // Comfort row (4 presets)
        [eInkCalm, classicMatte, vellumMist, blueprint],
        // Character row (8 presets)
        [whisperWeave, sunbakedParchment, saddleLinen, paintersPress, mulberryVeil, monasticFelt, carbonLedger, risoGrain]
    ]

    /// Flat list of all 12 presets for easy lookup
    static let flatPresets = [
        eInkCalm, classicMatte, vellumMist, blueprint,
        whisperWeave, sunbakedParchment, saddleLinen, paintersPress,
        mulberryVeil, monasticFelt, carbonLedger, risoGrain
    ]

    /// Find a preset by ID
    static func preset(withID id: String) -> TextureProfile? {
        flatPresets.first { $0.id == id }
    }
}
