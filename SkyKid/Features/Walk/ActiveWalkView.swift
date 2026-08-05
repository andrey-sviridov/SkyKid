import SwiftUI

// MARK: - ActiveWalkView

/// Экран идущей прогулки: живой таймер на weather-градиенте, набор одежды,
/// быстрые кнопки-события и таймлайн. По тапу доступно завершение.
struct ActiveWalkView: View {
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    var onChanged: () -> Void = {}

    @Environment(ActiveWalkStore.self) private var store
    @State private var showFinish = false
    @State private var showCancel = false
    @State private var reclassifyingEvent: WalkEvent?

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
                // Место под таб-баром резервировать не нужно: нативный бар
                // сам ужимает safe area вкладки.
                finishButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
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
