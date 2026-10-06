import Foundation

enum BackupValidationError: LocalizedError, Equatable {
    case corrupt
    case unsupportedFutureVersion(Int)
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .corrupt:
            L10n.text("Файл резервной копии повреждён или обрезан")
        case let .unsupportedFutureVersion(version):
            L10n.format("Эта копия создана более новой версией SkyKid (схема %lld)", version)
        case let .invalid(reason):
            L10n.format("Резервная копия не прошла проверку: %@", reason)
        }
    }
}

enum BackupValidation {
    static func validate(_ backup: SkyKidBackup) throws {
        guard backup.schemaVersion == SkyKidBackup.currentSchemaVersion else {
            throw BackupValidationError.invalid("schemaVersion")
        }
        guard backup.walks.count <= 10_000 else {
            throw BackupValidationError.invalid("walks")
        }
        guard Set(backup.walks.map(\.id)).count == backup.walks.count else {
            throw BackupValidationError.invalid("duplicate walk IDs")
        }
        let catalogIDs = Set(GarmentCatalog.all.map(\.id))
        guard backup.wardrobe.confirmedOwnedIDs.isSubset(of: catalogIDs),
              backup.wardrobe.unavailableIDs.isSubset(of: catalogIDs),
              backup.wardrobe.confirmedOwnedIDs.isDisjoint(with: backup.wardrobe.unavailableIDs)
        else {
            throw BackupValidationError.invalid("wardrobe")
        }
        guard backup.personalization.values.allSatisfy({ $0.observations.count <= 10_000 }) else {
            throw BackupValidationError.invalid("personalization")
        }
    }
}
