import SwiftUI

// MARK: - OutfitSafetyWarningsSection

struct OutfitSafetyWarningsSection: View {
    let warnings: [SafetyWarning]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                warningCard(warning)
            }
        }
    }
}

// MARK: - Warning Card

private extension OutfitSafetyWarningsSection {
    func warningCard(_ warning: SafetyWarning) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: warning.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(warning.severity.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(warning.severity.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(warning.severity.tint)

                Text(warning.message)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(warning.severity.tint.opacity(0.4), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Severity Appearance

private extension SafetyWarning.Severity {
    var label: String {
        switch self {
        case .info:
            return L10n.text("Подсказка")
        case .caution:
            return L10n.text("Осторожно")
        case .danger:
            return L10n.text("Исправьте до выхода")
        case .blocked:
            return L10n.text("Прогулку отмените")
        }
    }

    var tint: Color {
        switch self {
        case .info:
            return .blue
        case .caution:
            return .orange
        case .danger:
            return .red
        case .blocked:
            return .red
        }
    }
}
