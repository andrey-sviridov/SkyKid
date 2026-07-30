import SwiftUI

struct WalkLogDetailView: View {
    let store: WalkLogStore
    let profile: ChildProfile?
    let onChanged: () -> Void

    @State private var log: WalkLog
    @State private var showAddEvent = false
    @State private var reclassifyingEvent: WalkEvent?
    @Environment(\.dismiss) private var dismiss

    init(log: WalkLog, store: WalkLogStore, profile: ChildProfile?, onChanged: @escaping () -> Void) {
        self.store = store
        self.profile = profile
        self.onChanged = onChanged
        _log = State(initialValue: log)
    }

    private var comfortColor: Color { log.comfortLevel.color }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                comfortHero
                infoCard
                if !log.outfitItemIDs.isEmpty { outfitCard }
                if log.isLiveTracked { timelineCard }
                deleteButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .skyKidBackground()
        .navigationTitle("Прогулка")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddEvent) {
            AddWalkEventSheet(walkStart: log.date) { event in
                log.events.append(event)
                persist()
            }
        }
        .sheet(item: $reclassifyingEvent) { event in
            WalkEventReclassifySheet(event: event, profile: profile) { kind, garmentID, note in
                reclassify(event, kind: kind, garmentID: garmentID, note: note)
            }
        }
    }

    private func persist() {
        log.events.sort { $0.timestamp < $1.timestamp }
        store.update(log, profile: profile)
        onChanged()
    }

    private func reclassify(_ event: WalkEvent, kind: WalkEventKind, garmentID: String?, note: String?) {
        guard let idx = log.events.firstIndex(where: { $0.id == event.id }) else { return }
        let result = WalkEventReclassifier.apply(
            old: log.events[idx],
            newKind: kind,
            newGarmentID: garmentID,
            newNote: note,
            outfitItemIDs: log.outfitItemIDs
        )
        log.events[idx] = result.event
        log.outfitItemIDs = result.outfitItemIDs
        persist()
    }

    // MARK: Timeline

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Таймлайн прогулки", systemImage: "list.bullet.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { showAddEvent = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            if log.events.isEmpty {
                Text("Отметок не было")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(log.events.sorted { $0.timestamp > $1.timestamp }) { event in
                    timelineRow(event)
                        .contextMenu {
                            Button {
                                reclassifyingEvent = event
                            } label: {
                                Label("Назначить действие", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                log.events.removeAll { $0.id == event.id }
                                persist()
                            } label: {
                                Label("Удалить отметку", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.10), lineWidth: 1))
    }

    private func timelineRow(_ event: WalkEvent) -> some View {
        let color = event.kind.color
        let subtitle: String? = event.garmentID.flatMap { GarmentCatalog.byID[$0]?.name } ?? event.note
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: event.kind.icon).font(.system(size: 14)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(event.kind.title).font(.subheadline.weight(.medium))
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(event.timestamp, format: .dateTime.hour().minute())
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            if event.kind == .checkpoint {
                Button {
                    reclassifyingEvent = event
                } label: {
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
        .padding(.vertical, 2)
    }

    // MARK: Sections

    private var comfortHero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(comfortColor.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: log.comfortLevel.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(comfortColor)
            }
            Text(log.comfortLevel.label)
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
            infoRow(icon: "calendar", label: L10n.text("Дата"),
                    value: log.date.formatted(
                        .dateTime
                            .day()
                            .month(.wide)
                            .year()
                            .locale(L10n.locale)
                    ))
            Divider().padding(.leading, 52)
            infoRow(icon: "clock", label: L10n.text("Время"),
                    value: log.date.formatted(
                        .dateTime
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
            Divider().padding(.leading, 52)
            infoRow(icon: "thermometer.medium", label: L10n.text("Температура"),
                    value: "\(Int(log.weatherTemperature.rounded()))°C")
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

    private var deleteButton: some View {
        Button(role: .destructive) {
            if let idx = store.logs.firstIndex(where: { $0.id == log.id }) {
                store.delete(at: IndexSet(integer: idx))
                onChanged()
            }
            dismiss()
        } label: {
            Label("Удалить прогулку", systemImage: "trash")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.red.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var durationString: String {
        WalkDurationFormatter.string(minutes: log.durationMinutes)
    }
}
