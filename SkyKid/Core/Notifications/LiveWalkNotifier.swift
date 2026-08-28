import Foundation
import UserNotifications

// MARK: - LiveWalkNotifier

/// Локальные уведомления о прогулке второго родителя.
///
/// `LiveWalkObserver` вызывает эти методы и сам ничего не знает про
/// `UNUserNotificationCenter` — вся логика доставки в одном месте.
///
/// Методы `async`, а не синхронные обёртки над `Task { }`: `UNNotificationRequest`
/// не гарантированно `Sendable`, и Swift 6 справедливо не даёт передавать его
/// в новый неструктурированный `Task` без разбора владения. Awaiting
/// напрямую снимает вопрос целиком — `LiveWalkObserver.apply`/`remove` и так
/// уже `async` из-за постоянного стрима Realtime-событий.
@MainActor
final class LiveWalkNotifier {
    static let shared = LiveWalkNotifier()

    enum ID {
        static let started = "live_walk_started"
        static let timeline = "live_walk_timeline"
        static let finished = "live_walk_finished"
    }

    /// Инъекции ради тестов: тестовый хост не запрашивал разрешение на
    /// уведомления, и реальный `UNUserNotificationCenter.add` там ведёт себя
    /// непредсказуемо. Реальная реализация полагается на то же поведение
    /// системы, которое проверяет `add(_:)`: запрос с уже занятым
    /// идентификатором заменяет отложенный, а не добавляется вторым —
    /// именно на этом держится агрегация отметок.
    var addRequest: (UNNotificationRequest) async -> Void = { request in
        try? await UNUserNotificationCenter.current().add(request)
    }
    var removePending: ([String]) -> Void = { identifiers in
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private init() {}

    /// Двойной гейт: общий тумблер уведомлений в приложении и отдельный
    /// тумблер именно для чужой прогулки — включать одно без другого
    /// бессмысленно.
    var isEnabled: Bool {
        NotificationService.shared.isEnabled && LiveWalkNotificationPreferences.isEnabled
    }

    func notifyStarted() async {
        guard isEnabled else { return }
        await post(
            id: ID.started,
            title: LiveWalkNotificationContent.startedTitle,
            body: LiveWalkNotificationContent.startedBody
        )
    }

    /// Агрегирует отметки в одно уведомление: фиксированный идентификатор
    /// значит, что каждая новая отметка внутри 30-секундного окна
    /// перезаписывает ещё не доставленный запрос, а не плодит баннер за
    /// баннером.
    func notifyTimelineUpdate(eventCount: Int) async {
        guard isEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = LiveWalkNotificationContent.timelineTitle
        content.body = LiveWalkNotificationContent.timelineBody(eventCount: eventCount)
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
        await addRequest(UNNotificationRequest(identifier: ID.timeline, content: content, trigger: trigger))
    }

    func notifyFinished() async {
        guard isEnabled else { return }
        // Отложенное «N новых отметок» больше не актуально — прогулка уже
        // закончилась, и оно доставилось бы поверх этого уведомления.
        removePending([ID.timeline])
        await post(
            id: ID.finished,
            title: LiveWalkNotificationContent.finishedTitle,
            body: LiveWalkNotificationContent.finishedBody
        )
    }

    private func post(id: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        await addRequest(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}
