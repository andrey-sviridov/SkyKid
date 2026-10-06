import SwiftUI

// MARK: - ActiveWalkView

/// Пассивный экран идущей прогулки: длительность, условия, одежда и завершение.
struct ActiveWalkView: View {
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    var onChanged: () -> Void = {}
    var onFinished: (WalkLog) -> Void = { _ in }

    @Environment(ActiveWalkStore.self) private var store
    @State private var showFinish = false
    @State private var showCancel = false
    @State private var isGarmentHistoryExpanded = false

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
                    if store.restorationState == .restored {
                        restoredWalkCard
                    }

                    WalkTimerHeaderCard(walk: walk)
                    WalkWeatherSnapshotCard(walk: walk)

                    WalkOutfitChipsCard(
                        selectedIDs: outfitBinding,
                        profile: profile,
                        targetTOG: walk.targetTOG
                    )
                    if let weatherChange = walk.latestWeatherChange {
                        weatherChangeNotice(weatherChange)
                    }
                    garmentChangeHistory(for: walk)
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
            ComfortLevelSheet(
                garmentOptions: GarmentCatalog.displayItems(
                    for: profile?.wardrobeAgeGroup ?? .infant
                ).values.flatMap { $0 },
                onSubmit: finish
            )
        }
        .sheet(isPresented: $showCancel) {
            CancelWalkSheet(onConfirm: { store.cancel(); onChanged() })
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
        .accessibilityIdentifier("walk.finish")
    }

    private func finish(_ feedback: WalkCompletionFeedback) {
        guard let log = store.finish(feedback: feedback, profile: profile) else { return }
        onChanged()

        // Даём текущему sheet выбора самочувствия закрыться до показа
        // следующего sheet с экраном завершения.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            onFinished(log)
        }
    }

    private var restoredWalkCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.text("Прогулка восстановлена"), systemImage: "arrow.clockwise.circle.fill")
                .font(.headline)
            Text(L10n.text("Можно продолжить таймер или завершить прогулку сейчас."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Button(L10n.text("Продолжить")) { store.acknowledgeRestoredWalk() }
                    .buttonStyle(.borderedProminent)
                Button(L10n.text("Завершить")) { showFinish = true }
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("walk.restored")
    }

    private func weatherChangeNotice(_ change: PassiveWeatherChange) -> some View {
        Label(change.message, systemImage: "cloud.sun.fill")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("walk.weatherChangeNotice")
    }

    @ViewBuilder
    private func garmentChangeHistory(for walk: ActiveWalk) -> some View {
        let events = walk.garmentChangeEvents
        if events.isEmpty {
            Label(
                L10n.text("Изменений одежды не отмечено"),
                systemImage: "arrow.triangle.2.circlepath"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        } else {
            DisclosureGroup(isExpanded: $isGarmentHistoryExpanded) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(events) { event in
                        garmentEventRow(event, walkStart: walk.startDate)
                        if event.id != events.last?.id {
                            Divider().padding(.leading, 34)
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                Label(
                    L10n.format("Изменений одежды: %lld", events.count),
                    systemImage: "arrow.triangle.2.circlepath"
                )
                .font(.subheadline.weight(.semibold))
            }
            .tint(.indigo)
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("walk.garmentHistory")
        }
    }

    private func garmentEventRow(_ event: WalkEvent, walkStart: Date) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: event.kind.icon)
                .foregroundStyle(event.kind.color)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(garmentEventTitle(event))
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text(garmentEventTime(event, walkStart: walkStart))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }

    private func garmentEventTitle(_ event: WalkEvent) -> String {
        let garmentName = event.garmentID
            .flatMap { GarmentCatalog.byID[$0]?.name }
            .map(OutfitFitPresentation.consumerGarmentName)
        guard let garmentName else { return event.kind.title }
        return "\(event.kind.title): \(garmentName)"
    }

    private func garmentEventTime(_ event: WalkEvent, walkStart: Date) -> String {
        let clockTime = event.timestamp.formatted(
            .dateTime.hour().minute().locale(L10n.locale)
        )
        let elapsedMinutes = max(0, Int(event.timestamp.timeIntervalSince(walkStart) / 60))
        return "\(clockTime) · +\(WalkDurationFormatter.string(minutes: elapsedMinutes))"
    }
}
