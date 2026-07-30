import SwiftUI

/// Свой bottom sheet выбора самочувствия малыша при завершении прогулки —
/// замена системного confirmationDialog (см. комментарий в ActiveWalkView.body).
struct ComfortLevelSheet: View {
    var onSelect: (BabyComfortLevel) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Как чувствовал себя малыш?")
                .font(.headline)
                .padding(.top, 8)

            VStack(spacing: 10) {
                ForEach(BabyComfortLevel.allCases) { level in
                    Button {
                        onSelect(level)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: level.icon)
                                .font(.title3)
                                .frame(width: 24)
                            Text(level.label)
                                .font(.body.weight(.medium))
                            Spacer()
                        }
                        .foregroundStyle(level.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(level.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(level.color.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Отмена") { dismiss() }
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }
}
