import AppIntents
@preconcurrency import ActivityKit
import Foundation

// MARK: - WalkQuickMarkIntents
// Кнопки быстрых меток на экране блокировки / в Dynamic Island Live Activity.
// Выполняются без открытия приложения (в процессе SkyKidWidgetExtension),
// поэтому читают/пишут `ActiveWalk` напрямую из App Group и обновляют
// Live Activity через `Activity<WalkActivityAttributes>` — без обращения
// к `ActiveWalkStore`/`WalkLiveActivityController` (те тянут GarmentCatalog).

/// Немедленно показывает спиннер на нужной кнопке и блокирует весь ряд —
/// до того, как реальное событие будет записано (см. `appendWalkEvent`).
@available(iOS 17, *)
private func setPending(_ control: QuickMarkControl) async {
    guard let activity = Activity<WalkActivityAttributes>.activities.first else { return }
    var state = activity.content.state
    state.pendingControl = control
    await activity.update(ActivityContent(state: state, staleDate: nil))
}

@available(iOS 17, *)
private func appendWalkEvent(kind: WalkEventKind) async {
    let defaults = AppGroup.defaults

    if let data = defaults.data(forKey: ActiveWalkStorage.key),
       var walk = try? JSONDecoder().decode(ActiveWalk.self, from: data) {
        walk.events.append(WalkEvent(kind: kind))
        if let newData = try? JSONEncoder().encode(walk) {
            defaults.set(newData, forKey: ActiveWalkStorage.key)
        }
    }

    guard let activity = Activity<WalkActivityAttributes>.activities.first else { return }

    var state = activity.content.state
    state.lastEventTitle = kind.title
    state.lastEventIcon = kind.icon
    state.lastEventDate = .now
    state.pendingControl = nil
    switch kind {
    case .sleep, .wake:
        state.isSleeping = kind == .sleep
    case .openedBassinette, .closedBassinette:
        state.isBassinetteOpen = kind == .openedBassinette
    case .addedGarment, .removedGarment, .checkpoint:
        break
    }
    await activity.update(ActivityContent(state: state, staleDate: nil))
}

@available(iOS 17, *)
struct WalkSleepToggleIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Уснул / Проснулся"
    static let description = IntentDescription("Отметить, что ребёнок уснул или проснулся")

    func perform() async throws -> some IntentResult {
        await setPending(.sleep)
        let isSleeping = Activity<WalkActivityAttributes>.activities.first?.content.state.isSleeping ?? false
        await appendWalkEvent(kind: isSleeping ? .wake : .sleep)
        return .result()
    }
}

@available(iOS 17, *)
struct WalkBassinetteToggleIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Люлька"
    static let description = IntentDescription("Отметить, что люльку открыли или закрыли")

    func perform() async throws -> some IntentResult {
        await setPending(.bassinette)
        let isOpen = Activity<WalkActivityAttributes>.activities.first?.content.state.isBassinetteOpen ?? false
        await appendWalkEvent(kind: isOpen ? .closedBassinette : .openedBassinette)
        return .result()
    }
}

@available(iOS 17, *)
struct WalkCheckpointIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Отметка"
    static let description = IntentDescription("Добавить контрольную точку на таймлайн прогулки")

    func perform() async throws -> some IntentResult {
        await setPending(.checkpoint)
        await appendWalkEvent(kind: .checkpoint)
        return .result()
    }
}
