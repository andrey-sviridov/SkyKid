import Foundation

// MARK: - Walk window models

struct WalkWindowCandidate: Equatable, Sendable {
    let time: Date
    let apparentTemperature: Double?
    let windKmh: Double?
    let gustKmh: Double?
    let precipitationProbability: Double?
    let uvIndex: Double?
}

struct WalkWindowSuggestion: Equatable, Sendable {
    enum Reason: String, Equatable, Sendable {
        case milderTemperature
        case lessRain
        case lighterWind
        case lowerUV
    }

    let interval: DateInterval
    let reasons: [Reason]
}

// MARK: - WalkWindowScorer

/// Ranks forecast intervals relative to current conditions. This is an
/// environmental comparison only; age and medical policies remain the gate.
enum WalkWindowScorer {
    static func suggestion(
        current: WalkWindowCandidate,
        hourly: [WalkWindowCandidate],
        limits: OutdoorSafetyLimits,
        forecastUpdatedAt: Date,
        confidence: WeatherConfidenceLevel,
        now: Date
    ) -> WalkWindowSuggestion? {
        guard confidence != .low,
              now.timeIntervalSince(forecastUpdatedAt) >= 0,
              now.timeIntervalSince(forecastUpdatedAt)
                <= OutfitConfig.Safety.walkWindowMaximumForecastAge
        else { return nil }

        let candidates = hourly
            .filter {
                $0.time >= now
                    && $0.time <= now.addingTimeInterval(OutfitConfig.Safety.walkWindowHorizon)
            }
            .sorted { $0.time < $1.time }

        let windows = zip(candidates, candidates.dropFirst()).compactMap { first, second -> RankedWindow? in
            guard second.time.timeIntervalSince(first.time)
                    <= OutfitConfig.Safety.walkWindowMaximumGap,
                  isWithinLimits(first, limits: limits),
                  isWithinLimits(second, limits: limits),
                  evidenceCount(first) >= OutfitConfig.Safety.walkWindowMinimumEvidenceFields,
                  evidenceCount(second) >= OutfitConfig.Safety.walkWindowMinimumEvidenceFields
            else { return nil }

            return RankedWindow(
                first: first,
                second: second,
                score: (penalty(first, limits: limits) + penalty(second, limits: limits)) / 2
            )
        }

        guard let best = windows.min(by: {
            $0.score == $1.score
                ? $0.first.time < $1.first.time
                : $0.score < $1.score
        }) else { return nil }

        return WalkWindowSuggestion(
            interval: DateInterval(start: best.first.time, duration: 2 * 3_600),
            reasons: reasons(for: best, comparedWith: current, limits: limits)
        )
    }
}

// MARK: - Ranking

private extension WalkWindowScorer {
    struct RankedWindow {
        let first: WalkWindowCandidate
        let second: WalkWindowCandidate
        let score: Double
    }

    static func isWithinLimits(_ value: WalkWindowCandidate, limits: OutdoorSafetyLimits) -> Bool {
        guard let temperature = value.apparentTemperature else { return false }
        return temperature > limits.coldBelow && temperature < limits.hotAbove
    }

    static func evidenceCount(_ value: WalkWindowCandidate) -> Int {
        [
            value.apparentTemperature,
            value.precipitationProbability,
            value.windKmh,
            value.gustKmh,
            value.uvIndex,
        ].compactMap { $0 }.count
    }

    static func penalty(_ value: WalkWindowCandidate, limits: OutdoorSafetyLimits) -> Double {
        let midpoint = (limits.coldBelow + limits.hotAbove) / 2
        let temperature = abs((value.apparentTemperature ?? midpoint) - midpoint)
        let rain = (value.precipitationProbability ?? 0) * OutfitConfig.Safety.walkWindowRainWeight
        let wind = max(value.windKmh ?? 0, value.gustKmh ?? 0)
            * OutfitConfig.Safety.walkWindowWindWeight
        let uv = (value.uvIndex ?? 0) * OutfitConfig.Safety.walkWindowUVWeight
        let missingOptionalFields = [
            value.precipitationProbability,
            maximum(value.windKmh, value.gustKmh),
            value.uvIndex,
        ].filter { $0 == nil }.count
        let evidencePenalty = Double(missingOptionalFields)
            * OutfitConfig.Safety.walkWindowMissingEvidencePenalty
        return temperature + rain + wind + uv + evidencePenalty
    }

    static func reasons(
        for window: RankedWindow,
        comparedWith current: WalkWindowCandidate,
        limits: OutdoorSafetyLimits
    ) -> [WalkWindowSuggestion.Reason] {
        var result: [WalkWindowSuggestion.Reason] = []
        let midpoint = (limits.coldBelow + limits.hotAbove) / 2

        if let currentValue = current.apparentTemperature,
           let candidateValue = average(window.first.apparentTemperature, window.second.apparentTemperature),
           abs(candidateValue - midpoint) < abs(currentValue - midpoint) {
            result.append(.milderTemperature)
        }
        if isLower(average(window.first.precipitationProbability, window.second.precipitationProbability), than: current.precipitationProbability) {
            result.append(.lessRain)
        }
        let candidateWind = average(
            maximum(window.first.windKmh, window.first.gustKmh),
            maximum(window.second.windKmh, window.second.gustKmh)
        )
        if isLower(candidateWind, than: maximum(current.windKmh, current.gustKmh)) {
            result.append(.lighterWind)
        }
        if isLower(average(window.first.uvIndex, window.second.uvIndex), than: current.uvIndex) {
            result.append(.lowerUV)
        }
        return result
    }

    static func average(_ first: Double?, _ second: Double?) -> Double? {
        guard let first, let second else { return nil }
        return (first + second) / 2
    }

    static func maximum(_ first: Double?, _ second: Double?) -> Double? {
        switch (first, second) {
        case let (first?, second?): max(first, second)
        case let (first?, nil): first
        case let (nil, second?): second
        case (nil, nil): nil
        }
    }

    static func isLower(_ candidate: Double?, than current: Double?) -> Bool {
        guard let candidate, let current else { return false }
        return candidate < current
    }
}
