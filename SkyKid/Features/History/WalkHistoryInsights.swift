import Foundation

// MARK: - WalkHistoryInsights

/// Compact, non-medical summaries of the user's own walk notes.
struct WalkHistoryInsights: Equatable {
    let walkCount: Int
    let averageDurationMinutes: Int
    let sleepMinutes: Int?
    let comfortablePercent: Int

    static func make(
        from logs: [WalkLog],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> WalkHistoryInsights? {
        guard let cutoff = calendar.date(byAdding: .day, value: -7, to: now) else {
            return nil
        }

        let recentLogs = logs.filter { $0.date >= cutoff && $0.date <= now }
        guard recentLogs.count >= 2 else { return nil }

        let summaries = recentLogs.map(WalkSummaryBuilder.make(from:))
        let trackedSleep = summaries.compactMap(\.sleepDurationMinutes)
        let comfortableCount = recentLogs.filter { $0.comfortLevel == .comfortable }.count

        return WalkHistoryInsights(
            walkCount: recentLogs.count,
            averageDurationMinutes: recentLogs.map(\.durationMinutes).reduce(0, +) / recentLogs.count,
            sleepMinutes: trackedSleep.isEmpty ? nil : trackedSleep.reduce(0, +),
            comfortablePercent: Int(
                (Double(comfortableCount) / Double(recentLogs.count) * 100).rounded()
            )
        )
    }
}
