import Foundation

enum BackupMigration {
    static func decodeAndMigrate(_ data: Data) throws -> SkyKidBackup {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = object["schemaVersion"] as? Int else {
            throw BackupValidationError.corrupt
        }
        guard version <= SkyKidBackup.currentSchemaVersion else {
            throw BackupValidationError.unsupportedFutureVersion(version)
        }
        guard version >= 1 else { throw BackupValidationError.corrupt }

        let decoded: SkyKidBackup
        do {
            decoded = try JSONDecoder().decode(SkyKidBackup.self, from: data)
        } catch {
            throw BackupValidationError.corrupt
        }

        if version == SkyKidBackup.currentSchemaVersion { return decoded }
        return SkyKidBackup(
            exportedAt: decoded.exportedAt,
            profile: decoded.profile,
            walks: decoded.walks,
            personalization: decoded.personalization,
            wardrobe: decoded.wardrobe,
            settings: decoded.settings
        )
    }
}
