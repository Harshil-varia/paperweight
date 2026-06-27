import Foundation

struct Settings: Codable, Equatable {
    var schemaVersion: Int = 1
    var isEnabled: Bool = true
    var selectedProfileID: String = "eink-calm"  // Default to E-Ink Calm in Phase 2
    var comfort: Float = 0.5  // Normalized 0.0-1.0, mapped to opacityRange by profile

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case isEnabled
        case selectedProfileID
        case comfort
    }

    init(
        schemaVersion: Int = 1,
        isEnabled: Bool = true,
        selectedProfileID: String = "eink-calm",
        comfort: Float = 0.5
    ) {
        self.schemaVersion = schemaVersion
        self.isEnabled = isEnabled
        self.selectedProfileID = selectedProfileID
        self.comfort = comfort
    }

    /// Get the selected TextureProfile by ID
    var selectedProfile: TextureProfile {
        TextureProfile.preset(withID: selectedProfileID) ?? .eInkCalm
    }
}
