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

struct Settings: Codable, Equatable {
    var schemaVersion: Int = 2
    var isEnabled: Bool = true
    var selectedProfileID: String = "eink-calm"  // Default to E-Ink Calm in Phase 2
    var comfort: Float = 0.5  // Normalized 0.0-1.0, mapped to opacityRange by profile
    var schedule: ScheduleConfig = .off

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case isEnabled
        case selectedProfileID
        case comfort
        case schedule
    }

    init(
        schemaVersion: Int = 2,
        isEnabled: Bool = true,
        selectedProfileID: String = "eink-calm",
        comfort: Float = 0.5,
        schedule: ScheduleConfig = .off
    ) {
        self.schemaVersion = schemaVersion
        self.isEnabled = isEnabled
        self.selectedProfileID = selectedProfileID
        self.comfort = comfort
        self.schedule = schedule
    }

    /// Get the selected TextureProfile by ID
    var selectedProfile: TextureProfile {
        TextureProfile.preset(withID: selectedProfileID) ?? .eInkCalm
    }
}
