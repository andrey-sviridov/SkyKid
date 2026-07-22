import SwiftUI

// MARK: - WalkContextSummaryCard

struct WalkContextSummaryCard: View {
    let context: WalkContext
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                Image(systemName: "figure.walk.motion")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.indigo)
                    .frame(width: 38, height: 38)
                    .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Собираемся гулять")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.indigo)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 17))
            .overlay(
                RoundedRectangle(cornerRadius: 17)
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
