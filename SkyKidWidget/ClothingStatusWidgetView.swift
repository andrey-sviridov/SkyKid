import SwiftUI
import WidgetKit

// MARK: - Корневой вью: диспетчер по размеру виджета

struct ClothingStatusWidgetView: View {
    let entry: ClothingStatusEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Строка: город + эмодзи статуса
            HStack(alignment: .top) {
                Text(rec.cityName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(rec.status.emoji)
                    .font(.title3)
            }

            Spacer(minLength: 6)

            // Большая температура
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text("\(Int(rec.temperature.rounded()))°")
                    .font(.system(size: 38, weight: .thin, design: .rounded))
                    .foregroundStyle(rec.status.color)
                    .contentTransition(.numericText())
                Text("C")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Ощущаемая температура для ребёнка
            Text("Ребёнок: \(Int(rec.effectiveChildTemp.rounded()))°")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            // Бейдж статуса
            StatusBadgeView(status: rec.status)
                .padding(.bottom, 6)

            // Топ-2 вещи
            ForEach(rec.outfitItems.prefix(2), id: \.self) { item in
                Text("· \(item)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(
            LinearGradient(
                colors: [rec.status.color.opacity(0.18), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            for: .widget
        )
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

    var body: some View {
        HStack(spacing: 0) {

            // Левая колонка: температура и статус
            VStack(alignment: .leading, spacing: 3) {
                Text(rec.cityName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(alignment: .lastTextBaseline, spacing: 1) {
                    Text("\(Int(rec.temperature.rounded()))°")
                        .font(.system(size: 46, weight: .thin, design: .rounded))
                        .foregroundStyle(rec.status.color)
                    Text("C")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("Ощущается \(Int(rec.apparentTemperature.rounded()))°")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("Для \(rec.ageLabel): \(Int(rec.effectiveChildTemp.rounded()))°")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                StatusBadgeView(status: rec.status)

                if let warning = rec.status.safetyWarning {
                    Text(warning)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(rec.status.color)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Разделитель
            Rectangle()
                .fill(.secondary.opacity(0.25))
                .frame(width: 1)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)

            // Правая колонка: список одежды
            VStack(alignment: .leading, spacing: 5) {
                Text("Что надеть")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(rec.outfitItems.prefix(4), id: \.self) { item in
                    Label {
                        Text(item)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: sfSymbol(for: item))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(rec.status.color)
                            .frame(width: 16)
                    }
                    .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(
            LinearGradient(
                colors: [rec.status.color.opacity(0.12), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            for: .widget
        )
    }

    /// Подбирает SF Symbol для наименования вещи
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
                Text("\(Int(rec.temperature.rounded()))°")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(rec.status.color)
                    .contentTransition(.numericText())
            }
        }
        .containerBackground(.clear, for: .widget)
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

                Text("\(Int(rec.temperature.rounded()))°C")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // Три главные вещи
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

