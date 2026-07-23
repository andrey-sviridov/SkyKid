import SwiftUI

// MARK: - Thermal status

enum ClothingWidgetStatus: String, Codable, CaseIterable, Sendable {
    case extremeHeat
    case hot
    case warm
    case ideal
    case slightlyCold
    case cold
    case extremeCold

    init(effectiveTemperature: Double) {
        switch effectiveTemperature {
        case 30...:    self = .extremeHeat
        case 22..<30:  self = .hot
        case 18..<22:  self = .warm
        case 8..<18:   self = .ideal
        case 0..<8:    self = .slightlyCold
        case -10..<0:  self = .cold
        default:       self = .extremeCold
        }
    }

    var label: String {
        switch self {
        case .extremeHeat:  return L10n.text("ОПАСНО: ПЕРЕГРЕВ")
        case .hot:          return L10n.text("Жарко")
        case .warm:         return L10n.text("Тепловато")
        case .ideal:        return L10n.text("Комфортно")
        case .slightlyCold: return L10n.text("Прохладно")
        case .cold:         return L10n.text("Холодно")
        case .extremeCold:  return L10n.text("ОПАСНО: МОРОЗ")
        }
    }

    var color: Color {
        switch self {
        case .extremeHeat:  return .red
        case .hot:          return .orange
        case .warm:         return Color(red: 0.95, green: 0.78, blue: 0)
        case .ideal:        return .green
        case .slightlyCold: return Color(red: 0.3, green: 0.65, blue: 1)
        case .cold:         return .blue
        case .extremeCold:  return Color(red: 0, green: 0.1, blue: 0.75)
        }
    }

    var systemImage: String {
        switch self {
        case .extremeHeat:  return "exclamationmark.triangle.fill"
        case .hot:          return "sun.max.fill"
        case .warm:         return "thermometer.medium"
        case .ideal:        return "checkmark.seal.fill"
        case .slightlyCold: return "cloud.fill"
        case .cold:         return "snowflake"
        case .extremeCold:  return "snowflake.circle.fill"
        }
    }

    var defaultSafetyWarning: String? {
        switch self {
        case .extremeHeat: return L10n.text("Прогулку лучше перенести")
        case .extremeCold: return L10n.text("Прогулку лучше перенести")
        default:           return nil
        }
    }
}

// MARK: - Widget presentation model

/// A presentation-only adapter for the persisted recommendation snapshot.
/// It does not calculate or alter clothing layers.
struct WidgetOutfitRecommendation: Sendable {
    let outsideTemperature: Double
    let apparentTemperature: Double
    let effectiveTemperature: Double
    let microclimateTemperature: Double
    let cityName: String
    let status: ClothingWidgetStatus
    let outfitItems: [String]
    let ageLabel: String
    let primaryWarning: String?
    let hasBlockingWarning: Bool
    let updatedAt: Date
    let contextSummary: String
    let contextDetails: String
    let weatherSource: String
    let weatherConfidence: String

    init(snapshot: OutfitRecommendationSnapshot) {
        let recommendation = snapshot.recommendation
        let temperatures = recommendation.temperatures

        self.outsideTemperature = temperatures.outside
        self.apparentTemperature = temperatures.apparent
        self.effectiveTemperature = temperatures.effective
        self.microclimateTemperature = temperatures.microclimate
        self.cityName = snapshot.cityName
        self.status = ClothingWidgetStatus(effectiveTemperature: temperatures.effective)
        self.outfitItems = recommendation.allDisplayLayers.map(\.name)
        self.ageLabel = snapshot.childAgeLabel
        self.primaryWarning = recommendation.primarySafetyWarning?.message
        self.hasBlockingWarning = recommendation.blockingWarning != nil
        self.updatedAt = snapshot.generatedAt
        self.contextSummary = snapshot.context?.shortSummary ?? L10n.text("Контекст не сохранён")
        self.contextDetails = snapshot.context?.fullSummary ?? L10n.text("Условия прогулки не сохранены")
        self.weatherSource = snapshot.context?.weatherSource ?? L10n.text("Источник не сохранён")
        self.weatherConfidence = snapshot.context?.weatherConfidence ?? L10n.text("Уверенность не сохранена")
    }

    private init(
        outsideTemperature: Double,
        apparentTemperature: Double,
        effectiveTemperature: Double,
        microclimateTemperature: Double,
        cityName: String,
        status: ClothingWidgetStatus,
        outfitItems: [String],
        ageLabel: String,
        primaryWarning: String?,
        hasBlockingWarning: Bool,
        updatedAt: Date,
        contextSummary: String,
        contextDetails: String,
        weatherSource: String,
        weatherConfidence: String
    ) {
        self.outsideTemperature = outsideTemperature
        self.apparentTemperature = apparentTemperature
        self.effectiveTemperature = effectiveTemperature
        self.microclimateTemperature = microclimateTemperature
        self.cityName = cityName
        self.status = status
        self.outfitItems = outfitItems
        self.ageLabel = ageLabel
        self.primaryWarning = primaryWarning
        self.hasBlockingWarning = hasBlockingWarning
        self.updatedAt = updatedAt
        self.contextSummary = contextSummary
        self.contextDetails = contextDetails
        self.weatherSource = weatherSource
        self.weatherConfidence = weatherConfidence
    }

    var topItemsSummary: String {
        outfitItems.prefix(3).joined(separator: " · ")
    }

    var alertLabel: String {
        hasBlockingWarning ? L10n.text("ПРОГУЛКУ ОТМЕНИТЕ") : status.label
    }

    var alertColor: Color {
        hasBlockingWarning ? .red : status.color
    }

    var alertSystemImage: String {
        hasBlockingWarning ? "exclamationmark.octagon.fill" : status.systemImage
    }

    static var placeholder: WidgetOutfitRecommendation {
        WidgetOutfitRecommendation(
            outsideTemperature: 12,
            apparentTemperature: 10,
            effectiveTemperature: 8,
            microclimateTemperature: 10,
            cityName: "—",
            status: .ideal,
            outfitItems: [
                L10n.text("Куртка"),
                L10n.text("Кофта"),
                L10n.text("Шапка")
            ],
            ageLabel: L10n.text("малыша"),
            primaryWarning: nil,
            hasBlockingWarning: false,
            updatedAt: Date(),
            contextSummary: L10n.text("Облачно · Прогулочная коляска"),
            contextDetails: L10n.text("Облачно · Прогулочная коляска · Спокойно"),
            weatherSource: "Open-Meteo",
            weatherConfidence: L10n.text("Высокая уверенность")
        )
    }
}
