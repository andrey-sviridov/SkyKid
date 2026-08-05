import Foundation
import Observation

// MARK: - WalkLogStore

/// Persists walk logs and keeps their personalization observations in sync.
@MainActor
@Observable
final class WalkLogStore {
    static let shared = WalkLogStore()

    private(set) var logs: [WalkLog] = []

    private let defaults: UserDefaults
    private let personalizationStore: PersonalOffsetStore
    private let syncService: SupabaseSyncService
    private let storageKey = "walk_logs_v1"

    init(
        defaults: UserDefaults = AppGroup.defaults,
        personalizationStore: PersonalOffsetStore = .shared,
        syncService: SupabaseSyncService = .shared
    ) {
        self.defaults = defaults
        self.personalizationStore = personalizationStore
        self.syncService = syncService
        load()
    }

    // MARK: - Public API

    func add(_ log: WalkLog, profile: ChildProfile?) {
        logs.insert(log, at: 0)
        save()
        synchronizePersonalization(for: log, profile: profile)
        Task { await syncService.pushWalkLog(log) }
    }

    func update(_ log: WalkLog, profile: ChildProfile?) {
        guard let index = logs.firstIndex(where: { $0.id == log.id }) else { return }
        logs[index] = log
        save()
        synchronizePersonalization(for: log, profile: profile)
        Task { await syncService.pushWalkLog(log) }
    }

    /// Стирает локальный журнал прогулок без каскадного удаления на
    /// сервере — вызывается при выходе из аккаунта
    /// (`SupabaseAuthService.signOut()`), где записи принадлежат уже
    /// отвязываемому пользователю. Не должно триггерить `deleteWalkLogRemote`:
    /// сами данные на сервере ещё принадлежат этому аккаунту и должны
    /// остаться доступны, если пользователь снова войдёт на этом или другом
    /// устройстве — стираем только локальный кеш, чтобы следующий
    /// `ContentView.syncOnLaunch()` не запушил их под чужим `auth.uid()`.
    func clearAll() {
        logs.forEach { personalizationStore.removeObservation(sourceID: $0.id) }
        logs = []
        save()
    }

    func delete(at offsets: IndexSet) {
        let deletedIDs = offsets.compactMap { index in
            logs.indices.contains(index) ? logs[index].id : nil
        }
        logs.remove(atOffsets: offsets)
        save()
        deletedIDs.forEach { personalizationStore.removeObservation(sourceID: $0) }
        for id in deletedIDs {
            Task { await syncService.deleteWalkLogRemote(id: id) }
        }
    }

    // MARK: - Stats

    var totalCount: Int { logs.count }

    var recentCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return logs.filter { $0.date >= cutoff }.count
    }

    // MARK: - Personalization

    private func synchronizePersonalization(
        for log: WalkLog,
        profile: ChildProfile?
    ) {
        guard let profile else {
            personalizationStore.removeObservation(sourceID: log.id)
            return
        }

        let defaults = WalkContext.standard(
            for: profile.thermalProfile,
            availableGarmentIDs: Set(log.outfitItemIDs)
        )
        let context = PersonalizationContext(
            microclimateTemperature: log.microclimateTemperature ?? log.apparentTemperature,
            transportMode: log.transportMode ?? defaults.transportMode,
            activityLevel: log.activityLevel ?? defaults.activityLevel,
            walkType: log.walkType ?? .regular,
            outfitItemIDs: log.outfitItemIDs,
            targetTOG: log.targetTOG,
            effectiveOutfitTOG: log.effectiveOutfitTOG,
            durationMinutes: log.durationMinutes
        )

        personalizationStore.removeObservation(sourceID: log.id)
        personalizationStore.record(
            feedback(for: log.comfortLevel),
            for: profile,
            context: context,
            sourceID: log.id,
            source: .walkLog,
            recordedAt: log.date
        )
    }

    private func feedback(for comfortLevel: BabyComfortLevel) -> UserFeedback {
        switch comfortLevel {
        case .cold:             return .tooCold
        case .comfortable:      return .comfortable
        case .warm, .sweating:  return .tooWarm
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([WalkLog].self, from: data)
        else { return }
        logs = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(logs) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
