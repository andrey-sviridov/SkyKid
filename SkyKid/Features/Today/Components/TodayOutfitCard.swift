import SwiftUI

// MARK: - TodayOutfitCard

struct TodayOutfitCard: View {
    let summary: OutfitParentSummary
    let warning: SafetyWarning?
    let onEditContext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.text("Что надеть"), systemImage: "hanger")
                .font(.headline)
                .foregroundStyle(.indigo)
            Text(summary.fit.label)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            garmentList
            Text(summary.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let warning {
                Label(warning.message, systemImage: warning.systemImage)
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(L10n.text("Изменить условия прогулки"), action: onEditContext)
                .frame(minHeight: 44)
            ShareLink(item: ShareOutfitComposer.compose(summary: summary)) {
                Label(L10n.text("Поделиться рекомендацией"), systemImage: "square.and.arrow.up")
            }
            .frame(minHeight: 44)
        }
        .padding(18)
        .glassCard(cornerRadius: 20, padding: 0)
        .accessibilityIdentifier("today.outfit")
    }

    // MARK: - Garments

    @ViewBuilder
    private var garmentList: some View {
        if summary.garments.isEmpty {
            Text(L10n.text("Дополнительные слои на корпус не нужны"))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(summary.garments) { garment in
                    RecommendedGarmentRow(garment: garment)
                }
            }
        }
    }
}
