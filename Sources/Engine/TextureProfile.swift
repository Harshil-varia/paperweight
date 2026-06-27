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
    case fbm        // Fractional Brownian Motion
    case ridged     // Ridged multifractal

    var requiresOctaves: Bool {
        self == .fbm || self == .ridged
    }

    /// Stable code for deterministic shader mapping (independent of String.hashValue)
    var stableCode: UInt32 {
        switch self {
        case .white: return 0
        case .value: return 1
        case .perlin: return 2
        case .fbm: return 3
        case .ridged: return 4
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
    /// Classic Matte: minimal grain, neutral tint, soft comfort band
    static let classicMatte = TextureProfile(
        id: "classic-matte",
        name: "Classic Matte",
        noiseType: .value,
        tint: 0.0,
        matteLift: 0.15,
        blendMode: .softLight,
        opacityRange: OpacityRange(0.15, 0.30),
        tileSize: 512,
        seed: 42
    )

    /// E-Ink Calm: nearly invisible grain, no tint, gentle lift, maximum comfort (default)
    static let eInkCalm = TextureProfile(
        id: "eink-calm",
        name: "E-Ink Calm",
        noiseType: .white,
        tint: 0.0,
        matteLift: 0.10,
        blendMode: .softLight,
        opacityRange: OpacityRange(0.12, 0.25),
        tileSize: 256,
        seed: 128
    )
}
