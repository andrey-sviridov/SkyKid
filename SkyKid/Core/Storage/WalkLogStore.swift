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
    private let nowProvider: () -> Date
    private let storageKey = "walk_logs_v1"

    init(
        defaults: UserDefaults = AppGroup.defaults,
        personalizationStore: PersonalOffsetStore = .shared,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.personalizationStore = personalizationStore
        self.nowProvider = nowProvider
        load()
    }

    // MARK: - Public API

    func add(_ log: WalkLog, profile: ChildProfile?) {
        logs.insert(log, at: 0)
        save()
        synchronizePersonalization(for: log, profile: profile)
    }

    func update(_ log: WalkLog, profile: ChildProfile?) {
        guard let index = logs.firstIndex(where: { $0.id == log.id }) else { return }
        logs[index] = log
        save()
        synchronizePersonalization(for: log, profile: profile)
    }

    func clearAll() {
        logs.forEach { personalizationStore.removeObservation(sourceID: $0.id) }
        logs = []
        save()
    }

    func replaceForRestore(with logs: [WalkLog]) {
        self.logs = logs.sorted { $0.date > $1.date }
        save()
    }

    func delete(at offsets: IndexSet) {
        let deletedIDs = offsets.compactMap { index in
            logs.indices.contains(index) ? logs[index].id : nil
        }
        logs.remove(atOffsets: offsets)
        save()
        deletedIDs.forEach { personalizationStore.removeObservation(sourceID: $0) }
    }

    func delete(id: UUID) {
        guard let index = logs.firstIndex(where: { $0.id == id }) else { return }
        delete(at: IndexSet(integer: index))
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
        // Evaluate a historical record in the walk's own temporal context;
        // editing it today must not make its original weather snapshot stale.
        guard log.personalizationEligibility(at: log.date).isEligible else {
            personalizationStore.removeObservation(sourceID: log.id)
            return
        }

        guard let profile else {
            personalizationStore.removeObservation(sourceID: log.id)
            return
        }

        guard let microclimateTemperature = log.microclimateTemperature,
              let transportMode = log.transportMode,
              let activityLevel = log.activityLevel,
              let walkType = log.walkType
        else {
            personalizationStore.removeObservation(sourceID: log.id)
            return
        }

        let context = PersonalizationContext(
            microclimateTemperature: microclimateTemperature,
            transportMode: transportMode,
            activityLevel: activityLevel,
            walkType: walkType,
            outfitItemIDs: log.outfitItemIDs,
            targetTOG: log.targetTOG,
            effectiveOutfitTOG: log.effectiveOutfitTOG,
            durationMinutes: log.durationMinutes,
            childAgeBand: PersonalizationAgeBand(ageGroup: profile.ageGroup),
            weatherCode: log.weatherCode ?? log.weatherSnapshot?.weatherCode,
            clothingAdjustment: log.clothingAdjustment
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

    private func feedback(for comfort: BabyComfortLevel) -> UserFeedback {
        switch comfort {
        case .cold: return .tooCold
        case .comfortable: return .comfortable
        case .warm, .sweating: return .tooWarm
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
