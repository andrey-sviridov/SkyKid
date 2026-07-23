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
            return L10n.text("Дополнительные слои на корпус не нужны")
        }

        let names = layers.map(\.name)
        guard names.count > 4 else { return joined(names) }
        return L10n.format(
            "%@ и ещё %lld",
            joined(Array(names.prefix(3))),
            names.count - 3
        )
    }

    private static func joined(_ values: [String]) -> String {
        let formatter = ListFormatter()
        formatter.locale = L10n.locale
        return formatter.string(from: values) ?? values.joined(separator: ", ")
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
            factors.append(L10n.text("ветер"))
        }
        if weather.precipitation > 0.1 {
            factors.append(L10n.text("осадки"))
        }

        return L10n.format(
            "На улице %lld°, в условиях ребёнка около %lld°. Учтены %@.",
            rounded(temperatures.outside),
            rounded(temperatures.microclimate),
            joined(factors)
        )
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
            return L10n.text("Не все погодные данные доступны — проверьте ребёнка раньше.")
        }
        if recommendation.fit?.confidence == .low {
            return L10n.text("Доступный гардероб не полностью совпадает с тепловой целью.")
        }
        switch confidence {
        case .high:
            return L10n.text("Погодные данные и доступный комплект хорошо согласуются с расчётом.")
        case .medium:
            return L10n.text("Комплект близок к расчётной цели, но нужна обычная проверка на прогулке.")
        case .low:
            return L10n.text("Используйте рекомендацию осторожно и проверьте ребёнка раньше.")
        }
    }

    // MARK: - Age range

    static func ageContext(for profile: ChildThermalProfile) -> String {
        L10n.format(
            "Возраст: %@ · группа %@",
            profile.ageLabel,
            ageRange(for: profile.ageGroup)
        )
    }

    private static func ageRange(for ageGroup: AgeGroup) -> String {
        switch ageGroup {
        case .infant:    return L10n.text("0–5 месяцев")
        case .baby:      return L10n.text("6–11 месяцев")
        case .toddler:   return L10n.text("1–3 года")
        case .preschool: return L10n.text("3–6 лет")
        case .schoolAge: return L10n.text("6–12 лет")
        case .teen:      return L10n.text("12+ лет")
        }
    }
}
