import SwiftUI

// MARK: - WalkContextSummaryCard

struct WalkContextSummaryCard: View {
    let context: WalkContext
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 10) {
                Image(systemName: "figure.walk.motion")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)
                    .frame(width: 28, height: 28)
                    .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Условия прогулки")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundStyle(.indigo)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.indigo.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Условия прогулки. \(summary)")
        .accessibilityHint("Изменить самочувствие, активность и условия прогулки")
    }

    private var summary: String {
        [
            context.healthStatus.label,
            context.activityLevel.label,
            context.transportMode.walkLabel,
            context.walkType.detail
        ].joined(separator: " · ")
    }
}
