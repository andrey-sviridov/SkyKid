import SwiftUI

// MARK: - WeatherView

struct WeatherView: View {
    let weather: NormalizedWeather
    let cityName: String
    var weatherUpdatedAt: Date?
    var currentProvider: WeatherProvider = .openMeteo
    var onProviderChange: ((WeatherProvider, String?) -> Void)?

    @State private var showProviderSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                cardsSection
            }
        }
        .skyKidBackground()
        .toolbar {
            providerToolbarItem
        }
        .sheet(isPresented: $showProviderSheet) {
            ProviderPickerView(
                current: currentProvider,
                onSelect: { provider, key in
                    onProviderChange?(provider, key)
                    showProviderSheet = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "location.fill")
                    .font(.caption2)
                Text(cityName)
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 12)

            Image(systemName: weather.conditionIcon)
                .font(.system(size: 76))
                .symbolRenderingMode(.multicolor)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
                .padding(.top, 10)

            Text("\(Int(weather.temperature.rounded()))°")
                .font(.system(size: 96, weight: .thin, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(weather.conditionDescription)
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            Text("Ощущается как \(Int(weather.apparentTemperature.rounded()))°")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            freshnessLine

            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
    }

    private var freshnessLine: some View {
        Group {
            if let weatherUpdatedAt {
                let freshness = WeatherFreshness(updatedAt: weatherUpdatedAt)
                VStack(spacing: 4) {
                    Label(
                        L10n.format(
                            "Обновлено в %@",
                            weatherUpdatedAt.formatted(.dateTime.hour().minute().locale(L10n.locale))
                        ),
                        systemImage: freshness.isStale
                            ? "exclamationmark.triangle"
                            : "checkmark.circle"
                    )
                    .foregroundStyle(freshness.isStale ? Color.orange : Color.secondary)

                    if freshness.isStale {
                        Text(L10n.text("Обновите погоду перед прогулкой"))
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption2)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(freshnessAccessibilityLabel(for: freshness))
                .accessibilityIdentifier("weather.freshness")
            }
        }
    }

    private func freshnessAccessibilityLabel(for freshness: WeatherFreshness) -> String {
        guard let weatherUpdatedAt else { return L10n.text("Нет данных") }
        let updated = L10n.format(
            "Обновлено в %@",
            weatherUpdatedAt.formatted(.dateTime.hour().minute().locale(L10n.locale))
        )
        return freshness.isStale
            ? "\(updated). \(L10n.text("Обновите погоду перед прогулкой"))"
            : updated
    }

    // MARK: - Cards (стеклянные карточки на градиенте)

    private var cardsSection: some View {
        VStack(spacing: 16) {
            if weather.confidence.level != .high {
                WeatherDataQualityCard(
                    source: weather.source,
                    confidence: weather.confidence
                )
            }
            if !weather.hourly.isEmpty {
                HourlyForecastCard(hourly: weather.hourly)
            }
            compactStats
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Compact stats

    private var compactStats: some View {
        HStack(spacing: 0) {
            MetricTile(
                icon: "wind",
                color: .teal,
                value: displayValue(
                    for: .windSpeed,
                    value: L10n.format("%lld м/с", Int(weather.windSpeed.rounded()))
                ),
                label: L10n.text("Ветер")
            )

            Divider().frame(height: 48)

            MetricTile(
                icon: "cloud.rain.fill",
                color: .indigo,
                value: displayValue(
                    for: .precipitation,
                    value: L10n.format("%.1f мм", weather.precipitation)
                ),
                label: L10n.text("Осадки")
            )
        }
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 18, padding: 0)
    }

    private func displayValue(for field: WeatherField, value: String) -> String {
        switch weather.status(for: field).quality {
        case .observed:
            return value
        case .derived, .estimated:
            return "~\(value)"
        case .unavailable:
            return L10n.text("Нет данных")
        }
    }

    // Источник остаётся доступным, но не занимает место в основном прогнозе.
    private var providerToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showProviderSheet = true
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel(L10n.text("Источник данных"))
        }
    }

}

// MARK: - Previews

#if DEBUG
#Preview("☀️ Ясно · 18°") {
    NavigationStack {
        WeatherView(weather: .mock, cityName: "Москва")
    }
}

#Preview("🌧 Дождь") {
    NavigationStack {
        WeatherView(weather: .mockRainy, cityName: "Санкт-Петербург")
    }
}

#Preview("❄️ Зима") {
    NavigationStack {
        WeatherView(weather: .mockWinter, cityName: "Сургут")
    }
}
#endif
