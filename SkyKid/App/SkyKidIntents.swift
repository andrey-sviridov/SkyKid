import SwiftUI
import AppIntents

// MARK: - Error type

@available(iOS 17, *)
private struct SkyKidIntentError: LocalizedError {
    let errorDescription: String?
}

// MARK: - Intent

@available(iOS 17, *)
struct GetOutfitRecommendationIntent: AppIntent {

    static let title: LocalizedStringResource = "Что надеть"
    static let description = IntentDescription("Рекомендация одежды для ребёнка по текущей погоде")
    static let openAppWhenRun: Bool = false

    // @MainActor required — BiasStore.shared is @MainActor-isolated.
    // AppIntents dispatches perform() to the main actor automatically.
    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        guard let profile = AppGroup.loadProfile() else {
            throw SkyKidIntentError(
                errorDescription: "Создайте профиль ребёнка в приложении SkyKid"
            )
        }
        guard let cached = AppGroup.loadCachedWeather() else {
            throw SkyKidIntentError(
                errorDescription: "Откройте SkyKid и дождитесь загрузки погоды"
            )
        }

        // Reconstruct WeatherData from flat cache snapshot.
        // windDirection and humidity are not cached — default to 0.
        let weather = WeatherData(
            temperature:         cached.temperature,
            apparentTemperature: cached.apparentTemperature,
            humidity:            0,
            windSpeed:           cached.windSpeed,
            windDirection:       0,
            precipitation:       cached.precipitation,
            weatherCode:         cached.weatherCode
        )

        let bias   = BiasStore.shared.currentBias(for: profile, feelsLike: cached.apparentTemperature)
        let outfit = ClothingRecommendationEngine.recommend(
            weather:     weather,
            profile:     profile,
            learnedBias: bias
        )

        return .result(view: OutfitSnippetView(
            childName: profile.name,
            ageLabel:  profile.ageLabel,
            cityName:  cached.cityName,
            outfit:    outfit
        ))
    }
}

// MARK: - Snippet View

@available(iOS 17, *)
struct OutfitSnippetView: View {
    let childName: String
    let ageLabel: String
    let cityName: String
    let outfit: LayeredOutfit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            Divider().opacity(0.4)
            layersList
        }
        .padding(16)
    }

    // MARK: Header: имя + город · возраст · температура

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(childName)
                    .font(.headline)
                Text(ageLabel + " · " + cityName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(Int(outfit.effectiveTemp.rounded()))°")
                    .font(.system(size: 40, weight: .thin, design: .rounded))
                    .foregroundStyle(tempColor(outfit.effectiveTemp))
                    .contentTransition(.numericText())
                Text("для ребёнка")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Список вещей (топ-4)

    private var layersList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(outfit.allLayers.prefix(4)) { layer in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: layer.systemImage)
                            .font(.system(size: 12, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.blue)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(layer.name)
                            .font(.subheadline.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(layer.reason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: Temperature tint

    private func tempColor(_ t: Double) -> Color {
        switch t {
        case ..<0:    return .blue
        case 0..<10:  return Color(red: 0.28, green: 0.56, blue: 1.0)
        case 10..<20: return .green
        case 20..<28: return .orange
        default:      return .red
        }
    }
}

// AppShortcutsProvider намеренно не используется:
// фиксированные фразы с .applicationName проблематичны при локализации.
// Пользователь добавляет GetOutfitRecommendationIntent вручную
// через приложение Shortcuts с любой фразой на своём языке.
