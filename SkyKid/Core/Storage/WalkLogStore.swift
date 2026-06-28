import Foundation
import Observation

// Persists walk logs and applies feedback to PersonalOffsetStore (§8).
// Key: "walk_logs_v1" in AppGroup.

@MainActor
@Observable
final class WalkLogStore {

    static let shared = WalkLogStore()

    private(set) var logs: [WalkLog] = []
    private let storageKey = "walk_logs_v1"

    init() { load() }

    // MARK: - Public API

    func add(_ log: WalkLog, profile: ChildProfile?) {
        logs.insert(log, at: 0)
        save()
        if let profile {
            let feedback: UserFeedback
            switch log.comfortLevel {
            case .cold:                  feedback = .tooCold
            case .comfortable:           feedback = .comfortable
            case .warm, .sweating:       feedback = .tooWarm
            }
            PersonalOffsetStore.shared.record(feedback, for: profile, tMicro: log.apparentTemperature)
        }
    }

    func update(_ log: WalkLog) {
        guard let idx = logs.firstIndex(where: { $0.id == log.id }) else { return }
        logs[idx] = log
        save()
    }

    func delete(at offsets: IndexSet) {
        logs.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Stats

    var totalCount: Int { logs.count }

    var recentCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return logs.filter { $0.date >= cutoff }.count
    }

    // MARK: - Persistence

    private func load() {
        guard let data = AppGroup.defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([WalkLog].self, from: data)
        else { return }
        logs = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(logs) else { return }
        AppGroup.defaults.set(data, forKey: storageKey)
    }
}
