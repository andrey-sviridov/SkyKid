import SwiftUI

/// Вход в ручной «Конструктор одежды» (перенесён из отдельной вкладки).
struct OutfitConstructorLinkCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "slider.horizontal.3")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Конструктор одежды")
                    .font(.subheadline.weight(.semibold))
                Text("Соберите комплект вручную и проверьте риск перегрева")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }
}
