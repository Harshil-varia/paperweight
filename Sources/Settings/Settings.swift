import Foundation

/// Configuration for overlay scheduling
enum ScheduleConfig: Codable, Equatable {
    /// Schedule is off; overlay visibility is solely controlled by isEnabled
    case off
    /// Manual schedule with fixed times (from hour:minute, to hour:minute, using 24-hour format)
    case manual(fromHour: Int, fromMinute: Int, toHour: Int, toMinute: Int)
    /// Solar schedule: compute sunrise/sunset from latitude/longitude
    case solar(latitude: Double, longitude: Double)

    enum CodingKeys: String, CodingKey {
        case type
        case fromHour
        case fromMinute
        case toHour
        case toMinute
        case latitude
        case longitude
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .off:
            try container.encode("off", forKey: .type)
        case let .manual(fh, fm, th, tm):
            try container.encode("manual", forKey: .type)
            try container.encode(fh, forKey: .fromHour)
            try container.encode(fm, forKey: .fromMinute)
            try container.encode(th, forKey: .toHour)
            try container.encode(tm, forKey: .toMinute)
        case let .solar(lat, long):
            try container.encode("solar", forKey: .type)
            try container.encode(lat, forKey: .latitude)
            try container.encode(long, forKey: .longitude)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "off":
            self = .off
        case "manual":
            let fh = try container.decode(Int.self, forKey: .fromHour)
            let fm = try container.decode(Int.self, forKey: .fromMinute)
            let th = try container.decode(Int.self, forKey: .toHour)
            let tm = try container.decode(Int.self, forKey: .toMinute)
            self = .manual(fromHour: fh, fromMinute: fm, toHour: th, toMinute: tm)
        case "solar":
            let lat = try container.decode(Double.self, forKey: .latitude)
            let long = try container.decode(Double.self, forKey: .longitude)
            self = .solar(latitude: lat, longitude: long)
        default:
            self = .off
        }
    }
}

/// How to respond to Reduce Transparency setting
enum ReduceTransparencyResponse: String, Codable, Equatable {
    /// Step down comfort by 50% when Reduce Transparency is on
    case stepDown = "step-down"
    /// Switch to flat matte when Reduce Transparency is on
    case flatMatte = "flat-matte"
}

/// Per-display overlay control
struct DisplaySetting: Codable, Equatable {
    /// Whether the overlay is enabled on this display
    var isEnabled: Bool = true
}

/// Type alias for display identifiers (screen index or UUID)
typealias DisplayID = String

struct Settings: Codable, Equatable {
    var schemaVersion: Int = 3
    var isEnabled: Bool = true
    var selectedProfileID: String = "eink-calm"  // Default to E-Ink Calm in Phase 2
    var comfort: Float = 0.5  // Normalized 0.0-1.0, mapped to opacityRange by profile
    var schedule: ScheduleConfig = .off

    // Phase 5: Ambient inputs
    /// List of bundle IDs to exclude (hide overlay when frontmost)
    var exclusions: [String] = []
    /// Whether to pause overlay when on battery
    var pauseOnBattery: Bool = false
    /// Whether app should launch at login
    var launchAtLogin: Bool = false
    /// How to respond to Reduce Transparency accessibility setting
    var reduceTransparencyResponse: ReduceTransparencyResponse = .stepDown
    /// Per-display visibility control; maps display identifier to per-display settings
    var perDisplay: [DisplayID: DisplaySetting] = [:]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case isEnabled
        case selectedProfileID
        case comfort
        case schedule
        case exclusions
        case pauseOnBattery
        case launchAtLogin
        case reduceTransparencyResponse
        case perDisplay
    }

    init(
        schemaVersion: Int = 3,
        isEnabled: Bool = true,
        selectedProfileID: String = "eink-calm",
        comfort: Float = 0.5,
        schedule: ScheduleConfig = .off,
        exclusions: [String] = [],
        pauseOnBattery: Bool = false,
        launchAtLogin: Bool = false,
        reduceTransparencyResponse: ReduceTransparencyResponse = .stepDown,
        perDisplay: [DisplayID: DisplaySetting] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.isEnabled = isEnabled
        self.selectedProfileID = selectedProfileID
        self.comfort = comfort
        self.schedule = schedule
        self.exclusions = exclusions
        self.pauseOnBattery = pauseOnBattery
        self.launchAtLogin = launchAtLogin
        self.reduceTransparencyResponse = reduceTransparencyResponse
        self.perDisplay = perDisplay
    }

    /// Get the selected TextureProfile by ID
    var selectedProfile: TextureProfile {
        TextureProfile.preset(withID: selectedProfileID) ?? .eInkCalm
    }
}
