import SwiftUI

// MARK: - OutfitCheckHintCard

struct OutfitCheckHintCard: View {
    let hint: String
    var title = L10n.text("Проверьте после начала прогулки")

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.teal)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))

                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.teal.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
