import SwiftUI

/// Чип вещи: мелкая иконка + название + TOG, с опциональной кнопкой удаления.
struct GarmentChip: View {
    let item: GarmentItem
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 7) {
            GarmentIconView(
                item: item,
                isSelected: true,
                accentColor: .blue,
                size: 26,
                shape: .roundedRectangle(6)
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(L10n.format("%.2f TOG", item.tog))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, onRemove == nil ? 12 : 6)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.primary.opacity(0.14), lineWidth: 1))
    }
}
