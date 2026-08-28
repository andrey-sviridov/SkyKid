import Foundation

// MARK: - WalkSummary

/// Итоги живой прогулки, рассчитанные из сохранённого таймлайна.
///
/// Значения здесь не зависят от SwiftUI: экран завершения и история используют
/// один и тот же расчёт. Если ребёнок уснул и отметки «Проснулся» нет, сон
/// считается до конца прогулки и помечается как незавершённый.
struct WalkSummary: Equatable {
    let durationMinutes: Int
    let sleepDurationMinutes: Int?
    let sleepSessionCount: Int
    let isSleepInProgressAtFinish: Bool
    let bassinetteDurationMinutes: Int?
    let bassinetteSessionCount: Int
    let garmentChangeCount: Int
    let checkpointCount: Int
    let eventCount: Int
    let plannedDurationMinutes: Int?
    let comfortLevel: BabyComfortLevel
    let weatherTemperature: Double

    var hasSleepData: Bool {
        sleepSessionCount > 0
    }

    var didReachPlannedDuration: Bool? {
        guard let plannedDurationMinutes else { return nil }
        return durationMinutes >= plannedDurationMinutes
    }
}

// MARK: - WalkSummaryBuilder

/// Чистый расчёт итогов по событиям прогулки.
enum WalkSummaryBuilder {
    static func make(from log: WalkLog) -> WalkSummary {
        let durationMinutes = max(1, log.durationMinutes)
        let startDate = log.date
        let endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
        let events = log.events
            .filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
            .sorted { $0.timestamp < $1.timestamp }

        let sleep = intervalSummary(
            events: events,
            startDate: startDate,
            endDate: endDate,
            startKind: .sleep,
            endKind: .wake
        )
        let bassinette = intervalSummary(
            events: events,
            startDate: startDate,
            endDate: endDate,
            startKind: .openedBassinette,
            endKind: .closedBassinette
        )

        return WalkSummary(
            durationMinutes: durationMinutes,
            sleepDurationMinutes: sleep.durationMinutes,
            sleepSessionCount: sleep.sessionCount,
            isSleepInProgressAtFinish: sleep.hasOpenInterval,
            bassinetteDurationMinutes: bassinette.durationMinutes,
            bassinetteSessionCount: bassinette.sessionCount,
            garmentChangeCount: events.filter {
                $0.kind == .addedGarment || $0.kind == .removedGarment
            }.count,
            checkpointCount: events.filter { $0.kind == .checkpoint }.count,
            eventCount: log.events.count,
            plannedDurationMinutes: log.plannedDurationMinutes,
            comfortLevel: log.comfortLevel,
            weatherTemperature: log.weatherTemperature
        )
    }

    // MARK: - Interval calculation

    private struct IntervalSummary {
        let durationMinutes: Int?
        let sessionCount: Int
        let hasOpenInterval: Bool
    }

    private static func intervalSummary(
        events: [WalkEvent],
        startDate: Date,
        endDate: Date,
        startKind: WalkEventKind,
        endKind: WalkEventKind
    ) -> IntervalSummary {
        var intervalStart: Date?
        var totalSeconds: TimeInterval = 0
        var sessionCount = 0

        for event in events {
            if event.kind.rawValue == startKind.rawValue {
                guard intervalStart == nil else { continue }
                intervalStart = event.timestamp
                sessionCount += 1
            } else if event.kind.rawValue == endKind.rawValue {
                guard let currentStart = intervalStart else { continue }
                totalSeconds += max(0, event.timestamp.timeIntervalSince(currentStart))
                intervalStart = nil
            }
        }

        if let intervalStart {
            totalSeconds += max(0, endDate.timeIntervalSince(intervalStart))
        }

        guard sessionCount > 0 else {
            return IntervalSummary(durationMinutes: nil, sessionCount: 0, hasOpenInterval: false)
        }

        return IntervalSummary(
            durationMinutes: max(0, Int(totalSeconds / 60.0)),
            sessionCount: sessionCount,
            hasOpenInterval: intervalStart != nil
        )
    }
}
