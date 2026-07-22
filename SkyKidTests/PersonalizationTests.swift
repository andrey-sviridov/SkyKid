import XCTest
@testable import SkyKid

@MainActor
final class PersonalizationTests: XCTestCase {
    nonisolated(unsafe) private var suiteName = ""
    nonisolated(unsafe) private var defaults: UserDefaults!
    private let now = Date(timeIntervalSince1970: 1_900_000_000)

    override func setUp() {
        super.setUp()
        suiteName = "PersonalizationTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Repeated evidence

    func test_singleFeedback_doesNotChangeOffset() {
        let store = makeStore()
        let profile = makeProfile()

        store.record(
            .tooCold,
            for: profile,
            context: makeContext(),
            source: .compatibilityAPI,
            recordedAt: now
        )

        XCTAssertEqual(store.currentOffset(for: profile, context: makeContext()), 0, accuracy: 0.001)
    }

    func test_feedbacksInsideFourHours_countAsOneWalk() {
        let store = makeStore()
        let profile = makeProfile()

        for hour in 0..<4 {
            store.record(
                .tooCold,
                for: profile,
                context: makeContext(),
                source: .compatibilityAPI,
                recordedAt: now.addingTimeInterval(Double(hour - 3) * 60 * 60)
            )
        }

        XCTAssertEqual(store.currentOffset(for: profile, context: makeContext()), 0, accuracy: 0.001)
    }

    func test_twoIndependentConsistentFeedbacks_applyOneStep() {
        let store = makeStore()
        let profile = makeProfile()

        record(.tooCold, count: 2, store: store, profile: profile)

        XCTAssertEqual(
            store.currentOffset(for: profile, context: makeContext()),
            OutfitConfig.TOG.feedbackStepTOG,
            accuracy: 0.001
        )
    }

    func test_manyConsistentFeedbacks_areClamped() {
        let store = makeStore()
        let profile = makeProfile()

        record(.tooCold, count: 10, store: store, profile: profile)

        XCTAssertEqual(
            store.currentOffset(for: profile, context: makeContext()),
            OutfitConfig.TOG.maxPersonalOffsetTOG,
            accuracy: 0.001
        )
    }

    func test_comfortableFeedback_doesNotEraseLearnedOffset() {
        let store = makeStore()
        let profile = makeProfile()
        record(.tooCold, count: 3, store: store, profile: profile)
        let learned = store.currentOffset(for: profile, context: makeContext())

        store.record(
            .comfortable,
            for: profile,
            context: makeContext(),
            source: .compatibilityAPI,
            recordedAt: now
        )

        XCTAssertEqual(store.currentOffset(for: profile, context: makeContext()), learned, accuracy: 0.001)
    }

    func test_oppositeIndependentSignal_changesOffsetByAtMostOneStep() {
        let store = makeStore()
        let profile = makeProfile()
        record(.tooCold, count: 3, store: store, profile: profile)
        let previousOffset = store.currentOffset(for: profile, context: makeContext())

        store.record(
            .tooWarm,
            for: profile,
            context: makeContext(),
            source: .compatibilityAPI,
            recordedAt: now
        )

        let currentOffset = store.currentOffset(for: profile, context: makeContext())
        XCTAssertEqual(
            abs(currentOffset - previousOffset),
            OutfitConfig.TOG.feedbackStepTOG,
            accuracy: 0.001
        )
    }

    func test_feedback_isIsolatedByActivityScenario() {
        let store = makeStore()
        let profile = makeProfile()
        record(.tooCold, count: 2, store: store, profile: profile)

        XCTAssertEqual(store.currentOffset(for: profile, context: makeContext()), 0.2, accuracy: 0.001)
        XCTAssertEqual(store.currentOffset(for: profile, context: makeContext(active: true)), 0, accuracy: 0.001)
    }

    func test_sameSource_replacesPreviousObservation() {
        let store = makeStore()
        let profile = makeProfile()
        let sourceID = UUID()

        store.record(
            .tooCold,
            for: profile,
            context: makeContext(),
            sourceID: sourceID,
            source: .outfitScreen,
            recordedAt: now.addingTimeInterval(-10 * 60 * 60)
        )
        store.record(
            .comfortable,
            for: profile,
            context: makeContext(),
            sourceID: sourceID,
            source: .outfitScreen,
            recordedAt: now
        )

        let summary = store.summary(for: profile, context: makeContext())
        XCTAssertEqual(summary.totalProfileObservationCount, 1)
        XCTAssertEqual(summary.comfortableConfirmationCount, 1)
        XCTAssertEqual(summary.appliedOffset, 0, accuracy: 0.001)
    }

    // MARK: - Persistence and journal synchronization

    func test_versionOneOffset_isMigratedAndCanBeReset() throws {
        let profile = makeProfile(name: "Migration")
        let profileKey = storageProfileKey(for: profile)
        let legacyMap = [TempBand.cold.rawValue: 0.6]
        defaults.set(try JSONEncoder().encode(legacyMap), forKey: "tog_offset_v1_\(profileKey)")
        defaults.set([profileKey], forKey: "tog_offset_v1_index")

        let store = makeStore()
        XCTAssertEqual(store.currentOffset(for: profile, context: makeContext()), 0.6, accuracy: 0.001)

        store.clearOffset(for: profile)
        XCTAssertEqual(store.currentOffset(for: profile, context: makeContext()), 0, accuracy: 0.001)
        XCTAssertNil(defaults.data(forKey: "tog_personalization_v2_\(profileKey)"))
    }

    func test_walkLogUpdateAndDelete_keepObservationInSync() {
        let personalStore = makeStore()
        let logStore = WalkLogStore(defaults: defaults, personalizationStore: personalStore)
        let profile = makeChildProfile()
        let first = makeLog(date: now.addingTimeInterval(-10 * 60 * 60), comfort: .cold)
        var second = makeLog(date: now.addingTimeInterval(-5 * 60 * 60), comfort: .cold)

        logStore.add(first, profile: profile)
        logStore.add(second, profile: profile)
        XCTAssertEqual(
            personalStore.currentOffset(for: profile.thermalProfile, context: makeContext()),
            0.2,
            accuracy: 0.001
        )

        second.comfortLevel = .comfortable
        logStore.update(second, profile: profile)
        XCTAssertEqual(
            personalStore.currentOffset(for: profile.thermalProfile, context: makeContext()),
            0,
            accuracy: 0.001
        )

        guard let firstIndex = logStore.logs.firstIndex(where: { $0.id == first.id }) else {
            return XCTFail("First log must exist")
        }
        logStore.delete(at: IndexSet(integer: firstIndex))
        let summary = personalStore.summary(for: profile.thermalProfile, context: makeContext())
        XCTAssertEqual(summary.totalProfileObservationCount, 1)
    }

    // MARK: - Fixtures

    private func makeStore() -> PersonalOffsetStore {
        PersonalOffsetStore(defaults: defaults, nowProvider: { [now] in now })
    }

    private func makeChildProfile(name: String = "Лиза") -> ChildProfile {
        ChildProfile(
            name: name,
            gender: .girl,
            birthday: Date(timeIntervalSince1970: 1_850_000_000)
        )
    }

    private func makeProfile(name: String = "Лиза") -> ChildThermalProfile {
        makeChildProfile(name: name).thermalProfile
    }

    private func makeContext(active: Bool = false) -> PersonalizationContext {
        PersonalizationContext(
            microclimateTemperature: 5,
            transportMode: active ? .walking : .pushchairSeat,
            activityLevel: active ? .walkingCrawling : .calmAwake,
            walkType: .regular
        )
    }

    private func record(
        _ feedback: UserFeedback,
        count: Int,
        store: PersonalOffsetStore,
        profile: ChildThermalProfile
    ) {
        for index in 0..<count {
            store.record(
                feedback,
                for: profile,
                context: makeContext(),
                source: .compatibilityAPI,
                recordedAt: now.addingTimeInterval(Double(index - count) * 5 * 60 * 60)
            )
        }
    }

    private func makeLog(date: Date, comfort: BabyComfortLevel) -> WalkLog {
        WalkLog(
            date: date,
            durationMinutes: 30,
            comfortLevel: comfort,
            weatherTemperature: 4,
            apparentTemperature: 5,
            microclimateTemperature: 5,
            transportMode: .pushchairSeat,
            activityLevel: .calmAwake,
            walkType: .regular
        )
    }

    private func storageProfileKey(for profile: ChildThermalProfile) -> String {
        let timestamp = Int(profile.birthday.timeIntervalSince1970)
        let safeName = profile.name.filter { $0.isLetter || $0.isNumber }
        return "\(safeName)_\(timestamp)"
    }
}
