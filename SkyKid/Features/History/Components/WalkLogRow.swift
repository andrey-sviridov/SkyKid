import SwiftUI

struct WalkLogRow: View {
    let log: WalkLog

    private var comfortColor: Color { log.comfortLevel.color }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(comfortColor.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: log.comfortLevel.icon)
                    .font(.system(size: 19))
                    .foregroundStyle(comfortColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(log.date, format: .dateTime.day().month(.abbreviated).hour().minute())
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    durationBadge
                }

                Label(log.comfortLevel.label, systemImage: log.comfortLevel.icon)
                    .foregroundStyle(comfortColor)
                    .font(.caption)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.10), lineWidth: 1))
    }

    private var durationBadge: some View {
        Text(WalkDurationFormatter.string(minutes: log.durationMinutes))
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.07), in: Capsule())
    }

}
