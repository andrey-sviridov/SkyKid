import Foundation

// MARK: - WalkHistoryInsights

/// Compact, non-medical summaries of the user's own walk notes.
struct WalkHistoryInsights: Equatable {
    let learningState: LearningState
    let similarWalkCount: Int
    let comfortPattern: String
    let clothingPattern: String?
    let adaptation: String

    // Legacy operational values remain temporarily for source compatibility.
    let walkCount: Int
    let averageDurationMinutes: Int
    let sleepMinutes: Int?
    let comfortablePercent: Int

    enum LearningState: Equatable {
        case noData
        case insufficient
        case warmer
        case lighter
        case mixed
        case legacy
    }

    static func learning(from summary: PersonalizationSummary?) -> WalkHistoryInsights {
        guard let summary, summary.hasAnyData else {
            return learningInsights(
                state: .noData,
                similarWalkCount: 0,
                comfortPattern: L10n.text("Пока нет подходящих прогулок с оценкой комфорта."),
                clothingPattern: nil,
                adaptation: L10n.text("После нескольких похожих прогулок SkyKid сможет осторожно учитывать повторяющиеся наблюдения.")
            )
        }

        let comfortPattern = comfortPattern(for: summary)
        switch summary.explanation {
        case let .insufficientEvidence(count):
            return learningInsights(
                state: .insufficient,
                similarWalkCount: count,
                comfortPattern: comfortPattern,
                clothingPattern: nil,
                adaptation: L10n.text("Данных пока недостаточно, поэтому базовый расчёт не изменён.")
            )
        case .prefersWarmer:
            return learningInsights(
                state: .warmer,
                similarWalkCount: summary.similarObservationCount,
                comfortPattern: comfortPattern,
                clothingPattern: nil,
                adaptation: L10n.text("Для похожих условий SkyKid осторожно выбирает более тёплый комплект.")
            )
        case .prefersLighter:
            return learningInsights(
                state: .lighter,
                similarWalkCount: summary.similarObservationCount,
                comfortPattern: comfortPattern,
                clothingPattern: nil,
                adaptation: L10n.text("Для похожих условий SkyKid осторожно выбирает более лёгкий комплект.")
            )
        case .balanced:
            return learningInsights(
                state: .mixed,
                similarWalkCount: summary.similarObservationCount,
                comfortPattern: comfortPattern,
                clothingPattern: nil,
                adaptation: L10n.text("Наблюдения различаются, поэтому базовый расчёт сохранён.")
            )
        case .legacyBaseline:
            return learningInsights(
                state: .legacy,
                similarWalkCount: summary.similarObservationCount,
                comfortPattern: comfortPattern,
                clothingPattern: nil,
                adaptation: L10n.text("Сохранена ранее настроенная персонализация; новые прогулки постепенно уточнят её.")
            )
        }
    }

    var similarWalkCountText: String {
        if similarWalkCount == 1 {
            return L10n.format("%lld похожая прогулка", similarWalkCount)
        }
        return L10n.format("%lld похожих прогулок", similarWalkCount)
    }

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
            learningState: .noData,
            similarWalkCount: 0,
            comfortPattern: "",
            clothingPattern: nil,
            adaptation: "",
            walkCount: recentLogs.count,
            averageDurationMinutes: recentLogs.map(\.durationMinutes).reduce(0, +) / recentLogs.count,
            sleepMinutes: trackedSleep.isEmpty ? nil : trackedSleep.reduce(0, +),
            comfortablePercent: Int(
                (Double(comfortableCount) / Double(recentLogs.count) * 100).rounded()
            )
        )
    }

    private static func learningInsights(
        state: LearningState,
        similarWalkCount: Int,
        comfortPattern: String,
        clothingPattern: String?,
        adaptation: String
    ) -> WalkHistoryInsights {
        WalkHistoryInsights(
            learningState: state,
            similarWalkCount: similarWalkCount,
            comfortPattern: comfortPattern,
            clothingPattern: clothingPattern,
            adaptation: adaptation,
            walkCount: 0,
            averageDurationMinutes: 0,
            sleepMinutes: nil,
            comfortablePercent: 0
        )
    }

    private static func comfortPattern(for summary: PersonalizationSummary) -> String {
        if summary.independentDirectionalCount == 0,
           summary.comfortableConfirmationCount > 0 {
            return L10n.text("В похожих условиях ребёнку обычно было комфортно.")
        }
        if summary.netDirectionalScore > 0 {
            return L10n.text("В похожих условиях повторялись признаки, что ребёнку было прохладно.")
        }
        if summary.netDirectionalScore < 0 {
            return L10n.text("В похожих условиях повторялись признаки, что ребёнку было жарко.")
        }
        return L10n.text("Оценки похожих прогулок пока не образуют устойчивого паттерна.")
    }

}
