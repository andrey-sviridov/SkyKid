import SwiftUI

// MARK: - PersonalizationStatusCard

struct PersonalizationStatusCard: View {
    let summary: PersonalizationSummary
    let onReset: () -> Void

    @State private var showsResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            statusText

            if shouldShowProgress {
                ProgressView(
                    value: Double(summary.evidenceTowardAdjustment),
                    total: Double(PersonalizationPolicy.minimumConsistentSignals)
                )
                .tint(.purple)
            }

            Text("Один отзыв не меняет комплект. Сигналы ближе 4 часов считаются одной прогулкой; шаг ограничен 0,2 TOG, общий предел — ±1,0 TOG.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            if summary.hasAnyData {
                Button(role: .destructive) {
                    showsResetConfirmation = true
                } label: {
                    Label("Сбросить персонализацию", systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.purple.opacity(0.25), lineWidth: 1)
        )
        .confirmationDialog(
            "Сбросить все сохранённые наблюдения для этого ребёнка?",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Сбросить", role: .destructive, action: onReset)
            Button("Отмена", role: .cancel) {}
        }
    }

    // MARK: - Content

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text("Персонализация")
                    .font(.subheadline.weight(.semibold))
                Text("\(bandLabel) · \(scenarioLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if abs(summary.appliedOffset) > 0.000_1 {
                Text(offsetLabel)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.purple)
            }
        }
    }

    @ViewBuilder
    private var statusText: some View {
        if abs(summary.appliedOffset) > 0.000_1 {
            Text("Поправка применяется только к похожей температуре и активности. Оценка «Комфортно» подтверждает её и не стирает.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if summary.evidenceTowardAdjustment > 0 {
            Text("Собираем повторные наблюдения: \(summary.evidenceTowardAdjustment) из \(PersonalizationPolicy.minimumConsistentSignals).")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if summary.totalProfileObservationCount > 0 {
            Text("Есть наблюдения для других условий или противоречивые оценки. Для текущей прогулки поправки нет.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Пока используется базовый расчёт. После повторяемых оценок приложение аккуратно подстроит тепло одежды.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Presentation helpers

    private var shouldShowProgress: Bool {
        abs(summary.appliedOffset) <= 0.000_1 && summary.evidenceTowardAdjustment > 0
    }

    private var offsetLabel: String {
        let sign = summary.appliedOffset > 0 ? "+" : ""
        let offset = summary.appliedOffset.formatted(
            .number
                .precision(.fractionLength(1))
                .locale(L10n.locale)
        )
        return "\(sign)\(offset) TOG"
    }

    private var bandLabel: String {
        switch summary.temperatureBand {
        case .cold: return L10n.text("прохладно")
        case .mild: return L10n.text("умеренно")
        case .hot:  return L10n.text("жарко")
        }
    }

    private var scenarioLabel: String {
        switch summary.scenario {
        case .resting: return L10n.text("спокойная прогулка")
        case .active:  return L10n.text("активное движение")
        }
    }
}
