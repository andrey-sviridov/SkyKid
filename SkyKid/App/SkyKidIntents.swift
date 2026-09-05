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

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let store = AppGroupRecommendationSnapshotStore()
        guard let snapshot = store.load() else {
            throw SkyKidIntentError(
                errorDescription: "Откройте SkyKid, обновите погоду и проверьте самочувствие ребёнка перед выходом."
            )
        }
        guard snapshot.isFresh() else {
            let updated = snapshot.generatedAt.formatted(
                .dateTime.day().month(.abbreviated).hour().minute()
            )
            let conditions = snapshot.context.map { " (\($0.shortSummary))" } ?? ""
            throw SkyKidIntentError(
                errorDescription: "Последняя рекомендация от \(updated)\(conditions) устарела. Откройте SkyKid и обновите погоду"
            )
        }

        let recommendation = snapshot.recommendation
        return .result(view: OutfitSnippetView(
            childName: snapshot.childName,
            ageLabel: snapshot.childAgeLabel,
            cityName: snapshot.cityName,
            updatedAt: snapshot.generatedAt,
            context: snapshot.context,
            temperatures: recommendation.temperatures,
            layers: recommendation.blockingWarning == nil
                ? recommendation.allDisplayLayers
                : [],
            warning: recommendation.primarySafetyWarning?.message,
            blocksScenario: recommendation.blockingWarning != nil
        ))
    }
}

// MARK: - Snippet View

@available(iOS 17, *)
struct OutfitSnippetView: View {
    let childName: String
    let ageLabel: String
    let cityName: String
    let updatedAt: Date
    let context: RecommendationSnapshotContext?
    let temperatures: OutfitTemperatures
    let layers: [RecommendedLayer]
    let warning: String?
    let blocksScenario: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            if let warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if blocksScenario {
                Text("Одежда для прогулки не показывается, пока действует ограничение.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Divider().opacity(0.4)
                layersList
            }
        }
        .padding(16)
    }

    // MARK: Header

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 4) {
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
                    Text("\(Int(temperatures.microclimate.rounded()))°")
                        .font(.system(size: 40, weight: .thin, design: .rounded))
                        .foregroundStyle(tempColor(temperatures.effective))
                        .contentTransition(.numericText())
                    Text("в микроклимате")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text("На улице \(Int(temperatures.outside.rounded()))° · ощущается \(Int(temperatures.apparent.rounded()))° · эффективная \(Int(temperatures.effective.rounded()))°")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .accessibilityHidden(true)
                Text("Обновлено")
                Text(updatedAt, style: .time)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if let context {
                Text("\(context.fullSummary) · \(context.weatherSource) · \(context.weatherConfidence)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Список вещей (топ-4)

    private var layersList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(layers.prefix(4)), id: \.name) { layer in
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
