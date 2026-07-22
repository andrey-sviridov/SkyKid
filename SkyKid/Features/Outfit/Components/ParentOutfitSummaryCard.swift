import SwiftUI

// MARK: - ParentOutfitSummaryCard

struct ParentOutfitSummaryCard: View {
    let summary: OutfitParentSummary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            answerRow(
                title: "Что надеть",
                text: summary.outfit,
                systemImage: "hanger",
                tint: .indigo
            )
            answerRow(
                title: "Почему",
                text: summary.reason,
                systemImage: "cloud.sun.fill",
                tint: .blue
            )
            answerRow(
                title: "Что проверить",
                text: summary.check,
                systemImage: "hand.raised.fill",
                tint: .teal
            )
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(confidenceTint.opacity(0.35), lineWidth: 1)
        )
        .accessibilityIdentifier("outfit.parentSummary")
    }

    // MARK: - Header

    private var header: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 10))

        return layout {
            VStack(alignment: .leading, spacing: 3) {
                Text("Рекомендация для ребёнка")
                    .font(.headline)
                Text(summary.ageContext)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            confidenceBadge
        }
    }

    private var confidenceBadge: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(confidenceLabel, systemImage: confidenceImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(confidenceTint)
            Text(summary.confidenceReason)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Уверенность: \(confidenceLabel). \(summary.confidenceReason)")
    }

    // MARK: - Answer rows

    private func answerRow(
        title: String,
        text: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 26)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Confidence presentation

    private var confidenceLabel: String {
        switch summary.confidence {
        case .high:   return "Высокая уверенность"
        case .medium: return "Средняя уверенность"
        case .low:    return "Низкая уверенность"
        }
    }

    private var confidenceImage: String {
        switch summary.confidence {
        case .high:   return "checkmark.seal.fill"
        case .medium: return "scope"
        case .low:    return "exclamationmark.triangle.fill"
        }
    }

    private var confidenceTint: Color {
        switch summary.confidence {
        case .high:   return .green
        case .medium: return .orange
        case .low:    return .red
        }
    }
}
