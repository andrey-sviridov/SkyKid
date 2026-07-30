import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - WalkLiveActivityWidget
// Live Activity для идущей прогулки: банер на экране блокировки + Dynamic
// Island. Рендерится системой из статичного снапшота — анимация переливания
// (используемая в кастомном таб-баре приложения) здесь не воспроизводится,
// фон — статичный weatherGradient.

struct WalkLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkActivityAttributes.self) { context in
            WalkLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.attributes.weatherIconSymbol ?? "figure.walk")
                            .symbolRenderingMode(.multicolor)
                        Text("\(Int(context.attributes.weatherTemperature.rounded()))°")
                            .font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.startDate, style: .timer)
                        .font(.headline)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.format("Одежда: %lld · TOG %.1f",
                                         context.state.outfitCount,
                                         context.state.effectiveTOG))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let title = context.state.lastEventTitle {
                            Label(title, systemImage: context.state.lastEventIcon ?? "flag.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.walk")
            } compactTrailing: {
                Text(context.attributes.startDate, style: .timer)
                    .monospacedDigit()
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "figure.walk")
            }
            .widgetURL(URL(string: "skykid://walk"))
        }
    }
}

// MARK: - WalkLockScreenView

private struct WalkLockScreenView: View {
    let context: ActivityViewContext<WalkActivityAttributes>

    var body: some View {
        let tone = WeatherTone(weatherCode: context.attributes.weatherCode)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: context.attributes.weatherIconSymbol ?? "figure.walk")
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(context.attributes.weatherDescription ?? L10n.text("Прогулка идёт"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tone.onColor.opacity(0.9))
                    Text(L10n.format("%lld°C", Int(context.attributes.weatherTemperature.rounded())))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(tone.onColor)
                }
                Spacer()
                Text(context.attributes.startDate, style: .timer)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tone.onColor)
            }

            HStack(spacing: 12) {
                Label(
                    L10n.format("Одежда: %lld · TOG %.1f", context.state.outfitCount, context.state.effectiveTOG),
                    systemImage: "hanger"
                )
                .font(.caption2)
                .foregroundStyle(tone.onColor.opacity(0.85))

                if let title = context.state.lastEventTitle {
                    Label(title, systemImage: context.state.lastEventIcon ?? "flag.fill")
                        .font(.caption2)
                        .foregroundStyle(tone.onColor.opacity(0.85))
                }
            }
        }
        .padding(16)
        .widgetURL(URL(string: "skykid://walk"))
        .background(weatherGradient(for: context.attributes.weatherCode))
    }
}
