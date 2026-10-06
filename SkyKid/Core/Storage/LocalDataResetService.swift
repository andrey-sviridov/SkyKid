import Foundation

@MainActor
final class LocalDataResetService {
    enum Step: CaseIterable, Sendable {
        case activeWalk, walks, personalization, wardrobe, recommendation, profile, runtime, settings
    }

    enum ResetError: LocalizedError {
        case confirmationRequired
        case resetFailed

        var errorDescription: String? {
            switch self {
            case .confirmationRequired: L10n.text("Подтвердите удаление локальных данных")
            case .resetFailed: L10n.text("Не удалось удалить все данные; прежнее состояние восстановлено")
            }
        }
    }

    static let shared = LocalDataResetService()

    private let profileStore: ChildProfileStore
    private let walkStore: WalkLogStore
    private let activeWalkStore: ActiveWalkStore
    private let personalizationStore: PersonalOffsetStore
    private let wardrobeStore: UserWardrobeStore
    private let recommendationStore: any RecommendationSnapshotStoring
    private let walkContextStore: WalkContextStore
    private let backupService: LocalBackupService
    private let defaults: UserDefaults
    private let beforeStep: (Step) throws -> Void

    init(
        profileStore: ChildProfileStore = .shared,
        walkStore: WalkLogStore = .shared,
        activeWalkStore: ActiveWalkStore = .shared,
        personalizationStore: PersonalOffsetStore = .shared,
        wardrobeStore: UserWardrobeStore = .shared,
        recommendationStore: any RecommendationSnapshotStoring = AppGroupRecommendationSnapshotStore(),
        walkContextStore: WalkContextStore = .shared,
        backupService: LocalBackupService = .shared,
        defaults: UserDefaults = AppGroup.defaults,
        beforeStep: @escaping (Step) throws -> Void = { _ in }
    ) {
        self.profileStore = profileStore
        self.walkStore = walkStore
        self.activeWalkStore = activeWalkStore
        self.personalizationStore = personalizationStore
        self.wardrobeStore = wardrobeStore
        self.recommendationStore = recommendationStore
        self.walkContextStore = walkContextStore
        self.backupService = backupService
        self.defaults = defaults
        self.beforeStep = beforeStep
    }

    func reset(confirmed: Bool) throws {
        guard confirmed else { throw ResetError.confirmationRequired }
        let backup = backupService.currentBackup()
        let activeWalk = activeWalkStore.current
        let context = walkContextStore.context
        let recommendation = recommendationStore.load()
        let rawValues = Dictionary(uniqueKeysWithValues: Self.runtimeKeys.compactMap { key in
            defaults.object(forKey: key).map { (key, $0) }
        })

        do {
            try performReset()
        } catch {
            try? backupService.restore(backup, confirmed: true)
            activeWalkStore.replaceForRollback(with: activeWalk)
            walkContextStore.replaceForRollback(with: context)
            if let recommendation { recommendationStore.save(recommendation) }
            for (key, value) in rawValues { defaults.set(value, forKey: key) }
            throw ResetError.resetFailed
        }
    }

    private func performReset() throws {
        try step(.activeWalk) { activeWalkStore.cancel() }
        try step(.walks) { walkStore.clearAll() }
        try step(.personalization) { personalizationStore.clearAll() }
        try step(.wardrobe) { wardrobeStore.clearAll() }
        try step(.recommendation) { recommendationStore.clear() }
        try step(.profile) { profileStore.replaceForRestore(with: nil) }
        try step(.runtime) { walkContextStore.clear() }
        try step(.settings) {
            for key in Self.runtimeKeys { defaults.removeObject(forKey: key) }
        }
    }

    private func step(_ value: Step, operation: () -> Void) throws {
        try beforeStep(value)
        operation()
    }

    /// Language and appearance are intentionally preserved. These keys are
    /// personal/runtime data: weather/location cache, location choice,
    /// reminders, provider selection and provider credentials.
    static let runtimeKeys = [
        "wg_temperature", "wg_apparent_temp", "wg_weather_code", "wg_wind_speed",
        "wg_precipitation", "wg_city_name", "wg_updated_at", "wg_latitude", "wg_longitude",
        "location_selection_v1", "notifications_enabled", "walk_schedule_v1",
        "weatherProvider", "owmApiKey", "wapiApiKey", "yandexApiKey",
    ]
}
