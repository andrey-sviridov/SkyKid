import SwiftUI

struct WalkEventRow: View {
    let event: WalkEvent
    let startDate: Date
    var onReclassify: () -> Void = {}

    private var color: Color { event.kind.color }
    private var isUnassignedCheckpoint: Bool { event.kind == .checkpoint }

    private var subtitle: String? {
        if let id = event.garmentID { return GarmentCatalog.byID[id]?.name }
        return event.note
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 34, height: 34)
                Image(systemName: event.kind.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(event.kind.title).font(.subheadline.weight(.medium))
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(event.timestamp, format: .dateTime.hour().minute())
                    .font(.caption.weight(.medium))
                Text(offsetLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if isUnassignedCheckpoint {
                Button(action: onReclassify) {
                    Text("Назначить")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var offsetLabel: String {
        let secs = max(0, Int(event.timestamp.timeIntervalSince(startDate)))
        return L10n.format("+%lld:%02lld", secs / 60, secs % 60)
    }
}
