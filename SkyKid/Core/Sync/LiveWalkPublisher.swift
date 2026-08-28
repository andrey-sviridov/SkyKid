import Foundation
import Observation

// MARK: - LiveWalkPublisher

/// Отправляет состояние своей идущей прогулки на сервер, схлопывая частые
/// изменения в один запрос.
///
/// Дебаунс здесь не роскошь: смена набора одежды в пикере (`outfitBinding`
/// в `ActiveWalkView`) превращается в пачку `addGarment`/`removeGarment`
/// подряд, и без него каждая галочка стоила бы отдельного upsert'а.
///
/// Старт и завершение, наоборот, публикуются немедленно — задержка в
/// полторы секунды на этих двух событиях видна второму родителю.
@MainActor
@Observable
final class LiveWalkPublisher {
    static let shared = LiveWalkPublisher()

    /// Точки выхода в сеть — свойства, а не прямые вызовы сервиса, чтобы
    /// тест мог посчитать запросы, не поднимая Supabase.
    var upload: (ActiveWalk) async -> Void = { walk in
        await SupabaseSyncService.shared.upsertLiveWalk(walk)
    }

    var retractUpload: () async -> Void = {
        await SupabaseSyncService.shared.deleteLiveWalk()
    }

    /// Тоже настраиваемый — иначе тест дебаунса ждал бы полторы секунды.
    var debounceInterval: Duration = .milliseconds(1500)

    private var pendingTask: Task<Void, Never>?

    private init() {}

    // MARK: - Публикация

    /// Отложенная публикация: следующий вызов внутри окна отменяет
    /// предыдущий, так что в сеть уходит только последнее состояние.
    func schedule(_ walk: ActiveWalk) {
        pendingTask?.cancel()
        pendingTask = Task {
            try? await Task.sleep(for: debounceInterval)
            guard !Task.isCancelled else { return }
            await upload(walk)
        }
    }

    /// Немедленная публикация: старт прогулки и догон отметок, сделанных с
    /// экрана блокировки.
    func publishNow(_ walk: ActiveWalk) {
        pendingTask?.cancel()
        pendingTask = Task {
            await upload(walk)
        }
    }

    /// Снятие слота: прогулка завершена или отменена. Отложенная публикация
    /// при этом обязана умереть — иначе она воскресит только что удалённую
    /// строку.
    func retract() {
        pendingTask?.cancel()
        pendingTask = Task {
            await retractUpload()
        }
    }
}
