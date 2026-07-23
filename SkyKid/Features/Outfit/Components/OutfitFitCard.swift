import SwiftUI

// MARK: - OutfitFitCard

struct OutfitFitCard: View {
    let fit: OutfitFit

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: presentation.systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(presentation.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(deltaLabel)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(presentation.color)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(presentation.color.opacity(0.3), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Presentation

    private var detail: String {
        L10n.format(
            "Комплект %.1f TOG · цель %.1f TOG",
            fit.effectiveTOG,
            fit.targetTOG
        )
    }

    private var deltaLabel: String {
        String(format: "%+.1f", fit.deltaTOG)
    }

    private var presentation: Presentation {
        switch fit.confidence {
        case .high:
            return Presentation(
                title: L10n.text("Комплект подходит точно"),
                systemImage: "checkmark.seal.fill",
                color: .green
            )
        case .medium:
            return Presentation(
                title: L10n.text("Комплект близок к цели"),
                systemImage: "scope",
                color: .orange
            )
        case .low:
            return Presentation(
                title: L10n.text("Гардероб ограничивает точность"),
                systemImage: "exclamationmark.triangle.fill",
                color: .red
            )
        }
    }

    private struct Presentation {
        let title: String
        let systemImage: String
        let color: Color
    }
}
