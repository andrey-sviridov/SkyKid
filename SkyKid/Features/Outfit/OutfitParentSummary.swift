import Foundation

// MARK: - OutfitParentSummary

struct OutfitParentSummary: Equatable, Sendable {
    let outfit: String
    let reason: String
    let check: String
    let ageContext: String
    let confidence: RecommendationConfidence
    let confidenceReason: String
}

enum RecommendationConfidence: String, Equatable, Sendable {
    case high
    case medium
    case low
}

// MARK: - OutfitParentSummaryBuilder

enum OutfitParentSummaryBuilder {
    static func make(
        recommendation: OutfitRecommendation,
        weather: NormalizedWeather,
        profile: ChildThermalProfile,
        walkContext: WalkContext
    ) -> OutfitParentSummary {
        let confidence = overallConfidence(
            recommendation: recommendation,
            weather: weather
        )

        return OutfitParentSummary(
            outfit: outfitText(from: recommendation.allDisplayLayers),
            reason: reasonText(
                recommendation: recommendation,
                weather: weather,
                walkContext: walkContext
            ),
            check: recommendation.checkHint,
            ageContext: ageContext(for: profile),
            confidence: confidence,
            confidenceReason: confidenceReason(
                confidence,
                recommendation: recommendation,
                weather: weather
            )
        )
    }

    // MARK: - Outfit text

    private static func outfitText(from layers: [RecommendedLayer]) -> String {
        guard !layers.isEmpty else {
            return "Дополнительные слои на корпус не нужны"
        }

        let names = layers.map(\.name)
        guard names.count > 4 else { return joined(names) }
        return "\(joined(Array(names.prefix(3)))) и ещё \(names.count - 3)"
    }

    private static func joined(_ values: [String]) -> String {
        guard let last = values.last else { return "" }
        guard values.count > 1 else { return last }
        return values.dropLast().joined(separator: ", ") + " и " + last
    }

    // MARK: - Reason

    private static func reasonText(
        recommendation: OutfitRecommendation,
        weather: NormalizedWeather,
        walkContext: WalkContext
    ) -> String {
        let temperatures = recommendation.temperatures
        var factors = [
            walkContext.transportMode.walkLabel.lowercased(),
            walkContext.activityLevel.label.lowercased()
        ]
        if weather.windSpeed >= 7 {
            factors.append("ветер")
        }
        if weather.precipitation > 0.1 {
            factors.append("осадки")
        }

        return "На улице \(rounded(temperatures.outside))°, в условиях ребёнка около \(rounded(temperatures.microclimate))°. Учтены \(joined(factors))."
    }

    private static func rounded(_ value: Double) -> Int {
        Int(value.rounded())
    }

    // MARK: - Confidence

    private static func overallConfidence(
        recommendation: OutfitRecommendation,
        weather: NormalizedWeather
    ) -> RecommendationConfidence {
        let fitConfidence: RecommendationConfidence
        switch recommendation.fit?.confidence {
        case .high:   fitConfidence = .high
        case .medium: fitConfidence = .medium
        case .low:    fitConfidence = .low
        case nil:     fitConfidence = .medium
        }

        let weatherConfidence: RecommendationConfidence
        switch weather.confidence.level {
        case .high:   weatherConfidence = .high
        case .medium: weatherConfidence = .medium
        case .low:    weatherConfidence = .low
        }

        return minimum(fitConfidence, weatherConfidence)
    }

    private static func minimum(
        _ left: RecommendationConfidence,
        _ right: RecommendationConfidence
    ) -> RecommendationConfidence {
        rank(left) <= rank(right) ? left : right
    }

    private static func rank(_ confidence: RecommendationConfidence) -> Int {
        switch confidence {
        case .low:    return 0
        case .medium: return 1
        case .high:   return 2
        }
    }

    private static func confidenceReason(
        _ confidence: RecommendationConfidence,
        recommendation: OutfitRecommendation,
        weather: NormalizedWeather
    ) -> String {
        if weather.confidence.level == .low {
            return "Не все погодные данные доступны — проверьте ребёнка раньше."
        }
        if recommendation.fit?.confidence == .low {
            return "Доступный гардероб не полностью совпадает с тепловой целью."
        }
        switch confidence {
        case .high:
            return "Погодные данные и доступный комплект хорошо согласуются с расчётом."
        case .medium:
            return "Комплект близок к расчётной цели, но нужна обычная проверка на прогулке."
        case .low:
            return "Используйте рекомендацию осторожно и проверьте ребёнка раньше."
        }
    }

    // MARK: - Age range

    static func ageContext(for profile: ChildThermalProfile) -> String {
        "Возраст: \(profile.ageLabel) · группа \(ageRange(for: profile.ageGroup))"
    }

    private static func ageRange(for ageGroup: AgeGroup) -> String {
        switch ageGroup {
        case .infant:    return "0–5 месяцев"
        case .baby:      return "6–11 месяцев"
        case .toddler:   return "1–3 года"
        case .preschool: return "3–6 лет"
        case .schoolAge: return "6–12 лет"
        case .teen:      return "12+ лет"
        }
    }
}
