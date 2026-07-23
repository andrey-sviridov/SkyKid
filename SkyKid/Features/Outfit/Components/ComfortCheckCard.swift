import SwiftUI

// MARK: - ComfortCheckCard

/// A neutral observation hint for the legacy constructor.
/// It deliberately does not imply endorsement by a pediatrician.
struct ComfortCheckCard: View {

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            icon
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.teal.opacity(0.09),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Components

private extension ComfortCheckCard {
    var icon: some View {
        Image(systemName: "hand.raised.circle.fill")
            .font(.title3)
            .symbolRenderingMode(.multicolor)
            .foregroundStyle(.teal)
            .accessibilityHidden(true)
    }

    var content: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Как проверить комфорт")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.teal)

            Text(
                "Проверьте живот или заднюю поверхность шеи: "
                    + "кожа должна быть тёплой и сухой. "
                    + "Прохладные кисти и стопы сами по себе — не признак холода."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
