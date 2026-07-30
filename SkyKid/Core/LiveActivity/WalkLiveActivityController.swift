@preconcurrency import ActivityKit
import Foundation

// MARK: - WalkLiveActivityController
// Тонкая обёртка над Activity<WalkActivityAttributes>. Обновления идут
// локально (Activity.update) в момент действий пользователя в приложении —
// APNs не нужен, т.к. таймер тикает нативно через Text(_:style:.timer),
// а прочие данные меняются только пока приложение открыто.

@MainActor
final class WalkLiveActivityController {
    static let shared = WalkLiveActivityController()

    private var activity: Activity<WalkActivityAttributes>?

    /// Запускает новую Live Activity. Молча выходит, если пользователь их отключил.
    func start(for walk: ActiveWalk) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activity == nil else { return }

        let attributes = WalkActivityAttributes(
            startDate: walk.startDate,
            plannedDurationMinutes: walk.plannedDurationMinutes,
            weatherTemperature: walk.weatherTemperature,
            weatherCode: walk.weatherCode,
            weatherIconSymbol: walk.weatherIconSymbol,
            weatherDescription: walk.weatherDescription,
            targetTOG: walk.targetTOG
        )
        let content = ActivityContent(
            state: Self.contentState(for: walk, lastEvent: walk.events.last),
            staleDate: nil
        )
        activity = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    /// Переприсоединение после перезапуска приложения посреди прогулки:
    /// система хранит систему-side активность независимо от процесса приложения.
    func reattachIfNeeded(for walk: ActiveWalk) {
        guard activity == nil else { return }
        if let existing = Activity<WalkActivityAttributes>.activities.first {
            activity = existing
        } else {
            start(for: walk)
        }
    }

    func update(for walk: ActiveWalk, lastEvent: WalkEvent?) {
        guard let activity else { return }
        let content = ActivityContent(
            state: Self.contentState(for: walk, lastEvent: lastEvent),
            staleDate: nil
        )
        Task { await activity.update(content) }
    }

    func end() {
        guard let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
    }

    private static func contentState(
        for walk: ActiveWalk,
        lastEvent: WalkEvent?
    ) -> WalkActivityAttributes.ContentState {
        WalkActivityAttributes.ContentState(
            outfitCount: walk.outfitItemIDs.count,
            effectiveTOG: walk.effectiveOutfitTOG ?? 0,
            lastEventTitle: lastEvent?.kind.title,
            lastEventIcon: lastEvent?.kind.icon,
            lastEventDate: lastEvent?.timestamp
        )
    }
}
