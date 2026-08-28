import Foundation
import Observation
import Supabase

// MARK: - LiveWalkObserver

/// Следит за идущими прогулками семьи и держит ту, что ведёт второй родитель.
///
/// Единственное место в приложении, где используется Supabase Realtime:
/// весь остальной синк — пулловый, но «в реальном времени» пуллом не
/// сделаешь. Подписка живёт только пока приложение на переднем плане —
/// фоновых режимов у приложения нет, и сокет всё равно умрёт при сворачивании.
@MainActor
@Observable
final class LiveWalkObserver {
    static let shared = LiveWalkObserver()

    /// Прогулка второго родителя. `nil` — либо никто не гуляет, либо гуляем
    /// только мы сами.
    private(set) var partner: LiveWalkSnapshot?
    private(set) var partnerName: String?

    /// Статус канала — по нему экран показывает «нет связи» и включается
    /// пулловый запасной путь.
    private(set) var isConnected = false

    /// Меняется, когда чужая прогулка исчезла со свободного слота, то есть
    /// была завершена или отменена. `ContentView` по этому сигналу
    /// подтягивает журнал: сама запись приезжает другим путём, обычным
    /// `walk_logs`-апсертом.
    private(set) var lastFinishedAt: Date?

    /// Экран чужой прогулки открыт — уведомлять о том, что и так на виду,
    /// не нужно.
    var isViewingLiveWalk = false

    /// Все слоты семьи, включая свой: свой отсеивается при выборе `partner`,
    /// а не при получении, иначе «своя vs чужая» размазалась бы по коду.
    private var slots: [UUID: LiveWalkSnapshot] = [:]

    /// Источник своего `userID`, вынесенный в свойство ради тестов: в тестах
    /// `SupabaseAuthService.shared` не залогинен, и без инъекции проверить
    /// самый важный инвариант (своя строка не становится `partner`) было бы
    /// нечем.
    var ownUserIDProvider: () -> UUID? = { SupabaseAuthService.shared.userID }

    private var channel: RealtimeChannelV2?
    private var subscriptionTask: Task<Void, Never>?
    private var statusSubscription: RealtimeSubscription?
    private var pollingTask: Task<Void, Never>?

    private init() {}

    // MARK: - Жизненный цикл

    /// Вызывается при выходе приложения на передний план и на старте.
    ///
    /// Пулл идёт первым и всегда: состояние обязано быть верным, даже если
    /// сокет не поднимется — например, когда миграцию ещё не выполнили.
    func start() {
        guard SupabaseAuthService.shared.isSignedIn,
              let familyID = SupabaseAuthService.shared.familyID
        else { return }

        guard channel == nil else { return }

        Task {
            await refreshFromPull()
            await loadPartnerName()
        }
        subscribe(familyID: familyID)
        startPollingFallback()
    }

    func stop() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
        pollingTask?.cancel()
        pollingTask = nil
        statusSubscription?.cancel()
        statusSubscription = nil
        isConnected = false

        if let channel {
            self.channel = nil
            Task { await SupabaseClientProvider.client.realtimeV2.removeChannel(channel) }
        }
    }

    /// Полный сброс — при выходе из аккаунта чужие прогулки не должны
    /// пережить смену пользователя.
    func reset() {
        stop()
        slots = [:]
        partner = nil
        partnerName = nil
        lastFinishedAt = nil
    }

    // MARK: - Подписка

    private func subscribe(familyID: UUID) {
        let channel = SupabaseClientProvider.client.realtimeV2.channel("live-walks:\(familyID)")
        self.channel = channel

        // Фильтр только по семье: `postgres_changes` принимает одно условие,
        // а свои строки всё равно отсеиваются на клиенте.
        let filter = RealtimePostgresFilter.eq("family_id", value: familyID.uuidString)

        // Стримы обязаны быть зарегистрированы ДО subscribe() — иначе
        // события до подписки просто потеряются.
        let inserts = channel.postgresChange(InsertAction.self, table: "live_walks", filter: filter)
        let updates = channel.postgresChange(UpdateAction.self, table: "live_walks", filter: filter)
        let deletes = channel.postgresChange(DeleteAction.self, table: "live_walks", filter: filter)

        statusSubscription = channel.onStatusChange { [weak self] status in
            Task { @MainActor in
                self?.isConnected = status == .subscribed
            }
        }

        subscriptionTask = Task { [weak self] in
            await channel.subscribe()

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await action in inserts {
                        await self?.apply(record: action.record)
                    }
                }
                group.addTask {
                    for await action in updates {
                        await self?.apply(record: action.record)
                    }
                }
                group.addTask {
                    for await action in deletes {
                        await self?.applyDeletion(oldRecord: action.oldRecord)
                    }
                }
            }
        }
    }

    /// Пока сокет не поднялся — редкий опрос. Выключается сам, как только
    /// Realtime заработал, и не крутится в фоне: там наблюдатель остановлен
    /// целиком.
    private func startPollingFallback() {
        pollingTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            while !Task.isCancelled {
                guard let self, await !self.isConnected else { return }
                await self.refreshFromPull()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    // MARK: - Приём изменений

    /// Полная пересборка состояния из REST — старт подписки, запасной путь и
    /// возврат в приложение.
    func refreshFromPull() async {
        let snapshots = await SupabaseSyncService.shared.pullLiveWalks()
        slots = Dictionary(
            snapshots.map { ($0.ownerUserID, $0) },
            uniquingKeysWith: { lhs, rhs in lhs.updatedAt >= rhs.updatedAt ? lhs : rhs }
        )
        recomputePartner()
    }

    private func apply(record: [String: AnyJSON]) async {
        guard let row = try? record.decode(as: LiveWalkRow.self, decoder: AnyJSON.decoder) else { return }
        await apply(row.snapshot)
    }

    /// Отдельная точка входа для одного слота — её же дёргают тесты, чтобы
    /// не поднимать ради проверок сеть.
    ///
    /// Уведомления решаются здесь же, по разнице с тем, что было в слоте
    /// раньше: `previous == nil` — новая чужая прогулка, `eventCount` вырос —
    /// новые отметки. `refreshFromPull()` через эту точку не идёт и поэтому
    /// уведомлений не порождает — иначе каждый возврат в приложение сыпал бы
    /// баннерами о прогулке, которая идёт уже час.
    func apply(_ snapshot: LiveWalkSnapshot) async {
        let ownUserID = ownUserIDProvider()
        let previous = slots[snapshot.ownerUserID]
        slots[snapshot.ownerUserID] = snapshot
        recomputePartner()

        guard snapshot.ownerUserID != ownUserID, !isViewingLiveWalk else { return }

        if previous == nil {
            await LiveWalkNotifier.shared.notifyStarted()
        } else if snapshot.eventCount > previous!.eventCount {
            await LiveWalkNotifier.shared.notifyTimelineUpdate(eventCount: snapshot.eventCount)
        }
    }

    private func applyDeletion(oldRecord: [String: AnyJSON]) async {
        // При `replica identity default` в old_record приезжают только
        // колонки первичного ключа — полной строки тут нет и быть не может.
        guard let raw = oldRecord["user_id"]?.stringValue,
              let ownerUserID = UUID(uuidString: raw)
        else { return }
        await remove(ownerUserID: ownerUserID)
    }

    func remove(ownerUserID: UUID) async {
        let wasPartner = partner?.ownerUserID == ownerUserID
        let existed = slots[ownerUserID] != nil
        let ownUserID = ownUserIDProvider()
        slots[ownerUserID] = nil
        recomputePartner()

        if wasPartner {
            lastFinishedAt = .now
        }

        if existed, ownerUserID != ownUserID, !isViewingLiveWalk {
            await LiveWalkNotifier.shared.notifyFinished()
        }
    }

    // MARK: - Выбор чужой прогулки

    /// Своя прогулка живёт в `ActiveWalkStore` и в `partner` не попадает
    /// никогда: иначе владелец видел бы её дважды и получал уведомления о
    /// собственных отметках.
    private func recomputePartner() {
        let ownUserID = ownUserIDProvider()

        partner = slots.values
            .filter { $0.ownerUserID != ownUserID && !$0.isStale() }
            // Родителей в семье может быть больше двух: показываем самую
            // свежую, а не случайную.
            .max { $0.updatedAt < $1.updatedAt }
    }

    private func loadPartnerName() async {
        let members = await SupabaseSyncService.shared.familyMembers()
        let ownUserID = ownUserIDProvider()
        partnerName = members.first { $0.userID != ownUserID }?.title
    }
}
