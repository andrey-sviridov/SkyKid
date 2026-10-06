import Foundation

@MainActor
final class LocalBackupService {
    enum CommitStep: CaseIterable, Sendable {
        case profile, walks, personalization, wardrobe, settings
    }

    enum RestoreError: LocalizedError {
        case confirmationRequired
        case commitFailed

        var errorDescription: String? {
            switch self {
            case .confirmationRequired: L10n.text("Подтвердите замену локальных данных")
            case .commitFailed: L10n.text("Не удалось восстановить данные; прежние данные сохранены")
            }
        }
    }

    static let shared = LocalBackupService()

    private let profileStore: ChildProfileStore
    private let walkStore: WalkLogStore
    private let personalizationStore: PersonalOffsetStore
    private let wardrobeStore: UserWardrobeStore
    private let appDefaults: UserDefaults
    private let standardDefaults: UserDefaults
    private let nowProvider: () -> Date
    private let beforeCommit: (CommitStep) throws -> Void

    init(
        profileStore: ChildProfileStore = .shared,
        walkStore: WalkLogStore = .shared,
        personalizationStore: PersonalOffsetStore = .shared,
        wardrobeStore: UserWardrobeStore = .shared,
        appDefaults: UserDefaults = AppGroup.defaults,
        standardDefaults: UserDefaults = .standard,
        nowProvider: @escaping () -> Date = Date.init,
        beforeCommit: @escaping (CommitStep) throws -> Void = { _ in }
    ) {
        self.profileStore = profileStore
        self.walkStore = walkStore
        self.personalizationStore = personalizationStore
        self.wardrobeStore = wardrobeStore
        self.appDefaults = appDefaults
        self.standardDefaults = standardDefaults
        self.nowProvider = nowProvider
        self.beforeCommit = beforeCommit
    }

    func currentBackup() -> SkyKidBackup {
        SkyKidBackup(
            exportedAt: nowProvider(),
            profile: profileStore.profile,
            walks: walkStore.logs,
            personalization: personalizationStore.exportStates(),
            wardrobe: wardrobeStore.backupState(),
            settings: BackupSettings(
                appLanguage: appDefaults.string(forKey: AppLanguagePreferences.storageKey),
                colorScheme: standardDefaults.string(forKey: "colorScheme")
            )
        )
    }

    func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(currentBackup())
    }

    func exportFileURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkyKid-backup.json")
        try exportData().write(to: url, options: .atomic)
        return url
    }

    func prepareRestore(from data: Data) throws -> SkyKidBackup {
        let backup = try BackupMigration.decodeAndMigrate(data)
        try BackupValidation.validate(backup)
        return backup
    }

    func restore(_ backup: SkyKidBackup, confirmed: Bool) throws {
        guard confirmed else { throw RestoreError.confirmationRequired }
        try BackupValidation.validate(backup)
        let rollback = currentBackup()

        do {
            try apply(backup, invokeFailureHook: true)
        } catch {
            try? apply(rollback, invokeFailureHook: false)
            throw RestoreError.commitFailed
        }
    }

    private func apply(_ backup: SkyKidBackup, invokeFailureHook: Bool) throws {
        try run(.profile, hook: invokeFailureHook) {
            profileStore.replaceForRestore(with: backup.profile)
        }
        try run(.walks, hook: invokeFailureHook) {
            walkStore.replaceForRestore(with: backup.walks)
        }
        try run(.personalization, hook: invokeFailureHook) {
            personalizationStore.replaceForRestore(with: backup.personalization)
        }
        try run(.wardrobe, hook: invokeFailureHook) {
            wardrobeStore.replaceForRestore(with: backup.wardrobe)
        }
        try run(.settings, hook: invokeFailureHook) {
            set(backup.settings.appLanguage, key: AppLanguagePreferences.storageKey, in: appDefaults)
            set(backup.settings.colorScheme, key: "colorScheme", in: standardDefaults)
        }
    }

    private func run(_ step: CommitStep, hook: Bool, operation: () -> Void) throws {
        if hook { try beforeCommit(step) }
        operation()
    }

    private func set(_ value: String?, key: String, in defaults: UserDefaults) {
        if let value { defaults.set(value, forKey: key) }
        else { defaults.removeObject(forKey: key) }
    }
}
