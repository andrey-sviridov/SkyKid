import SwiftUI

/// Снапшот текущей погоды: иконка + описание + температура на weather-градиенте.
struct WalkWeatherSnapshotCard: View {
    private let weather: NormalizedWeather?
    private let walk: ActiveWalk?

    init(weather: NormalizedWeather?) {
        self.weather = weather
        self.walk = nil
    }

    init(walk: ActiveWalk) {
        self.weather = nil
        self.walk = walk
    }

    var body: some View {
        let tone = SkyKidTheme.WeatherTone(weatherCode: weatherCode)
        HStack(spacing: 14) {
            Image(systemName: conditionIcon)
                .font(.system(size: 34))
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(tone.onColor)
                .frame(width: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tone.onColor)
                if let temperature {
                    Text(temperatureText(temperature: temperature, apparent: apparentTemperature))
                        .font(.caption)
                        .foregroundStyle(tone.onColor.opacity(0.85))
                }
                if let change = walk?.latestWeatherChange {
                    Text(change.message)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tone.onColor)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(SkyKidTheme.weatherGradient(for: weatherCode), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.25), lineWidth: 1))
        .accessibilityIdentifier("walk.weather")
    }

    private var snapshot: WeatherSnapshot? { walk?.latestWeatherSnapshot }
    private var weatherCode: Int? { weather?.weatherCode ?? snapshot?.weatherCode ?? walk?.weatherCode }
    private var temperature: Double? { weather?.temperature ?? snapshot?.temperature ?? walk?.weatherTemperature }
    private var apparentTemperature: Double? {
        weather?.apparentTemperature ?? snapshot?.apparentTemperature ?? walk?.apparentTemperature
    }
    private var conditionIcon: String {
        weather?.conditionIcon ?? walk?.weatherIconSymbol ?? "questionmark"
    }
    private var title: String {
        if walk?.latestWeatherChange != nil { return L10n.text("Условия изменились") }
        if walk != nil { return L10n.text("Условия на старте") }
        return weather?.conditionDescription ?? L10n.text("Нет данных о погоде")
    }

    private func temperatureText(temperature: Double, apparent: Double?) -> String {
        guard let apparent else {
            return L10n.format("%lld°C", Int(temperature.rounded()))
        }
        return L10n.format(
            "%lld° · ощущается %lld°C",
            Int(temperature.rounded()),
            Int(apparent.rounded())
        )
    }
}
