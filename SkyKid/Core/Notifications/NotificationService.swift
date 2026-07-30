import Foundation
import UserNotifications

// Локальные уведомления не содержат повторяющийся комплект одежды:
// прогноз и рекомендация могут устареть до момента доставки.

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
@Observable
final class NotificationService {
    static let shared = NotificationService()

    static let enabledKey        = "notifications_enabled"
    static let walkScheduleKey   = "walk_schedule_v1"
    private static let walkReminderPrefix = "walk_reminder_"

    private enum ID {
        static let rainCoverVent = "rain_cover_vent"
        static let walkWindow    = "walk_window_start"
        static let dailyWeatherRefresh = "daily_weather_refresh_v2"
        static let legacyDailyOutfit = "daily_outfit_summary"
        static var all: [String] {
            [rainCoverVent, walkWindow, dailyWeatherRefresh, legacyDailyOutfit]
        }
    }

    private init() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [ID.legacyDailyOutfit]
        )
    }

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
        if granted {
            await scheduleDailyRefresh()
            await syncWalkSchedule(loadWalkSchedule())
        } else {
            removeAll()
        }
        return granted
    }

    /// Синхронизирует отложенные уведомления с текущей рекомендацией.
    /// Идемпотентно: можно вызывать при каждом обновлении погоды.
    func sync(recommendation: OutfitRecommendation, gearSetup: GearSetup) async {
        guard isEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let pending = Set(await center.pendingNotificationRequests().map(\.identifier))

        // Повторяющееся уведомление просит обновить данные и никогда не
        // повторяет вчерашний комплект как актуальный.
        await scheduleDailyRefresh()

        // Дождевик: таймер не перезапускаем, если уже заведён
        if gearSetup.rainCover == .present_on {
            if !pending.contains(ID.rainCoverVent) {
                let content = notificationContent(
                    from: SafeReminderContentFactory.rainCoverVentilationCheck()
                )
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 15 * 60, repeats: false)
                try? await center.add(UNNotificationRequest(
                    identifier: ID.rainCoverVent, content: content, trigger: trigger))
            }
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [ID.rainCoverVent])
        }

        // walkWindow: время окна может сдвигаться с каждым прогнозом — перезаписываем
        if recommendation.blockingWarning == nil,
           let window = recommendation.walkWindow,
           window.start > Date() {
            let content = notificationContent(
                from: SafeReminderContentFactory.suitableWalkWindow(start: window.start)
            )
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
            let content = notificationContent(
                from: SafeReminderContentFactory.scheduledWalkCheck()
            )
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

    private func notificationContent(
        from reminder: SafeReminderContent
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        return content
    }

    private func scheduleDailyRefresh() async {
        let center = UNUserNotificationCenter.current()
        let content = notificationContent(
            from: SafeReminderContentFactory.dailyWeatherRefresh()
        )
        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        center.removePendingNotificationRequests(
            withIdentifiers: [ID.dailyWeatherRefresh, ID.legacyDailyOutfit]
        )
        try? await center.add(UNNotificationRequest(
            identifier: ID.dailyWeatherRefresh,
            content: content,
            trigger: trigger
        ))
    }

    private func removeAll() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ID.all)
        // Walk reminders are removed by prefix during syncWalkSchedule; here clear all
        center.removeAllPendingNotificationRequests()
    }
}
