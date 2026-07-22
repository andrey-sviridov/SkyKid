import SwiftUI

// MARK: - StableThermalTraitRow

struct StableThermalTraitRow: View {
    let trait: StableThermalTrait
    let isSelected: Bool
    let isLast: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: trait.systemImage)
                    .frame(width: 24)
                    .foregroundStyle(isSelected ? .indigo : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(trait.label)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text(trait.note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.indigo : Color.secondary.opacity(0.45))
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if !isLast {
            Divider().padding(.leading, 36)
        }
    }
}
