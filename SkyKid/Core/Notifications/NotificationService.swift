import Foundation
import UserNotifications

// P2-3: локальные уведомления.
// «Проветрите дождевик» — через 15 мин после установки дождевика.
// «Хорошая погода для прогулки» — когда наступает walkWindow из §6.1.
// «Время прогулки» — по расписанию пользователя (до 4 слотов).
// Включается переключателем в ProfileSummaryView; ключ — в AppGroup.

// MARK: - WalkScheduleEntry

struct WalkScheduleEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var hour: Int
    var minute: Int
    var isEnabled: Bool

    init(hour: Int, minute: Int, isEnabled: Bool = true) {
        self.id = UUID()
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
    }

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    static let enabledKey        = "notifications_enabled"
    static let walkScheduleKey   = "walk_schedule_v1"
    private static let walkReminderPrefix = "walk_reminder_"

    private enum ID {
        static let rainCoverVent = "rain_cover_vent"
        static let walkWindow    = "walk_window_start"
        static let dailyOutfit   = "daily_outfit_summary"
        static var all: [String] { [rainCoverVent, walkWindow, dailyOutfit] }
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
    func sync(recommendation: OutfitRecommendation, weather: WeatherData, gearSetup: GearSetup) async {
        guard isEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let pending = Set(await center.pendingNotificationRequests().map(\.identifier))

        // Ежедневное уведомление в 08:00 — всегда перезаписываем свежим контентом
        let dailyContent = UNMutableNotificationContent()
        dailyContent.title = "Что надеть малышу сегодня?"
        let temp = Int(weather.apparentTemperature.rounded())
        let topLayers = recommendation.layers.prefix(3).map(\.name).joined(separator: " + ")
        dailyContent.body = topLayers.isEmpty
            ? "Ощущается \(temp)°C — откройте приложение для рекомендации."
            : "Ощущается \(temp)°C: \(topLayers)."
        dailyContent.sound = .default
        var dailyComps = DateComponents()
        dailyComps.hour   = 8
        dailyComps.minute = 0
        let dailyTrigger = UNCalendarNotificationTrigger(dateMatching: dailyComps, repeats: true)
        center.removePendingNotificationRequests(withIdentifiers: [ID.dailyOutfit])
        try? await center.add(UNNotificationRequest(
            identifier: ID.dailyOutfit, content: dailyContent, trigger: dailyTrigger))

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

    // MARK: - Walk Schedule

    func loadWalkSchedule() -> [WalkScheduleEntry] {
        guard let data = AppGroup.defaults.data(forKey: Self.walkScheduleKey),
              let entries = try? JSONDecoder().decode([WalkScheduleEntry].self, from: data)
        else { return [] }
        return entries
    }

    func saveWalkSchedule(_ entries: [WalkScheduleEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        AppGroup.defaults.set(data, forKey: Self.walkScheduleKey)
    }

    func syncWalkSchedule(_ entries: [WalkScheduleEntry]) async {
        guard isEnabled else { return }
        let center = UNUserNotificationCenter.current()

        // Remove all existing walk reminders
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        let toRemove = pending.filter { $0.hasPrefix(Self.walkReminderPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: toRemove)

        for entry in entries where entry.isEnabled {
            let content = UNMutableNotificationContent()
            content.title = "Время прогулки!"
            content.body  = "Не забудьте проверить погоду и подобрать одежду для малыша."
            content.sound = .default
            var comps = DateComponents()
            comps.hour   = entry.hour
            comps.minute = entry.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            try? await center.add(UNNotificationRequest(
                identifier: Self.walkReminderPrefix + entry.id.uuidString,
                content: content,
                trigger: trigger
            ))
        }
    }

    // MARK: - Private

    private func removeAll() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ID.all)
        // Walk reminders are removed by prefix during syncWalkSchedule; here clear all
        center.removeAllPendingNotificationRequests()
    }
}
