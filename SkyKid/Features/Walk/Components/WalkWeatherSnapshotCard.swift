import SwiftUI

/// Снапшот текущей погоды: иконка + описание + температура на weather-градиенте.
struct WalkWeatherSnapshotCard: View {
    let weather: NormalizedWeather?

    var body: some View {
        let tone = SkyKidTheme.WeatherTone(weatherCode: weather?.weatherCode)
        HStack(spacing: 14) {
            Image(systemName: weather?.conditionIcon ?? "questionmark")
                .font(.system(size: 34))
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(tone.onColor)
                .frame(width: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(weather?.conditionDescription ?? L10n.text("Нет данных о погоде"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tone.onColor)
                if let weather {
                    Text(L10n.format("%lld° · ощущается %lld°C",
                                     Int(weather.temperature.rounded()),
                                     Int(weather.apparentTemperature.rounded())))
                        .font(.caption)
                        .foregroundStyle(tone.onColor.opacity(0.85))
                }
            }
            Spacer()
        }
        .padding(16)
        .background(SkyKidTheme.weatherGradient(for: weather?.weatherCode), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.25), lineWidth: 1))
    }
}
