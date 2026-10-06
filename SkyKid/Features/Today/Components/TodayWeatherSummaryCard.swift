import SwiftUI

// MARK: - TodayWeatherSummaryCard

struct TodayWeatherSummaryCard: View {
    let weather: NormalizedWeather
    let cityName: String
    let updatedAt: Date?

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: weather.conditionIcon)
                .font(.largeTitle)
                .symbolRenderingMode(.multicolor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(cityName)
                    .font(.headline)
                Text(L10n.format("%@ · ощущается как %lld°", weather.conditionDescription, Int(weather.apparentTemperature.rounded())))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let updatedAt {
                    Text(L10n.format("Обновлено в %@", updatedAt.formatted(.dateTime.hour().minute().locale(L10n.locale))))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)
            Text("\(Int(weather.temperature.rounded()))°")
                .font(.system(.largeTitle, design: .rounded).weight(.medium))
                .monospacedDigit()
        }
        .padding(18)
        .glassCard(cornerRadius: 20, padding: 0)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today.weather")
    }
}
