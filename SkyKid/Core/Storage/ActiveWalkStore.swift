import Foundation
import Observation

// MARK: - ActiveWalk (GarmentCatalog extension)
// Стуктура `ActiveWalk` живёт в ActiveWalk.swift (общий файл для SkyKid +
// SkyKidWidgetExtension). `effectiveOutfitTOG` зависит от GarmentCatalog,
// которого не должно быть в виджет-таргете — поэтому вычисляется здесь,
// только в app-таргете.
extension ActiveWalk {
    /// Суммарный TOG текущего набора одежды.
    var effectiveOutfitTOG: Double? {
        let values = outfitItemIDs.compactMap { GarmentCatalog.byID[$0]?.tog }
        return values.isEmpty ? nil : values.reduce(0, +)
    }
}

// MARK: - ActiveWalkStore

/// Хранит единственную активную прогулку и синхронизирует её с AppGroup.
@MainActor
@Observable
final class ActiveWalkStore {
    static let shared = ActiveWalkStore()

    private(set) var current: ActiveWalk?

    private let defaults: UserDefaults
    private let logStore: WalkLogStore
    private let liveActivity: WalkLiveActivityController
    private let storageKey = ActiveWalkStorage.key

    init(
        defaults: UserDefaults = AppGroup.defaults,
        logStore: WalkLogStore = .shared,
        liveActivity: WalkLiveActivityController = .shared
    ) {
        self.defaults = defaults
        self.logStore = logStore
        self.liveActivity = liveActivity
        load()
        if let current {
            liveActivity.reattachIfNeeded(for: current)
        }
    }

    var isActive: Bool { current != nil }

    // MARK: - Lifecycle

    func start(_ walk: ActiveWalk) {
        current = walk
        save()
        liveActivity.start(for: walk)
    }

    func cancel() {
        current = nil
        defaults.removeObject(forKey: storageKey)
        liveActivity.end()
    }

    /// Завершает прогулку: конвертирует её в `WalkLog` (isLiveTracked) и сохраняет в журнал.
    @discardableResult
    func finish(
        comfortLevel: BabyComfortLevel = .comfortable,
        profile: ChildProfile?,
        now: Date = .now
    ) -> WalkLog? {
        guard let walk = current else { return nil }

        let minutes = max(1, Int(now.timeIntervalSince(walk.startDate) / 60.0))
        let log = WalkLog(
            date: walk.startDate,
            durationMinutes: minutes,
            outfitItemIDs: walk.outfitItemIDs,
            comfortLevel: comfortLevel,
            weatherTemperature: walk.weatherTemperature,
            apparentTemperature: walk.apparentTemperature,
            microclimateTemperature: walk.microclimateTemperature ?? walk.apparentTemperature,
            transportMode: walk.transportMode,
            activityLevel: walk.activityLevel,
            walkType: walk.walkType,
            targetTOG: walk.targetTOG,
            effectiveOutfitTOG: walk.effectiveOutfitTOG,
            events: walk.events.sorted { $0.timestamp < $1.timestamp },
            isLiveTracked: true,
            weatherCode: walk.weatherCode,
            plannedDurationMinutes: walk.plannedDurationMinutes
        )
        logStore.add(log, profile: profile)
        cancel()
        return log
    }

    // MARK: - Timeline mutations

    /// Надеть вещь: добавляет её в набор и пишет событие.
    func addGarment(_ id: String, at date: Date = .now) {
        guard var walk = current else { return }
        if !walk.outfitItemIDs.contains(id) {
            walk.outfitItemIDs.append(id)
        }
        walk.events.append(WalkEvent(timestamp: date, kind: .addedGarment, garmentID: id))
        current = walk
        save()
        liveActivity.update(for: walk, lastEvent: walk.events.last)
    }

    /// Снять вещь: убирает её из набора и пишет событие.
    func removeGarment(_ id: String, at date: Date = .now) {
        guard var walk = current else { return }
        walk.outfitItemIDs.removeAll { $0 == id }
        walk.events.append(WalkEvent(timestamp: date, kind: .removedGarment, garmentID: id))
        current = walk
        save()
        liveActivity.update(for: walk, lastEvent: walk.events.last)
    }

    /// Фиксирует событие без изменения набора одежды (люлька/сон/отметка).
    func logEvent(_ kind: WalkEventKind, note: String? = nil, at date: Date = .now) {
        guard var walk = current else { return }
        walk.events.append(WalkEvent(timestamp: date, kind: kind, note: note))
        current = walk
        save()
        liveActivity.update(for: walk, lastEvent: walk.events.last)
    }

    func removeEvent(id: UUID) {
        guard var walk = current else { return }
        walk.events.removeAll { $0.id == id }
        current = walk
        save()
        liveActivity.update(for: walk, lastEvent: walk.events.last)
    }

    /// Назначает конкретное действие ранее поставленной контрольной точке
    /// (или переклассифицирует любое другое событие), сохраняя его время.
    func reclassifyEvent(id: UUID, kind: WalkEventKind, garmentID: String?, note: String?) {
        guard var walk = current,
              let idx = walk.events.firstIndex(where: { $0.id == id })
        else { return }

        let result = WalkEventReclassifier.apply(
            old: walk.events[idx],
            newKind: kind,
            newGarmentID: garmentID,
            newNote: note,
            outfitItemIDs: walk.outfitItemIDs
        )
        walk.events[idx] = result.event
        walk.outfitItemIDs = result.outfitItemIDs
        current = walk
        save()
        let mostRecent = walk.events.max { $0.timestamp < $1.timestamp }
        liveActivity.update(for: walk, lastEvent: mostRecent)
    }

    // MARK: - Persistence

    /// Перечитывает активную прогулку из AppGroup — нужно при возврате в
    /// приложение, т.к. быстрые метки с экрана блокировки пишут события
    /// напрямую в хранилище, минуя этот процесс.
    func refresh() {
        load()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(ActiveWalk.self, from: data)
        else { return }
        current = decoded
    }

    private func save() {
        guard let walk = current,
              let data = try? JSONEncoder().encode(walk) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
