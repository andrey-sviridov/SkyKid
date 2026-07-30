import SwiftUI

struct GenderButton: View {
    let gender: ChildGender
    let isSelected: Bool
    let action: () -> Void
    private var accent: Color { gender == .boy ? .blue : .pink }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(gender.emoji)
                Text(gender.label).font(.body.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 22).padding(.vertical, 11)
            .background(isSelected ? accent.opacity(0.14) : Color.primary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? accent : Color.clear, lineWidth: 1.5))
            .foregroundStyle(isSelected ? accent : .primary)
        }
        .buttonStyle(.plain)
    }
}
