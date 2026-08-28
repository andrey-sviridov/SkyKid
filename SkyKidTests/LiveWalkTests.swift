import XCTest
import UserNotifications
@testable import SkyKid

/// Regression coverage for "живая прогулка у второго родителя": сборка/разбор
/// строки `live_walks`, отсечение своей прогулки от чужой, дебаунс публикации
/// и локальные уведомления.
///
/// Ничего не ходит в сеть: `LiveWalkObserver.apply(_:)`/`remove(ownerUserID:)`
/// — прямые точки входа без REST/Realtime, `LiveWalkObserver.ownUserIDProvider`
/// и `LiveWalkPublisher.upload`/`LiveWalkNotifier.addRequest`/`removePending`
/// — инъекции ради тестируемости (см. `AuthSyncTests.swift` про тот же приём
/// с `SupabaseAuthService.shared` не будучи залогиненным).
@MainActor
final class LiveWalkTests: XCTestCase {

    // MARK: - Fixtures

    /// `startDate` по умолчанию — «сейчас», а не фиксированная дата в
    /// прошлом: `LiveWalkSnapshot.isStale()` также смотрит на длительность
    /// самой прогулки (12 ч), и старая фиксированная дата ложно протухала бы
    /// независимо от `updatedAt`, который как раз проверяют тесты ниже.
    private func makeWalk(
        id: UUID = UUID(),
        startDate: Date = .now,
        eventCount: Int = 0
    ) -> ActiveWalk {
        ActiveWalk(
            id: id,
            startDate: startDate,
            plannedDurationMinutes: 30,
            weatherTemperature: 12,
            apparentTemperature: 10,
            weatherCode: 3,
            outfitItemIDs: ["bodysuit_ss", "hat_knit"],
            events: (0..<eventCount).map { i in
                WalkEvent(timestamp: startDate.addingTimeInterval(Double(i) * 60), kind: .checkpoint)
            }
        )
    }

    private func makeSnapshot(
        ownerUserID: UUID,
        walk: ActiveWalk? = nil,
        updatedAt: Date = .now
    ) -> LiveWalkSnapshot {
        LiveWalkSnapshot(walk: walk ?? makeWalk(), ownerUserID: ownerUserID, updatedAt: updatedAt)
    }

    /// То же ISO8601-представление даты, которое используют
    /// `JSONEncoder.supabase()`/`JSONDecoder.supabase()` внутри supabase-swift
    /// (`Date.iso8601String` / `String.date` в `Helpers/DateFormatter.swift`)
    /// — те расширения объявлены `package` и недоступны тестовому таргету,
    /// поэтому формат воспроизведён явно через `Date.ISO8601FormatStyle`.
    private var supabaseLikeCoders: (encoder: JSONEncoder, decoder: JSONDecoder) {
        let style = Date.ISO8601FormatStyle()
            .year().month().day()
            .dateTimeSeparator(.standard)
            .time(includingFractionalSeconds: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, enc in
            var container = enc.singleValueContainer()
            try container.encode(date.formatted(style))
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = try? Date(string, strategy: style) else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Invalid date format: \(string)"
                )
            }
            return date
        }

        return (encoder, decoder)
    }

    // MARK: - 1. LiveWalkRow ↔ ActiveWalk round-trip

    /// Полный набор полей — если бы `startDate` или вложенный `WalkEvent`
    /// съезжали при кодировании, это была бы ровно та грабля, что уже была
    /// описана для `BirthdayFormat` (сдвиг часового пояса на сериализации).
    func test_liveWalkRow_roundTripsFullActiveWalkWithoutDrift() throws {
        let startDate = Date(timeIntervalSince1970: 1_755_000_000.123)
        let walk = ActiveWalk(
            id: UUID(),
            startDate: startDate,
            plannedDurationMinutes: 45,
            weatherTemperature: 8.5,
            apparentTemperature: 6.2,
            microclimateTemperature: 9.1,
            weatherCode: 61,
            weatherIconSymbol: "cloud.rain.fill",
            weatherDescription: "Дождь",
            transportMode: .pramBassinette,
            activityLevel: .sleeping,
            walkType: .regular,
            targetTOG: 2.4,
            outfitItemIDs: ["bodysuit_ls", "fleece", "hat_knit"],
            events: [
                WalkEvent(timestamp: startDate.addingTimeInterval(300), kind: .sleep),
                WalkEvent(timestamp: startDate.addingTimeInterval(900), kind: .addedGarment, garmentID: "fleece"),
                WalkEvent(timestamp: startDate.addingTimeInterval(1200), kind: .checkpoint, note: "тестовая заметка"),
            ]
        )
        let ownerID = UUID()
        let updatedAt = Date(timeIntervalSince1970: 1_755_001_234.5)

        struct Wire: Encodable {
            let userID: UUID
            let payload: ActiveWalk
            let updatedAt: Date
            enum CodingKeys: String, CodingKey {
                case userID = "user_id", payload, updatedAt = "updated_at"
            }
        }

        let (encoder, decoder) = supabaseLikeCoders
        let data = try encoder.encode(Wire(userID: ownerID, payload: walk, updatedAt: updatedAt))
        let row = try decoder.decode(LiveWalkRow.self, from: data)

        XCTAssertEqual(row.userID, ownerID)
        XCTAssertEqual(
            row.payload.startDate.timeIntervalSince1970, startDate.timeIntervalSince1970,
            accuracy: 0.001, "startDate не должен съезжать при кодировании/декодировании"
        )
        XCTAssertEqual(row.updatedAt.timeIntervalSince1970, updatedAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(row.payload.id, walk.id)
        XCTAssertEqual(row.payload.outfitItemIDs, walk.outfitItemIDs)
        XCTAssertEqual(row.payload.transportMode, .pramBassinette)
        XCTAssertEqual(row.payload.activityLevel, .sleeping)
        XCTAssertEqual(row.payload.walkType, .regular)
        XCTAssertEqual(row.payload.targetTOG, 2.4)
        XCTAssertEqual(row.payload.events.count, 3)
        XCTAssertEqual(row.payload.events[1].garmentID, "fleece")
        XCTAssertEqual(row.payload.events[2].note, "тестовая заметка")

        let snapshot = row.snapshot
        XCTAssertEqual(snapshot.ownerUserID, ownerID)
        XCTAssertEqual(snapshot.eventCount, 3)
    }

    // MARK: - 2. Своя строка никогда не становится partner (самый важный тест)

    func test_apply_ownRowNeverBecomesPartner() async {
        let observer = LiveWalkObserver.shared
        observer.reset()
        let originalProvider = observer.ownUserIDProvider
        addTeardownBlock {
            observer.ownUserIDProvider = originalProvider
            observer.reset()
        }

        let ownID = UUID()
        observer.ownUserIDProvider = { ownID }

        await observer.apply(makeSnapshot(ownerUserID: ownID))

        XCTAssertNil(
            observer.partner,
            "снапшот с собственным userID не должен попадать в partner — иначе " +
            "владелец увидит свою прогулку дважды и получит уведомления о своих же отметках"
        )
    }

    /// Позитивный контроль к тесту выше: чужая прогулка, наоборот, обязана
    /// попасть в `partner` — иначе тест ownRowNeverBecomesPartner мог бы
    /// проходить просто потому, что `apply` вообще ничего не делает.
    func test_apply_foreignRowBecomesPartner() async {
        let observer = LiveWalkObserver.shared
        observer.reset()
        let originalProvider = observer.ownUserIDProvider
        addTeardownBlock {
            observer.ownUserIDProvider = originalProvider
            observer.reset()
        }

        let ownID = UUID()
        let partnerID = UUID()
        observer.ownUserIDProvider = { ownID }

        await observer.apply(makeSnapshot(ownerUserID: partnerID))

        XCTAssertEqual(observer.partner?.ownerUserID, partnerID)
    }

    // MARK: - 3. Протухание

    func test_recomputePartner_ignoresStaleRow_acceptsFreshRow() async {
        let observer = LiveWalkObserver.shared
        observer.reset()
        let originalProvider = observer.ownUserIDProvider
        addTeardownBlock {
            observer.ownUserIDProvider = originalProvider
            observer.reset()
        }

        let ownID = UUID()
        let partnerID = UUID()
        observer.ownUserIDProvider = { ownID }

        let staleWalk = makeWalk(startDate: .now.addingTimeInterval(-20 * 60))
        await observer.apply(makeSnapshot(
            ownerUserID: partnerID, walk: staleWalk,
            updatedAt: .now.addingTimeInterval(-3 * 60 * 60)
        ))
        XCTAssertNil(observer.partner, "строка с updatedAt трёхчасовой давности должна считаться протухшей")

        let freshWalk = makeWalk(startDate: .now.addingTimeInterval(-20 * 60))
        await observer.apply(makeSnapshot(
            ownerUserID: partnerID, walk: freshWalk,
            updatedAt: .now.addingTimeInterval(-2 * 60)
        ))
        XCTAssertEqual(
            observer.partner?.ownerUserID, partnerID,
            "строка с updatedAt двухминутной давности должна быть принята"
        )
    }

    // MARK: - 4. Дебаунс публикации

    /// Изолированный (actor) счётчик, а не обычная переменная: `upload`
    /// вызывается изнутри `Task { ... }`, и без актора это была бы гонка
    /// данных при параллельном доступе из теста и из таска публикатора.
    private actor CallCounter {
        private(set) var count = 0
        func increment() { count += 1 }
    }

    func test_publisher_schedule_debouncesFiveCallsToSingleUpload() async {
        let publisher = LiveWalkPublisher.shared
        let originalUpload = publisher.upload
        let originalInterval = publisher.debounceInterval
        addTeardownBlock {
            publisher.upload = originalUpload
            publisher.debounceInterval = originalInterval
        }

        let counter = CallCounter()
        publisher.debounceInterval = .milliseconds(30)
        publisher.upload = { _ in await counter.increment() }

        let walk = makeWalk()
        for _ in 0..<5 {
            publisher.schedule(walk)
        }

        try? await Task.sleep(for: .milliseconds(300))

        let count = await counter.count
        XCTAssertEqual(count, 1, "пять schedule() подряд должны схлопнуться в один upload")
    }

    func test_publisher_publishNow_doesNotWaitForDebounce() async {
        let publisher = LiveWalkPublisher.shared
        let originalUpload = publisher.upload
        let originalInterval = publisher.debounceInterval
        addTeardownBlock {
            publisher.upload = originalUpload
            publisher.debounceInterval = originalInterval
        }

        let counter = CallCounter()
        // Специально длинный дебаунс — если бы publishNow() шёл через
        // schedule(), за отведённое тесту время он бы не успел.
        publisher.debounceInterval = .seconds(30)
        publisher.upload = { _ in await counter.increment() }

        publisher.publishNow(makeWalk())
        try? await Task.sleep(for: .milliseconds(150))

        let count = await counter.count
        XCTAssertEqual(count, 1, "publishNow() не должен ждать дебаунс")
    }

    func test_publisher_retract_cancelsPendingScheduleAndCallsRetractUpload() async {
        let publisher = LiveWalkPublisher.shared
        let originalUpload = publisher.upload
        let originalRetract = publisher.retractUpload
        let originalInterval = publisher.debounceInterval
        addTeardownBlock {
            publisher.upload = originalUpload
            publisher.retractUpload = originalRetract
            publisher.debounceInterval = originalInterval
        }

        let uploadCounter = CallCounter()
        let retractCounter = CallCounter()
        publisher.debounceInterval = .milliseconds(50)
        publisher.upload = { _ in await uploadCounter.increment() }
        publisher.retractUpload = { await retractCounter.increment() }

        publisher.schedule(makeWalk())
        publisher.retract()

        try? await Task.sleep(for: .milliseconds(200))

        let uploads = await uploadCounter.count
        let retracts = await retractCounter.count
        XCTAssertEqual(uploads, 0, "retract() должен отменить ещё не сработавший schedule()")
        XCTAssertEqual(retracts, 1)
    }

    // MARK: - 5. Несколько чужих прогулок — выбор самой свежей

    func test_recomputePartner_picksMostRecentlyUpdatedAmongForeignRows() async {
        let observer = LiveWalkObserver.shared
        observer.reset()
        let originalProvider = observer.ownUserIDProvider
        addTeardownBlock {
            observer.ownUserIDProvider = originalProvider
            observer.reset()
        }

        let ownID = UUID()
        observer.ownUserIDProvider = { ownID }

        let olderID = UUID()
        let newerID = UUID()
        await observer.apply(makeSnapshot(ownerUserID: olderID, updatedAt: .now.addingTimeInterval(-120)))
        await observer.apply(makeSnapshot(ownerUserID: newerID, updatedAt: .now.addingTimeInterval(-5)))

        XCTAssertEqual(
            observer.partner?.ownerUserID, newerID,
            "если гуляют двое (не считая себя), должен выбираться тот, чья строка обновлялась позже"
        )
    }

    // MARK: - 6. Агрегация уведомлений о новых отметках

    func test_notifier_repeatedTimelineUpdates_collapseToOnePendingRequest() async {
        let notifier = LiveWalkNotifier.shared
        let originalAdd = notifier.addRequest
        let originalRemove = notifier.removePending
        let (originalTop, originalFeature) = enableLiveWalkNotifications()
        addTeardownBlock {
            notifier.addRequest = originalAdd
            notifier.removePending = originalRemove
            self.restoreNotificationGates(top: originalTop, feature: originalFeature)
        }

        var pending: [String: UNNotificationRequest] = [:]
        notifier.addRequest = { pending[$0.identifier] = $0 }
        notifier.removePending = { ids in ids.forEach { pending.removeValue(forKey: $0) } }

        for count in 1...4 {
            await notifier.notifyTimelineUpdate(eventCount: count)
        }

        XCTAssertEqual(
            pending.count, 1,
            "4 события подряд должны оставить ровно один отложенный запрос, а не четыре"
        )
        XCTAssertNotNil(pending[LiveWalkNotifier.ID.timeline])

        await notifier.notifyFinished()
        XCTAssertNil(
            pending[LiveWalkNotifier.ID.timeline],
            "завершение прогулки должно снимать ещё не доставленное «N новых отметок»"
        )
    }

    // MARK: - 7. Гейт настройки

    func test_notifier_disabledPreference_addsNoRequests() async {
        let notifier = LiveWalkNotifier.shared
        let originalAdd = notifier.addRequest
        let originalPref = LiveWalkNotificationPreferences.isEnabled
        let originalService = AppGroup.defaults.bool(forKey: NotificationService.enabledKey)
        addTeardownBlock {
            notifier.addRequest = originalAdd
            LiveWalkNotificationPreferences.isEnabled = originalPref
            AppGroup.defaults.set(originalService, forKey: NotificationService.enabledKey)
        }

        AppGroup.defaults.set(true, forKey: NotificationService.enabledKey)
        LiveWalkNotificationPreferences.isEnabled = false

        var addCount = 0
        notifier.addRequest = { _ in addCount += 1 }

        await notifier.notifyStarted()
        await notifier.notifyTimelineUpdate(eventCount: 1)
        await notifier.notifyFinished()

        XCTAssertEqual(
            addCount, 0,
            "выключенный тумблер уведомлений о живой прогулке должен блокировать все три вида уведомлений"
        )
    }

    /// Позитивный контроль: включённый тумблер, наоборот, обязан пропускать
    /// уведомление — иначе тест выше мог бы проходить просто потому, что
    /// `addRequest` никогда не вызывается вообще.
    func test_notifier_enabledPreference_addsStartedRequest() async {
        let notifier = LiveWalkNotifier.shared
        let originalAdd = notifier.addRequest
        let (originalTop, originalFeature) = enableLiveWalkNotifications()
        addTeardownBlock {
            notifier.addRequest = originalAdd
            self.restoreNotificationGates(top: originalTop, feature: originalFeature)
        }

        var addCount = 0
        notifier.addRequest = { _ in addCount += 1 }

        await notifier.notifyStarted()

        XCTAssertEqual(addCount, 1)
    }

    // MARK: - 8. Экран чужой прогулки открыт — уведомлений нет

    func test_apply_whileViewingLiveWalk_suppressesNotifications() async {
        let observer = LiveWalkObserver.shared
        observer.reset()
        let originalProvider = observer.ownUserIDProvider
        let originalViewing = observer.isViewingLiveWalk
        let notifier = LiveWalkNotifier.shared
        let originalAdd = notifier.addRequest
        let (originalTop, originalFeature) = enableLiveWalkNotifications()
        addTeardownBlock {
            observer.ownUserIDProvider = originalProvider
            observer.isViewingLiveWalk = originalViewing
            notifier.addRequest = originalAdd
            self.restoreNotificationGates(top: originalTop, feature: originalFeature)
            observer.reset()
        }

        let ownID = UUID()
        observer.ownUserIDProvider = { ownID }
        observer.isViewingLiveWalk = true

        var addCount = 0
        notifier.addRequest = { _ in addCount += 1 }

        await observer.apply(makeSnapshot(ownerUserID: UUID()))

        XCTAssertEqual(addCount, 0, "пока экран чужой прогулки открыт, уведомлять о ней незачем")
    }

    /// Позитивный контроль: та же новая чужая строка при закрытом экране
    /// обязана уведомить о старте.
    func test_apply_newForeignRow_notifiesStarted_whenNotViewing() async {
        let observer = LiveWalkObserver.shared
        observer.reset()
        let originalProvider = observer.ownUserIDProvider
        let originalViewing = observer.isViewingLiveWalk
        let notifier = LiveWalkNotifier.shared
        let originalAdd = notifier.addRequest
        let (originalTop, originalFeature) = enableLiveWalkNotifications()
        addTeardownBlock {
            observer.ownUserIDProvider = originalProvider
            observer.isViewingLiveWalk = originalViewing
            notifier.addRequest = originalAdd
            self.restoreNotificationGates(top: originalTop, feature: originalFeature)
            observer.reset()
        }

        let ownID = UUID()
        observer.ownUserIDProvider = { ownID }
        observer.isViewingLiveWalk = false

        var addedIDs: [String] = []
        notifier.addRequest = { addedIDs.append($0.identifier) }

        await observer.apply(makeSnapshot(ownerUserID: UUID()))

        XCTAssertEqual(addedIDs, [LiveWalkNotifier.ID.started])
    }

    /// Рост `event_count` в уже существующем слоте — «новые отметки», а не
    /// повторный «начал прогулку».
    func test_apply_eventCountGrowth_notifiesTimelineUpdate() async {
        let observer = LiveWalkObserver.shared
        observer.reset()
        let originalProvider = observer.ownUserIDProvider
        let notifier = LiveWalkNotifier.shared
        let originalAdd = notifier.addRequest
        let (originalTop, originalFeature) = enableLiveWalkNotifications()
        addTeardownBlock {
            observer.ownUserIDProvider = originalProvider
            notifier.addRequest = originalAdd
            self.restoreNotificationGates(top: originalTop, feature: originalFeature)
            observer.reset()
        }

        let ownID = UUID()
        let partnerID = UUID()
        observer.ownUserIDProvider = { ownID }

        var addedIDs: [String] = []
        notifier.addRequest = { addedIDs.append($0.identifier) }

        let walkID = UUID()
        let start = Date.now.addingTimeInterval(-600)
        await observer.apply(makeSnapshot(
            ownerUserID: partnerID,
            walk: makeWalk(id: walkID, startDate: start, eventCount: 1)
        ))
        XCTAssertEqual(addedIDs, [LiveWalkNotifier.ID.started])

        await observer.apply(makeSnapshot(
            ownerUserID: partnerID,
            walk: makeWalk(id: walkID, startDate: start, eventCount: 3)
        ))

        XCTAssertEqual(addedIDs, [LiveWalkNotifier.ID.started, LiveWalkNotifier.ID.timeline])
    }

    /// DELETE чужого слота — «прогулка завершена».
    func test_remove_foreignRow_notifiesFinished() async {
        let observer = LiveWalkObserver.shared
        observer.reset()
        let originalProvider = observer.ownUserIDProvider
        let notifier = LiveWalkNotifier.shared
        let originalAdd = notifier.addRequest
        let (originalTop, originalFeature) = enableLiveWalkNotifications()
        addTeardownBlock {
            observer.ownUserIDProvider = originalProvider
            notifier.addRequest = originalAdd
            self.restoreNotificationGates(top: originalTop, feature: originalFeature)
            observer.reset()
        }

        let ownID = UUID()
        let partnerID = UUID()
        observer.ownUserIDProvider = { ownID }

        await observer.apply(makeSnapshot(ownerUserID: partnerID))

        var addedIDs: [String] = []
        notifier.addRequest = { addedIDs.append($0.identifier) }

        await observer.remove(ownerUserID: partnerID)

        XCTAssertEqual(addedIDs, [LiveWalkNotifier.ID.finished])
    }

    // MARK: - Helpers

    /// Включает оба гейта (`NotificationService.isEnabled` и
    /// `LiveWalkNotificationPreferences.isEnabled`) и возвращает исходные
    /// значения для восстановления в teardown — по тому же паттерну, что и
    /// `AuthSyncTests.restoreAuthPreferencesAfterTest()`.
    private func enableLiveWalkNotifications() -> (top: Bool, feature: Bool) {
        let top = AppGroup.defaults.bool(forKey: NotificationService.enabledKey)
        let feature = LiveWalkNotificationPreferences.isEnabled
        AppGroup.defaults.set(true, forKey: NotificationService.enabledKey)
        LiveWalkNotificationPreferences.isEnabled = true
        return (top, feature)
    }

    private func restoreNotificationGates(top: Bool, feature: Bool) {
        AppGroup.defaults.set(top, forKey: NotificationService.enabledKey)
        LiveWalkNotificationPreferences.isEnabled = feature
    }
}
