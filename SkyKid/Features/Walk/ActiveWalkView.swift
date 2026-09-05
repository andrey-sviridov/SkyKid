import SwiftUI

// MARK: - ActiveWalkView

/// Экран идущей прогулки: живой таймер на weather-градиенте, набор одежды,
/// быстрые кнопки-события и таймлайн. По тапу доступно завершение.
struct ActiveWalkView: View {
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    var onChanged: () -> Void = {}
    var onFinished: (WalkLog) -> Void = { _ in }

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
                    WalkTimerHeaderCard(walk: walk, weather: weather)

                    WalkOutfitChipsCard(
                        selectedIDs: outfitBinding,
                        profile: profile,
                        targetTOG: walk.targetTOG
                    )

                    WalkQuickActionsCard(
                        eventCount: walk.events.count,
                        isSleeping: walk.isSleeping,
                        showsBassinette: walk.transportMode == .pramBassinette
                    ) { kind in
                        store.logEvent(kind)
                    }

                    WalkTimelineCard(
                        events: walk.events,
                        startDate: walk.startDate,
                        onReclassify: { reclassifyingEvent = $0 },
                        onDelete: { store.removeEvent(id: $0.id) },
                        onUndoLast: { store.undoLastEvent() }
                    )
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

    private func finish(_ level: BabyComfortLevel) {
        guard let log = store.finish(comfortLevel: level, profile: profile) else { return }
        onChanged()

        // Даём текущему sheet выбора самочувствия закрыться до показа
        // следующего sheet с экраном завершения.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            onFinished(log)
        }
    }
}
