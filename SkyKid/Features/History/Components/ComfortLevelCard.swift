import SwiftUI

struct ComfortLevelCard: View {
    @Binding var selected: BabyComfortLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Как чувствовал себя малыш?", systemImage: "hand.raised.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Проверьте живот или заднюю поверхность шеи: кожа должна быть тёплой и сухой. Холодные кисти и стопы сами по себе не означают, что ребёнок замёрз.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 10) {
                ForEach(BabyComfortLevel.allCases) { level in
                    let isSelected = selected == level
                    let color = level.color
                    Button { withAnimation(.spring(response: 0.25)) { selected = level } } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isSelected ? color.opacity(0.18) : Color.primary.opacity(0.07))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(isSelected ? color : Color.clear, lineWidth: 1.5)
                                    )
                                    .frame(height: 52)
                                Image(systemName: level.icon)
                                    .font(.system(size: 22))
                                    .foregroundStyle(isSelected ? color : .secondary)
                            }
                            Text(level.label)
                                .font(.caption2.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? color : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }
}
