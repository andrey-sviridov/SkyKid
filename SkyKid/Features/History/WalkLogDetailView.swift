import SwiftUI

struct WalkLogDetailView: View {
    let store: WalkLogStore
    let profile: ChildProfile?
    let onChanged: () -> Void

    @State private var log: WalkLog
    @Environment(\.dismiss) private var dismiss

    init(log: WalkLog, store: WalkLogStore, profile: ChildProfile?, onChanged: @escaping () -> Void) {
        self.store = store
        self.profile = profile
        self.onChanged = onChanged
        _log = State(initialValue: log)
    }

    private var comfortColor: Color { log.comfortFeedback.color }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                comfortHero
                infoCard
                if !log.outfitItemIDs.isEmpty { outfitCard }
                feedbackCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .skyKidBackground()
        .navigationTitle("Прогулка")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        deleteLog()
                    } label: {
                        Label(L10n.text("Удалить прогулку"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(L10n.text("Действия"))
            }
        }
    }

    // MARK: Sections

    private var comfortHero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(comfortColor.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: log.comfortFeedback.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(comfortColor)
            }
            Text(log.comfortFeedback.label)
                .font(.title3.weight(.semibold))
                .foregroundStyle(comfortColor)
            Text("Самочувствие малыша")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(comfortColor.opacity(0.3), lineWidth: 1))
    }

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(icon: "calendar.clock", label: L10n.text("Дата и время"),
                    value: log.date.formatted(
                        .dateTime
                            .day()
                            .month(.wide)
                            .year()
                            .hour()
                            .minute()
                            .locale(L10n.locale)
                    ))
            Divider().padding(.leading, 52)
            infoRow(
                icon: "timer",
                label: L10n.text("Длительность"),
                value: durationString
            )
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.10), lineWidth: 1))
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .padding(.leading, 16)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .padding(.trailing, 16)
        }
        .padding(.vertical, 13)
    }

    private var outfitCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Одежда", systemImage: "hanger")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            let items = log.outfitItemIDs.compactMap { GarmentCatalog.byID[$0] }
            FlowLayout(spacing: 8) {
                ForEach(items) { item in
                    Text(item.name)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.10), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.blue.opacity(0.25), lineWidth: 1))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.10), lineWidth: 1))
    }

    private var feedbackCard: some View {
        SectionCard(title: L10n.text("После прогулки"), systemImage: "checkmark.bubble") {
            infoRow(
                icon: "thermometer.medium",
                label: L10n.text("Самочувствие"),
                value: log.comfortFeedback.label
            )
            Divider().padding(.leading, 52)
            infoRow(
                icon: "arrow.triangle.2.circlepath",
                label: L10n.text("Одежда"),
                value: log.clothingAdjustment.label
            )
        }
    }

    private func deleteLog() {
        let logID = log.id
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            store.delete(id: logID)
            onChanged()
        }
    }

    private var durationString: String {
        WalkDurationFormatter.string(minutes: log.durationMinutes)
    }
}
