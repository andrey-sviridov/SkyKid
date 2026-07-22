import SwiftUI

// MARK: - OutfitCalculationDetailsCard

struct OutfitCalculationDetailsCard: View {
    let recommendation: OutfitRecommendation
    let weather: NormalizedWeather

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            toggle

            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)

                VStack(spacing: 14) {
                    temperatureSection

                    if let fit = recommendation.fit {
                        OutfitFitCard(fit: fit)
                    }

                    traceSection
                }
                .padding(14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .accessibilityIdentifier("outfit.calculationDetails")
    }

    // MARK: - Toggle

    private var toggle: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "function")
                    .foregroundStyle(.indigo)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Как получилась рекомендация")
                        .font(.subheadline.weight(.semibold))
                    Text(isExpanded ? "Скрыть температуры и этапы" : "Показать температуры и этапы")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .contentShape(Rectangle())
            .padding(14)
            .frame(minHeight: 52)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isExpanded ? "Развёрнуто" : "Свёрнуто")
        .accessibilityHint(isExpanded ? "Скрывает подробный расчёт" : "Показывает подробный расчёт")
    }

    // MARK: - Temperatures

    private var temperatureSection: some View {
        VStack(spacing: 9) {
            detailRow("На улице", value: recommendation.temperatures.outside, unit: "°C")
            detailRow("По данным сервиса ощущается", value: recommendation.temperatures.apparent, unit: "°C")
            detailRow("После погоды", value: recommendation.temperatures.effective, unit: "°C")
            detailRow("В условиях ребёнка", value: recommendation.temperatures.microclimate, unit: "°C")

            Divider()

            HStack {
                Text("Источник погоды")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(weather.source.displayName)
                    .multilineTextAlignment(.trailing)
            }
            .font(.caption)

            HStack {
                Text("Качество данных")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(weather.confidence.level.label)
                    .multilineTextAlignment(.trailing)
            }
            .font(.caption)
        }
        .accessibilityElement(children: .contain)
    }

    private func detailRow(_ title: String, value: Double, unit: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value.formatted(.number.precision(.fractionLength(0))))\(unit)")
                .monospacedDigit()
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Trace

    private var traceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Этапы расчёта")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(recommendation.explanation.enumerated()), id: \.offset) { _, step in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(step.label)
                            .font(.caption)
                        Spacer(minLength: 8)
                        Text("\(step.value.formatted(.number.precision(.fractionLength(1)))) \(step.unit)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if let note = step.note {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
