import SwiftUI

// MARK: - ActiveWalkView

/// Экран идущей прогулки: живой таймер на weather-градиенте, набор одежды,
/// быстрые кнопки-события и таймлайн. По тапу доступно завершение.
struct ActiveWalkView: View {
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    var onChanged: () -> Void = {}

    @State private var store = ActiveWalkStore.shared
    @State private var showFinish = false
    @State private var showCancel = false
    @State private var reclassifyingEvent: WalkEvent?
    private var tabBarHeight: CGFloat { SkyKidTabBarMetrics.totalHeight }

    private var outfitBinding: Binding<[String]> {
        Binding(
            get: { store.current?.outfitItemIDs ?? [] },
            set: { newValue in
                let old = store.current?.outfitItemIDs ?? []
                for id in newValue where !old.contains(id) { store.addGarment(id) }
                for id in old where !newValue.contains(id) { store.removeGarment(id) }
            }
        )
    }

    var body: some View {
        ScrollView {
            if let walk = store.current {
                VStack(spacing: 16) {
                    timerHeader(walk)
                    WalkOutfitChipsCard(
                        selectedIDs: outfitBinding,
                        profile: profile,
                        targetTOG: walk.targetTOG
                    )
                    quickActions
                    timeline(walk)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            } else {
                ContentUnavailableView("Нет активной прогулки", systemImage: "figure.walk")
            }
        }
        .skyKidBackground()
        .navigationTitle("Прогулка идёт")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { showCancel = true } label: {
                    Image(systemName: "xmark.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if store.current != nil {
                finishButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, tabBarHeight + 8)
            }
        }
        // Свой bottom sheet вместо системного confirmationDialog: на iOS 26
        // (симулятор) он иногда рендерился как плавающая карточка с
        // "хвостиком" в произвольной точке экрана вместо привычного шита
        // снизу. .sheet — другой, не адаптивный API, ведёт себя стабильно
        // на любой версии iOS и заодно в едином стиле с остальным приложением.
        .sheet(isPresented: $showFinish) {
            ComfortLevelSheet(onSelect: finish)
        }
        .sheet(isPresented: $showCancel) {
            CancelWalkSheet(onConfirm: { store.cancel(); onChanged() })
        }
        .sheet(item: $reclassifyingEvent) { event in
            WalkEventReclassifySheet(event: event, profile: profile) { kind, garmentID, note in
                store.reclassifyEvent(id: event.id, kind: kind, garmentID: garmentID, note: note)
            }
        }
    }

    // MARK: - Timer header

    private func timerHeader(_ walk: ActiveWalk) -> some View {
        let tone = SkyKidTheme.WeatherTone(weatherCode: walk.weatherCode)
        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: weather?.conditionIcon ?? "cloud.fill")
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(tone.onColor)
                Text(L10n.format("%lld°C", Int(walk.weatherTemperature.rounded())))
                    .font(.headline)
                    .foregroundStyle(tone.onColor)
                Spacer()
                if let desc = weather?.conditionDescription {
                    Text(desc)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(tone.onColor.opacity(0.9))
                }
            }

            Text(walk.startDate, style: .timer)
                .font(.system(size: 54, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tone.onColor)

            if let planned = walk.plannedDurationMinutes {
                let target = walk.startDate.addingTimeInterval(TimeInterval(planned * 60))
                HStack(spacing: 6) {
                    Image(systemName: "hourglass")
                    if target > .now {
                        Text("осталось")
                        Text(target, style: .timer).monospacedDigit()
                    } else {
                        Text("цель достигнута")
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tone.onColor.opacity(0.9))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(SkyKidTheme.weatherGradient(for: walk.weatherCode), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.28), lineWidth: 1))
        .shadow(color: tone.colors.first?.opacity(0.35) ?? .clear, radius: 12, y: 4)
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Быстрые отметки", systemImage: "bolt.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 10) {
                quickButton(.openedBassinette)
                quickButton(.closedBassinette)
                quickButton(.sleep)
                quickButton(.wake)
                quickButton(.checkpoint)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    private func quickButton(_ kind: WalkEventKind) -> some View {
        let color = kind.color
        return Button {
            withAnimation(.spring(response: 0.25)) { store.logEvent(kind) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: kind.icon)
                Text(kind.title)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: store.current?.events.count ?? 0)
    }

    // MARK: - Timeline

    @ViewBuilder
    private func timeline(_ walk: ActiveWalk) -> some View {
        if !walk.events.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Таймлайн", systemImage: "list.bullet.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(walk.events.sorted { $0.timestamp > $1.timestamp }) { event in
                    WalkEventRow(event: event, startDate: walk.startDate) {
                        reclassifyingEvent = event
                    }
                    .contextMenu {
                        Button {
                            reclassifyingEvent = event
                        } label: {
                            Label("Назначить действие", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            store.removeEvent(id: event.id)
                        } label: {
                            Label("Удалить отметку", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
        }
    }

    // MARK: - Finish

    private var finishButton: some View {
        Button { showFinish = true } label: {
            Label("Завершить прогулку", systemImage: "flag.checkered")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.10, green: 0.60, blue: 0.35),
                                 Color(red: 0.06, green: 0.44, blue: 0.52)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
        }
        .buttonStyle(.plain)
    }

    private func finish(_ level: BabyComfortLevel) {
        store.finish(comfortLevel: level, profile: profile)
        onChanged()
    }
}

// MARK: - ComfortLevelSheet

/// Свой bottom sheet выбора самочувствия малыша при завершении прогулки —
/// замена системного confirmationDialog (см. комментарий в ActiveWalkView.body).
private struct ComfortLevelSheet: View {
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

// MARK: - CancelWalkSheet

/// Свой bottom sheet подтверждения отмены прогулки без сохранения — замена
/// системного confirmationDialog.
private struct CancelWalkSheet: View {
    var onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Отменить прогулку без сохранения?")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            VStack(spacing: 10) {
                Button {
                    onConfirm()
                    dismiss()
                } label: {
                    Text("Удалить прогулку")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Button("Отмена") { dismiss() }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - WalkEventRow

private struct WalkEventRow: View {
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
