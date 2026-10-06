import Foundation

struct SkyKidBackup: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    let exportedAt: Date
    let profile: ChildProfile?
    let walks: [WalkLog]
    let personalization: [String: PersonalizationProfileState]
    let wardrobe: WardrobeBackup
    let settings: BackupSettings

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        exportedAt: Date,
        profile: ChildProfile?,
        walks: [WalkLog],
        personalization: [String: PersonalizationProfileState],
        wardrobe: WardrobeBackup,
        settings: BackupSettings = .init()
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.profile = profile
        self.walks = walks
        self.personalization = personalization
        self.wardrobe = wardrobe
        self.settings = settings
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, exportedAt, profile, walks, personalization, wardrobe, settings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        profile = try container.decodeIfPresent(ChildProfile.self, forKey: .profile)
        walks = try container.decodeIfPresent([WalkLog].self, forKey: .walks) ?? []
        personalization = try container.decodeIfPresent(
            [String: PersonalizationProfileState].self,
            forKey: .personalization
        ) ?? [:]
        wardrobe = try container.decodeIfPresent(WardrobeBackup.self, forKey: .wardrobe)
            ?? WardrobeBackup(confirmedOwnedIDs: [], unavailableIDs: [])
        settings = try container.decodeIfPresent(BackupSettings.self, forKey: .settings) ?? .init()
    }
}

struct WardrobeBackup: Codable, Equatable, Sendable {
    let confirmedOwnedIDs: Set<String>
    let unavailableIDs: Set<String>

    private enum CodingKeys: String, CodingKey {
        case confirmedOwnedIDs, unavailableIDs
    }

    init(confirmedOwnedIDs: Set<String>, unavailableIDs: Set<String>) {
        self.confirmedOwnedIDs = confirmedOwnedIDs
        self.unavailableIDs = unavailableIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        confirmedOwnedIDs = try container.decodeIfPresent(Set<String>.self, forKey: .confirmedOwnedIDs) ?? []
        unavailableIDs = try container.decodeIfPresent(Set<String>.self, forKey: .unavailableIDs) ?? []
    }
}

struct BackupSettings: Codable, Equatable, Sendable {
    let appLanguage: String?
    let colorScheme: String?

    init(appLanguage: String? = nil, colorScheme: String? = nil) {
        self.appLanguage = appLanguage
        self.colorScheme = colorScheme
    }
}
