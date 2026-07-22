import SwiftUI

// MARK: - WeatherDataQualityCard

struct WeatherDataQualityCard: View {
    let source: WeatherSource
    let confidence: WeatherConfidence

    private var accent: Color {
        confidence.level == .low ? .orange : .indigo
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(confidence.level.label)
                        .font(.subheadline.weight(.semibold))
                    Text("Источник: \(source.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(confidence.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if confidence.issues.contains(where: { $0.field == .uvIndex }) {
                Label(
                    "UV не подтверждён — для солнца ориентируйтесь на более осторожный сценарий.",
                    systemImage: "sun.max.trianglebadge.exclamationmark"
                )
                .font(.caption2)
                .foregroundStyle(accent)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(accent.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
