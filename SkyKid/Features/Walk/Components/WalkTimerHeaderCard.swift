import SwiftUI

// MARK: - WalkTimerHeaderCard

/// Шапка прогулки: погода на момент старта, живой таймер и остаток до цели,
/// всё на weather-градиенте.
///
/// Общая для своего экрана прогулки и для просмотра прогулки второго
/// родителя — поэтому принимает `ActiveWalk` и не знает ни про стор, ни про
/// то, можно ли что-то менять.
struct WalkTimerHeaderCard: View {
    let walk: ActiveWalk
    var weather: NormalizedWeather?
    /// Имя того, кто ведёт прогулку. `nil` — это своя прогулка, подписывать нечего.
    var ownerName: String?

    private var tone: SkyKidTheme.WeatherTone {
        SkyKidTheme.WeatherTone(weatherCode: walk.weatherCode)
    }

    var body: some View {
        VStack(spacing: 12) {
            weatherLine

            if let ownerName {
                Text(ownerName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(tone.onColor.opacity(0.9))
            }

            ElapsedTimeText(since: walk.startDate, size: .hero)
                .foregroundStyle(tone.onColor)

            if let planned = walk.plannedDurationMinutes {
                CountdownLabel(
                    target: walk.startDate.addingTimeInterval(TimeInterval(planned * 60)),
                    ongoingText: L10n.text("осталось"),
                    finishedText: L10n.text("цель достигнута")
                )
                .foregroundStyle(tone.onColor.opacity(0.9))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            SkyKidTheme.weatherGradient(for: walk.weatherCode),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.28), lineWidth: 1))
        .shadow(color: tone.colors.first?.opacity(0.35) ?? .clear, radius: 12, y: 4)
    }

    private var weatherLine: some View {
        HStack(spacing: 10) {
            Image(systemName: weather?.conditionIcon ?? "cloud.fill")
                .font(.title2)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(tone.onColor)

            Text(L10n.format("%lld°C", Int(walk.weatherTemperature.rounded())))
                .font(.headline)
                .foregroundStyle(tone.onColor)

            Spacer()

            if let description = weather?.conditionDescription {
                Text(description)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(tone.onColor.opacity(0.9))
            }
        }
    }
}
