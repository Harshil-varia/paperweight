import Foundation

struct Settings: Codable, Equatable {
    var schemaVersion: Int = 1
    var isEnabled: Bool = true
    var selectedProfileID: String = "classic-matte"
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
        selectedProfileID: String = "classic-matte",
        comfort: Float = 0.5
    ) {
        self.schemaVersion = schemaVersion
        self.isEnabled = isEnabled
        self.selectedProfileID = selectedProfileID
        self.comfort = comfort
    }
}
