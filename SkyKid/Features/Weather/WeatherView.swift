import SwiftUI

// MARK: - WeatherView

struct WeatherView: View {
    let weather: NormalizedWeather
    let cityName: String
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

            // Attribution chip — не навязчивый, но доступный
            Button {
                showProviderSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: weather.source.systemImage)
                        .font(.system(size: 9, weight: .medium))
                    Text(weather.source.displayName)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
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
            statsGrid
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            StatCard(icon: "wind", color: .teal, title: L10n.text("Ветер"),
                     value: displayValue(
                        for: .windSpeed,
                        value: L10n.format(
                            "%lld м/с",
                            Int(weather.windSpeed.rounded())
                        )
                     ))
            StatCard(
                icon: "location.north.fill",
                color: .orange,
                title: L10n.text("Направление"),
                     value: displayValue(for: .windDirection, value: weather.windDirectionLabel),
                iconRotation: Double(weather.windDirection)
            )
            StatCard(icon: "humidity.fill", color: .blue, title: L10n.text("Влажность"),
                     value: displayValue(for: .humidity, value: "\(weather.humidity)%"))
            StatCard(icon: "cloud.rain.fill", color: .indigo, title: L10n.text("Осадки"),
                     value: displayValue(
                        for: .precipitation,
                        value: L10n.format("%.1f мм", weather.precipitation)
                     ))
        }
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
