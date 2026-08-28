import Foundation

// MARK: - LiveWalkSnapshot

/// Идущая прогулка одного из родителей, какой её видит семья.
///
/// Отличается от [ActiveWalk] тем, что несёт ещё и «чья она» и «когда
/// последний раз обновлялась»: без первого нельзя отличить свою прогулку от
/// чужой, без второго — живую от зависшей.
struct LiveWalkSnapshot: Identifiable, Hashable {
    let walk: ActiveWalk
    let ownerUserID: UUID
    /// Проставляется сервером (триггер `live_walks_set_updated_at`), а не
    /// устройством: расхождение часов телефонов ломало бы расчёт свежести.
    let updatedAt: Date

    var id: UUID { walk.id }

    var eventCount: Int { walk.events.count }
}

// MARK: - Протухание

extension LiveWalkSnapshot {
    /// Строка живёт ровно столько, сколько идёт прогулка, и удаляется на
    /// завершении. Но приложение владельца могло умереть, не успев её
    /// убрать, — такие «призраки» отсекаются по времени.
    enum Staleness {
        /// Публикатор трогает строку на каждой мутации; тишина в несколько
        /// часов означает, что прогулки уже нет.
        static let maxSilence: TimeInterval = 2 * 60 * 60
        /// Страховка от прогулки, которую забыли завершить.
        static let maxDuration: TimeInterval = 12 * 60 * 60
    }

    func isStale(now: Date = .now) -> Bool {
        now.timeIntervalSince(updatedAt) > Staleness.maxSilence
            || now.timeIntervalSince(walk.startDate) > Staleness.maxDuration
    }
}
