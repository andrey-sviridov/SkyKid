import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

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
                    VStack(alignment: .leading, spacing: 8) {
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
                        quickMarkButtons(state: context.state, foreground: .primary)
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

            quickMarkButtons(state: context.state, foreground: tone.onColor)
        }
        .padding(16)
        .widgetURL(URL(string: "skykid://walk"))
        .background(weatherGradient(for: context.attributes.weatherCode))
    }
}

// MARK: - Quick mark buttons
// Общие для Lock Screen и развёрнутого Dynamic Island: сон/подъём и
// люлька — переключатели (подпись/иконка зависят от текущего состояния),
// отметка — фиксированная кнопка. Растянуты на всю ширину, единый стиль
// (заливка/обводка от `foreground`) — контраст гарантирован по построению,
// а не подобран под конкретную погоду/фон.

@ViewBuilder
private func quickMarkButtons(state: WalkActivityAttributes.ContentState, foreground: Color) -> some View {
    let isBusy = state.pendingControl != nil
    HStack(spacing: 8) {
        quickMarkButton(
            WalkSleepToggleIntent(),
            title: state.isSleeping ? L10n.text("Проснулся") : L10n.text("Уснул"),
            icon: state.isSleeping ? "sun.max.fill" : "moon.zzz.fill",
            foreground: foreground,
            isPending: state.pendingControl == .sleep,
            isBusy: isBusy
        )
        quickMarkButton(
            WalkBassinetteToggleIntent(),
            title: state.isBassinetteOpen ? L10n.text("Закрыли") : L10n.text("Открыли"),
            icon: state.isBassinetteOpen ? "tray.and.arrow.down.fill" : "tray.and.arrow.up.fill",
            foreground: foreground,
            isPending: state.pendingControl == .bassinette,
            isBusy: isBusy
        )
        quickMarkButton(
            WalkCheckpointIntent(),
            title: L10n.text("Отметка"),
            icon: "flag.fill",
            foreground: foreground,
            isPending: state.pendingControl == .checkpoint,
            isBusy: isBusy
        )
    }
    .frame(maxWidth: .infinity)
}

/// `isPending` — именно эта кнопка сейчас выполняется (показывает спиннер),
/// `isBusy` — какая-то из трёх выполняется (весь ряд затемнён и недоступен).
private func quickMarkButton<I: LiveActivityIntent>(
    _ intent: I, title: String, icon: String, foreground: Color, isPending: Bool, isBusy: Bool
) -> some View {
    Button(intent: intent) {
        VStack(spacing: 3) {
            if isPending {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(foreground)
            } else {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
            }
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .foregroundStyle(foreground)
        .opacity(isBusy && !isPending ? 0.45 : 1)
        .background(foreground.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(foreground.opacity(0.3), lineWidth: 1))
    }
    .buttonStyle(.plain)
    .disabled(isBusy)
}
