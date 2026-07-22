import SwiftUI
import WidgetKit

// MARK: - Корневой вью: диспетчер по размеру виджета

struct ClothingStatusWidgetView: View {
    let entry: ClothingStatusEntry

    @Environment(\.widgetFamily) private var family

    @ViewBuilder
    var body: some View {
        if entry.requiresRefresh {
            WidgetRefreshRequiredView(
                family: family,
                lastUpdatedAt: entry.lastUpdatedAt,
                contextSummary: entry.recommendation.contextSummary
            )
        } else {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .accessoryCircular:
                CircularAccessoryView(entry: entry)
            case .accessoryRectangular:
                RectangularAccessoryView(entry: entry)
            default:
                SmallWidgetView(entry: entry)
            }
        }
    }
}

// MARK: - Refresh required

private struct WidgetRefreshRequiredView: View {
    let family: WidgetFamily
    let lastUpdatedAt: Date?
    let contextSummary: String

    var body: some View {
        VStack(spacing: family == .accessoryCircular ? 2 : 8) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(family == .accessoryCircular ? .title3 : .title)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
            if family != .accessoryCircular {
                Text("Откройте SkyKid")
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                if let lastUpdatedAt {
                    HStack(spacing: 3) {
                        Text("Последние данные:")
                        Text(lastUpdatedAt, style: .time)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    Text(contextSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                } else {
                    Text("Нужна свежая погода")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Домашний экран: маленький (2×2)
//
//  ┌──────────────────┐
//  │  Москва      😊  │
//  │  12°C            │
//  │  Ребёнок: 9°     │
//  │  ● Идеально      │
//  │  · Куртка        │
//  │  · Кофта         │
//  └──────────────────┘

struct SmallWidgetView: View {
    let entry: ClothingStatusEntry
    private var rec: WidgetOutfitRecommendation { entry.recommendation }
    private var isExtreme: Bool {
        rec.hasBlockingWarning
            || rec.status == .extremeHeat
            || rec.status == .extremeCold
    }

    var body: some View {
        ZStack {
            if isExtreme {
                smallExtremeView
            } else {
                smallNormalView
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(
            LinearGradient(
                colors: isExtreme
                    ? [rec.alertColor.opacity(0.35), rec.alertColor.opacity(0.08)]
                    : [rec.status.color.opacity(0.18), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            for: .widget
        )
    }

    // Обычный вид
    private var smallNormalView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(rec.cityName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 1) {
                    Image(systemName: rec.status.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(rec.status.color)
                        .symbolRenderingMode(.hierarchical)
                    Text(rec.updatedAt, style: .time)
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 6)

            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text("\(Int(rec.outsideTemperature.rounded()))°")
                    .font(.system(size: 38, weight: .thin, design: .rounded))
                    .foregroundStyle(rec.status.color)
                    .contentTransition(.numericText())
                Text("C")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Микроклимат: \(Int(rec.microclimateTemperature.rounded()))°")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            Text(rec.contextSummary)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.bottom, 4)

            StatusBadgeView(status: rec.status)
                .padding(.bottom, 6)

            ForEach(rec.outfitItems.prefix(2), id: \.self) { item in
                Text("· \(item)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    // Баннер опасности — вся площадь виджета
    private var smallExtremeView: some View {
        VStack(alignment: .center, spacing: 6) {
            Image(systemName: rec.alertSystemImage)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(rec.alertColor)

            Text(rec.alertLabel)
                .font(.caption.weight(.black))
                .foregroundStyle(rec.alertColor)
                .multilineTextAlignment(.center)

            if let warning = rec.primaryWarning ?? rec.status.defaultSafetyWarning {
                Text(warning)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(rec.alertColor.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("\(Int(rec.outsideTemperature.rounded()))°C")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Домашний экран: средний (4×2)
//
//  ┌──────────────────────────────────────┐
//  │  Москва              │  Что надеть   │
//  │  12°C                │  ☁ Куртка     │
//  │  Ощущается: 9°       │  👕 Кофта     │
//  │  Для малыша (8 мес)  │  🧣 Шапка     │
//  │  ● Идеально          │  🧤 Перчатки  │
//  └──────────────────────────────────────┘

struct MediumWidgetView: View {
    let entry: ClothingStatusEntry
    private var rec: WidgetOutfitRecommendation { entry.recommendation }
    private var isExtreme: Bool {
        rec.hasBlockingWarning
            || rec.status == .extremeHeat
            || rec.status == .extremeCold
    }

    var body: some View {
        HStack(spacing: 0) {

            // Левая колонка: температура, статус (одинакова в обоих режимах)
            leftColumn
                .frame(maxWidth: .infinity, alignment: .leading)

            // Разделитель
            Rectangle()
                .fill(.secondary.opacity(0.25))
                .frame(width: 1)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)

            // Правая колонка: либо список одежды, либо баннер опасности
            if isExtreme {
                mediumExtremeBanner
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                outfitColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(
            LinearGradient(
                colors: isExtreme
                    ? [rec.alertColor.opacity(0.28), rec.alertColor.opacity(0.06)]
                    : [rec.status.color.opacity(0.12), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            for: .widget
        )
    }

    // MARK: - Колонки

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(rec.cityName)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "clock")
                    .accessibilityHidden(true)
                Text(rec.updatedAt, style: .time)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text("\(Int(rec.outsideTemperature.rounded()))°")
                    .font(.system(size: 46, weight: .thin, design: .rounded))
                    .foregroundStyle(rec.status.color)
                Text("C")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Микроклимат: \(Int(rec.microclimateTemperature.rounded()))°")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(rec.contextSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 4)

            StatusBadgeView(status: rec.status)
        }
    }

    private var outfitColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Что надеть")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(rec.outfitItems.prefix(4), id: \.self) { item in
                Label {
                    Text(item).lineLimit(1)
                } icon: {
                    Image(systemName: sfSymbol(for: item))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(rec.status.color)
                        .frame(width: 16)
                }
                .font(.caption)
            }
        }
    }

    // Баннер экстремального риска — правая колонка
    private var mediumExtremeBanner: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: rec.alertSystemImage)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(rec.alertColor)

            Text(rec.alertLabel)
                .font(.caption.weight(.black))
                .foregroundStyle(rec.alertColor)
                .multilineTextAlignment(.center)

            if let warning = rec.primaryWarning ?? rec.status.defaultSafetyWarning {
                Text(warning)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(rec.alertColor.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 4)
    }

    // MARK: - SF Symbol lookup

    private func sfSymbol(for item: String) -> String {
        let lower = item.lowercased()
        if lower.contains("куртк") || lower.contains("комбез") || lower.contains("ветровк") { return "cloud.fill" }
        if lower.contains("шапк") || lower.contains("шапочк")    { return "moon.fill" }
        if lower.contains("перчат") || lower.contains("варежк")   { return "hand.raised.fill" }
        if lower.contains("сапог") || lower.contains("ботинк")    { return "shoe.fill" }
        if lower.contains("термо")                                 { return "thermometer.medium" }
        if lower.contains("дождев")                               { return "cloud.rain.fill" }
        if lower.contains("кофт") || lower.contains("футболк")    { return "tshirt.fill" }
        if lower.contains("панамк") || lower.contains("кепк")     { return "sun.max.fill" }
        return "checkmark.circle.fill"
    }
}

// MARK: - Экран блокировки: круглый (Circular)
//
//     ╔════╗
//     ║ 🧥 ║
//     ║ 12°║
//     ╚════╝

struct CircularAccessoryView: View {
    let entry: ClothingStatusEntry
    private var rec: WidgetOutfitRecommendation { entry.recommendation }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: rec.status.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(rec.status.color)
                Text("\(Int(rec.outsideTemperature.rounded()))°")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(rec.status.color)
                    .contentTransition(.numericText())
            }
        }
        .containerBackground(.clear, for: .widget)
        .accessibilityLabel(
            "\(rec.status.label), \(Int(rec.outsideTemperature.rounded())) градусов, обновлено \(rec.updatedAt.formatted(date: .omitted, time: .shortened)), \(rec.contextDetails)"
        )
    }
}

// MARK: - Экран блокировки: прямоугольный (Rectangular)
//
//  ┌──────────────────────────────────┐
//  │  ✅ Идеально              12°C   │
//  │  Куртка · Кофта · Шапка         │
//  └──────────────────────────────────┘

struct RectangularAccessoryView: View {
    let entry: ClothingStatusEntry
    private var rec: WidgetOutfitRecommendation { entry.recommendation }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {

            // Строка: статус + температура
            HStack(spacing: 5) {
                Image(systemName: rec.status.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(rec.status.color)

                Text(rec.status.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(rec.status.color)
                    .lineLimit(1)

                Spacer(minLength: 0)

                HStack(spacing: 3) {
                    Text("\(Int(rec.outsideTemperature.rounded()))°C ·")
                    Text(rec.updatedAt, style: .time)
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            }

            Text(rec.contextSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(rec.topItemsSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Общий компонент: бейдж статуса

struct StatusBadgeView: View {
    let status: ClothingWidgetStatus

    var body: some View {
        Label {
            Text(status.label)
                .lineLimit(1)
        } icon: {
            Image(systemName: status.systemImage)
                .symbolRenderingMode(.hierarchical)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(status.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(status.color.opacity(0.15), in: Capsule())
    }
}

// MARK: - Превью

#Preview("Маленький", as: .systemSmall) {
    ClothingStatusWidget()
} timeline: {
    ClothingStatusEntry.placeholder
}

#Preview("Средний", as: .systemMedium) {
    ClothingStatusWidget()
} timeline: {
    ClothingStatusEntry.placeholder
}

#Preview("Circular", as: .accessoryCircular) {
    ClothingStatusLockScreenWidget()
} timeline: {
    ClothingStatusEntry.placeholder
}

#Preview("Rectangular", as: .accessoryRectangular) {
    ClothingStatusLockScreenWidget()
} timeline: {
    ClothingStatusEntry.placeholder
}
// MARK: - Widgets

import WidgetKit

struct ClothingStatusWidget: Widget {
    let kind: String = "ClothingStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClothingStatusProvider()) { entry in
            ClothingStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Одежда для ребёнка")
        .description("Рекомендации по одежде с учётом погоды и возраста.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ClothingStatusLockScreenWidget: Widget {
    let kind: String = "ClothingStatusLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClothingStatusProvider()) { entry in
            ClothingStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Одежда — Экран блокировки")
        .description("Краткие рекомендации для экрана блокировки.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}
