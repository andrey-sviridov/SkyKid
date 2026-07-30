import Foundation
import Observation

// MARK: - ActiveWalk

/// Прогулка, идущая прямо сейчас. Персистится целиком, чтобы пережить
/// перезапуск/выгрузку приложения (таймер восстанавливается из `startDate`).
struct ActiveWalk: Codable, Identifiable, Hashable {
    var id: UUID
    var startDate: Date
    var plannedDurationMinutes: Int?

    // Снапшот погоды на момент старта.
    var weatherTemperature: Double
    var apparentTemperature: Double
    var microclimateTemperature: Double?
    var weatherCode: Int?
    /// Снимок иконки/описания погоды на старте — для Live Activity (виджет-таргет
    /// не должен зависеть от WeatherData/PrecipType, поэтому передаём готовые строки).
    var weatherIconSymbol: String?
    var weatherDescription: String?

    // Контекст прогулки (для персонализации при завершении).
    var transportMode: TransportMode?
    var activityLevel: BabyActivityLevel?
    var walkType: WalkType?
    var targetTOG: Double?

    // Текущий набор одежды и таймлайн событий.
    var outfitItemIDs: [String]
    var events: [WalkEvent]

    init(
        id: UUID = UUID(),
        startDate: Date = .now,
        plannedDurationMinutes: Int? = nil,
        weatherTemperature: Double,
        apparentTemperature: Double,
        microclimateTemperature: Double? = nil,
        weatherCode: Int? = nil,
        weatherIconSymbol: String? = nil,
        weatherDescription: String? = nil,
        transportMode: TransportMode? = nil,
        activityLevel: BabyActivityLevel? = nil,
        walkType: WalkType? = nil,
        targetTOG: Double? = nil,
        outfitItemIDs: [String] = [],
        events: [WalkEvent] = []
    ) {
        self.id = id
        self.startDate = startDate
        self.plannedDurationMinutes = plannedDurationMinutes
        self.weatherTemperature = weatherTemperature
        self.apparentTemperature = apparentTemperature
        self.microclimateTemperature = microclimateTemperature
        self.weatherCode = weatherCode
        self.weatherIconSymbol = weatherIconSymbol
        self.weatherDescription = weatherDescription
        self.transportMode = transportMode
        self.activityLevel = activityLevel
        self.walkType = walkType
        self.targetTOG = targetTOG
        self.outfitItemIDs = outfitItemIDs
        self.events = events
    }

    /// Суммарный TOG текущего набора одежды.
    var effectiveOutfitTOG: Double? {
        let values = outfitItemIDs.compactMap { GarmentCatalog.byID[$0]?.tog }
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    /// Осталось до целевой длительности (сек), если она задана.
    func remainingSeconds(now: Date = .now) -> TimeInterval? {
        guard let planned = plannedDurationMinutes else { return nil }
        let target = startDate.addingTimeInterval(TimeInterval(planned * 60))
        return target.timeIntervalSince(now)
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
    private let storageKey = "active_walk_v1"

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
