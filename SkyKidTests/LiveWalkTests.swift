import XCTest
@testable import SkyKid

@MainActor
final class LiveWalkTests: XCTestCase {
    func test_activeWalkRestartRoundTripUsesOnlyLocalPersistence() {
        let suite = "LiveWalkTests.active.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let startDate = Date(timeIntervalSince1970: 1_755_000_000)
        let walk = ActiveWalk(startDate: startDate, algorithmVersion: 23, outfitItemIDs: ["diaper"])

        ActiveWalkStore(defaults: defaults).start(walk)
        let restoredStore = ActiveWalkStore(defaults: defaults)

        XCTAssertEqual(restoredStore.current?.id, walk.id)
        XCTAssertEqual(restoredStore.current?.startDate, startDate)
        XCTAssertEqual(restoredStore.current?.outfitItemIDs, ["diaper"])
    }

    func test_finishPersistsLogAndKeepsAlgorithmVersion() {
        let activeSuite = "LiveWalkTests.active.\(UUID().uuidString)"
        let logsSuite = "LiveWalkTests.logs.\(UUID().uuidString)"
        let activeDefaults = UserDefaults(suiteName: activeSuite)!
        let logsDefaults = UserDefaults(suiteName: logsSuite)!
        defer {
            activeDefaults.removePersistentDomain(forName: activeSuite)
            logsDefaults.removePersistentDomain(forName: logsSuite)
        }
        let logStore = WalkLogStore(defaults: logsDefaults)
        let store = ActiveWalkStore(defaults: activeDefaults, logStore: logStore)
        let startDate = Date(timeIntervalSince1970: 1_755_000_000)

        store.start(ActiveWalk(startDate: startDate, algorithmVersion: 23))
        let log = store.finish(profile: nil, now: startDate.addingTimeInterval(1_800))

        XCTAssertEqual(log?.algorithmVersion, 23)
        XCTAssertEqual(logStore.logs.first?.id, log?.id)
        XCTAssertFalse(store.isActive)
        XCTAssertNil(activeDefaults.data(forKey: ActiveWalkStorage.key))
    }

    func test_duplicateStartReturnsAlreadyActiveAndNeverOverwritesPersistedWalk() {
        let suite = "LiveWalkTests.duplicate.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = ActiveWalk(startDate: Date(timeIntervalSince1970: 1_755_000_000))
        let second = ActiveWalk(startDate: Date(timeIntervalSince1970: 1_755_001_000))
        let store = ActiveWalkStore(defaults: defaults)

        XCTAssertEqual(store.start(first), .started)
        XCTAssertEqual(store.start(second), .alreadyActive(existingID: first.id))
        XCTAssertEqual(store.current?.id, first.id)
        XCTAssertEqual(ActiveWalkStore(defaults: defaults).current?.id, first.id)
    }

    func test_restoredWalkOffersExplicitAcknowledgementWithoutChangingStart() {
        let suite = "LiveWalkTests.restore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let walk = ActiveWalk(startDate: Date(timeIntervalSince1970: 1_755_000_000))
        let initialStore = ActiveWalkStore(defaults: defaults)
        initialStore.start(walk)

        let restoredStore = ActiveWalkStore(defaults: defaults)
        XCTAssertEqual(restoredStore.restorationState, .restored)
        XCTAssertEqual(restoredStore.current?.startDate, walk.startDate)

        restoredStore.acknowledgeRestoredWalk()
        XCTAssertEqual(restoredStore.restorationState, .acknowledged)
        restoredStore.refresh()
        XCTAssertEqual(restoredStore.restorationState, .acknowledged)
    }

    func test_elapsedDurationIsAbsoluteAcrossBackgroundAndClampedAfterClockRollback() {
        let start = Date(timeIntervalSince1970: 1_755_000_000)
        let walk = ActiveWalk(startDate: start)

        XCTAssertEqual(walk.elapsedSeconds(now: start.addingTimeInterval(3_600)), 3_600)
        XCTAssertEqual(walk.elapsedSeconds(now: start.addingTimeInterval(-60)), 0)
    }

    func test_garmentChangeHistoryIsFilteredAndSortedChronologically() {
        let start = Date(timeIntervalSince1970: 1_755_000_000)
        let walk = ActiveWalk(
            startDate: start,
            events: [
                WalkEvent(
                    timestamp: start.addingTimeInterval(600),
                    kind: .removedGarment,
                    garmentID: "hat"
                ),
                WalkEvent(timestamp: start.addingTimeInterval(300), kind: .sleep),
                WalkEvent(
                    timestamp: start.addingTimeInterval(120),
                    kind: .addedGarment,
                    garmentID: "hat"
                )
            ]
        )

        XCTAssertEqual(walk.garmentChangeEvents.map(\.kind), [.addedGarment, .removedGarment])
        XCTAssertEqual(walk.garmentChangeEvents.map(\.timestamp), [
            start.addingTimeInterval(120),
            start.addingTimeInterval(600)
        ])
    }

    func test_passiveWeatherUpdateRecordsOnlySignificantChangeAndKeepsStartSnapshotImmutable() throws {
        let suite = "LiveWalkTests.weather.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let start = Date(timeIntervalSince1970: 1_755_000_000)
        let startSnapshot = try XCTUnwrap(makeSnapshot(temperature: 12, capturedAt: start))
        let store = ActiveWalkStore(defaults: defaults)
        store.start(ActiveWalk(startDate: start, weatherSnapshot: startSnapshot))

        let smallChange = try XCTUnwrap(makeSnapshot(
            temperature: 13,
            capturedAt: start.addingTimeInterval(600)
        ))
        XCTAssertNil(store.recordPassiveWeatherUpdate(smallChange))
        XCTAssertEqual(store.current?.passiveWeatherUpdates?.count, 0)

        let significantChange = try XCTUnwrap(makeSnapshot(
            temperature: 8,
            capturedAt: start.addingTimeInterval(1_200)
        ))
        XCTAssertEqual(store.recordPassiveWeatherUpdate(significantChange), .becameColder)
        XCTAssertEqual(store.current?.weatherSnapshot, startSnapshot)
        XCTAssertEqual(store.current?.latestWeatherSnapshot, significantChange)
        XCTAssertEqual(ActiveWalkStore(defaults: defaults).current?.weatherSnapshot, startSnapshot)
    }

    func test_finishWithoutAnswersPersistsSkippedFeedbackAndZeroMinuteWalk() {
        let activeSuite = "LiveWalkTests.skip.active.\(UUID().uuidString)"
        let logsSuite = "LiveWalkTests.skip.logs.\(UUID().uuidString)"
        let activeDefaults = UserDefaults(suiteName: activeSuite)!
        let logsDefaults = UserDefaults(suiteName: logsSuite)!
        defer {
            activeDefaults.removePersistentDomain(forName: activeSuite)
            logsDefaults.removePersistentDomain(forName: logsSuite)
        }
        let logStore = WalkLogStore(defaults: logsDefaults)
        let store = ActiveWalkStore(defaults: activeDefaults, logStore: logStore)
        let start = Date(timeIntervalSince1970: 1_755_000_000)
        store.start(ActiveWalk(startDate: start))

        let log = store.finish(profile: nil, now: start.addingTimeInterval(-60))

        XCTAssertEqual(log?.durationMinutes, 0)
        XCTAssertEqual(log?.comfortFeedback, .skipped)
        XCTAssertEqual(log?.clothingAdjustment, .unknown)
        XCTAssertFalse(log?.personalizationEligibility(at: start).isEligible ?? true)
    }

    func test_finishPersistsOptionalComfortAndClothingAdjustment() {
        let activeSuite = "LiveWalkTests.feedback.active.\(UUID().uuidString)"
        let logsSuite = "LiveWalkTests.feedback.logs.\(UUID().uuidString)"
        let activeDefaults = UserDefaults(suiteName: activeSuite)!
        let logsDefaults = UserDefaults(suiteName: logsSuite)!
        defer {
            activeDefaults.removePersistentDomain(forName: activeSuite)
            logsDefaults.removePersistentDomain(forName: logsSuite)
        }
        let store = ActiveWalkStore(
            defaults: activeDefaults,
            logStore: WalkLogStore(defaults: logsDefaults)
        )
        let start = Date(timeIntervalSince1970: 1_755_000_000)
        store.start(ActiveWalk(startDate: start))

        let log = store.finish(
            feedback: WalkCompletionFeedback(
                comfort: .hot,
                clothingAdjustment: .removedLayer,
                garmentID: "snowsuit"
            ),
            profile: nil,
            now: start.addingTimeInterval(600)
        )

        XCTAssertEqual(log?.comfortFeedback, .hot)
        XCTAssertEqual(log?.comfortLevel, .warm)
        XCTAssertEqual(log?.clothingAdjustment, .removedLayer)
        XCTAssertEqual(log?.adjustedGarmentID, "snowsuit")
    }

    func test_unsureFeedbackIsNotPersonalizationSignal() {
        let log = WalkLog(
            date: Date(timeIntervalSince1970: 1_755_000_000),
            durationMinutes: 20,
            comfortLevel: .comfortable,
            comfortFeedback: .unsure,
            clothingAdjustment: .none,
            isLiveTracked: true
        )

        XCTAssertFalse(log.personalizationEligibility(at: log.date).isEligible)
    }

    func test_legacyWalkLogPayloadMapsComfortAndKeepsEvents() throws {
        let json = """
        {
          "id":"00000000-0000-0000-0000-000000000002",
          "date":755000000,
          "durationMinutes":30,
          "outfitItemIDs":[],
          "comfortLevel":"sweating",
          "events":[{
            "id":"00000000-0000-0000-0000-000000000003",
            "timestamp":755000600,
            "kind":"sleep"
          }],
          "isLiveTracked":true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(WalkLog.self, from: json)

        XCTAssertEqual(decoded.comfortFeedback, .hot)
        XCTAssertEqual(decoded.clothingAdjustment, .unknown)
        XCTAssertEqual(decoded.events.map(\.kind), [.sleep])
    }

    func test_legacyActiveWalkPayloadDecodesWithoutWeatherProvenance() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","startDate":755000000,"outfitItemIDs":[],"events":[]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ActiveWalk.self, from: json)

        XCTAssertNil(decoded.weatherSnapshot)
        XCTAssertNil(decoded.algorithmVersion)
        XCTAssertNil(decoded.passiveWeatherUpdates)
    }

    private func makeSnapshot(temperature: Double, capturedAt: Date) -> WeatherSnapshot? {
        WeatherSnapshot(
            provider: .openMeteo,
            temperature: temperature,
            apparentTemperature: temperature,
            precipitation: 0,
            capturedAt: capturedAt
        )
    }
}
