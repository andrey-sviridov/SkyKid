import Foundation
import UserNotifications

// P2-3: локальные уведомления.
// «Проветрите дождевик» — через 15 мин после установки дождевика.
// «Хорошая погода для прогулки» — когда наступает walkWindow из §6.1.
// Включается переключателем в ProfileSummaryView; ключ — в AppGroup.

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    static let enabledKey = "notifications_enabled"

    private enum ID {
        static let rainCoverVent = "rain_cover_vent"
        static let walkWindow    = "walk_window_start"
        static var all: [String] { [rainCoverVent, walkWindow] }
    }

    private init() {}

    var isEnabled: Bool {
        AppGroup.defaults.bool(forKey: Self.enabledKey)
    }

    /// Включает/выключает уведомления. При включении запрашивает разрешение;
    /// возвращает фактическое состояние (false, если пользователь отказал).
    func setEnabled(_ on: Bool) async -> Bool {
        guard on else {
            AppGroup.defaults.set(false, forKey: Self.enabledKey)
            removeAll()
            return false
        }
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        AppGroup.defaults.set(granted, forKey: Self.enabledKey)
        if !granted { removeAll() }
        return granted
    }

    /// Синхронизирует отложенные уведомления с текущей рекомендацией.
    /// Идемпотентно: можно вызывать при каждом обновлении погоды.
    func sync(recommendation: OutfitRecommendation, gearSetup: GearSetup) async {
        guard isEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let pending = Set(await center.pendingNotificationRequests().map(\.identifier))

        // Дождевик: таймер не перезапускаем, если уже заведён
        if gearSetup.rainCover == .present_on {
            if !pending.contains(ID.rainCoverVent) {
                let content = UNMutableNotificationContent()
                content.title = "Проветрите дождевик"
                content.body  = "Дождевик стоит уже 15 минут — приоткройте его на 1–2 минуты."
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 15 * 60, repeats: false)
                try? await center.add(UNNotificationRequest(
                    identifier: ID.rainCoverVent, content: content, trigger: trigger))
            }
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [ID.rainCoverVent])
        }

        // walkWindow: время окна может сдвигаться с каждым прогнозом — перезаписываем
        if let window = recommendation.walkWindow, window.start > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Хорошая погода для прогулки"
            let time = window.start.formatted(
                Date.FormatStyle.dateTime.hour(.twoDigits(amPM: .omitted)).minute())
            content.body  = "С \(time) условия подходят для прогулки — собирайтесь!"
            content.sound = .default
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: window.start)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(
                identifier: ID.walkWindow, content: content, trigger: trigger))
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [ID.walkWindow])
        }
    }

    private func removeAll() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ID.all)
    }
}
