import SwiftUI

struct WalkLogRow: View {
    let log: WalkLog

    @State private var showingLiveActivityInfo = false

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
                    if log.isLiveTracked { liveBadge }
                    Spacer()
                    durationBadge
                }

                HStack(spacing: 10) {
                    Label("\(Int(log.weatherTemperature.rounded()))°C", systemImage: "thermometer.medium")
                    Label(log.comfortLevel.label, systemImage: log.comfortLevel.icon)
                        .foregroundStyle(comfortColor)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !log.outfitItemIDs.isEmpty {
                    let names = log.outfitItemIDs.compactMap { GarmentCatalog.byID[$0]?.name }
                    if !names.isEmpty {
                        Text(names.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.10), lineWidth: 1))
        .alert(L10n.text("Live Activity"), isPresented: $showingLiveActivityInfo) {
            Button(L10n.text("Понятно")) {}
        } message: {
            Text(L10n.text("Эта прогулка отслеживалась вживую: таймер и статус отображались на экране блокировки и в Dynamic Island, пока прогулка шла."))
        }
    }

    private var durationBadge: some View {
        Text(WalkDurationFormatter.string(minutes: log.durationMinutes))
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.07), in: Capsule())
    }

    private var liveBadge: some View {
        Button {
            showingLiveActivityInfo = true
        } label: {
            Label("Прогулка", systemImage: "figure.walk.motion")
                .labelStyle(.iconOnly)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.green)
                .padding(5)
                .background(Color.green.opacity(0.14), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.text("Live Activity"))
        .accessibilityHint(L10n.text("Прогулка отслеживалась вживую через экран блокировки"))
    }
}
