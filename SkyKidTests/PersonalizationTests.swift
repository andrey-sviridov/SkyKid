import XCTest
import Observation
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

    func test_similarContextRequiresMatchingTransportActivityAndWalkType() {
        let store = makeStore()
        let profile = makeProfile()
        record(.tooCold, count: 2, store: store, profile: profile)

        let differentTransport = PersonalizationContext(
            microclimateTemperature: 5,
            transportMode: .carrier,
            activityLevel: .calmAwake,
            walkType: .regular
        )
        let differentWalkType = PersonalizationContext(
            microclimateTemperature: 5,
            transportMode: .pushchairSeat,
            activityLevel: .calmAwake,
            walkType: .short
        )

        XCTAssertEqual(store.currentOffset(for: profile, context: differentTransport), 0, accuracy: 0.001)
        XCTAssertEqual(store.currentOffset(for: profile, context: differentWalkType), 0, accuracy: 0.001)
    }

    func test_typedWeatherInsulationAndDurationBucketsSeparateEvidence() {
        let store = makeStore()
        let profile = makeProfile()
        let rainyMedium = makeContext(
            weatherCode: 61,
            outfitTOG: 1.5,
            durationMinutes: 45
        )
        for index in 0..<2 {
            store.record(
                .tooCold,
                for: profile,
                context: rainyMedium,
                source: .walkLog,
                recordedAt: now.addingTimeInterval(Double(index - 2) * 5 * 60 * 60)
            )
        }

        XCTAssertEqual(store.currentOffset(for: profile, context: rainyMedium), 0.2, accuracy: 0.001)
        XCTAssertEqual(
            store.currentOffset(
                for: profile,
                context: makeContext(weatherCode: 0, outfitTOG: 1.5, durationMinutes: 45)
            ),
            0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            store.currentOffset(
                for: profile,
                context: makeContext(weatherCode: 61, outfitTOG: 3, durationMinutes: 45)
            ),
            0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            store.currentOffset(
                for: profile,
                context: makeContext(weatherCode: 61, outfitTOG: 1.5, durationMinutes: 100)
            ),
            0,
            accuracy: 0.001
        )
    }

    func test_clothingAdjustmentTurnsComfortableWalkIntoDirectionalEvidence() {
        let store = makeStore()
        let profile = makeProfile()
        let context = makeContext(clothingAdjustment: .addedLayer)

        for index in 0..<2 {
            store.record(
                .comfortable,
                for: profile,
                context: context,
                source: .walkLog,
                recordedAt: now.addingTimeInterval(Double(index - 2) * 5 * 60 * 60)
            )
        }

        let summary = store.summary(for: profile, context: context)
        XCTAssertEqual(summary.appliedOffset, 0.2, accuracy: 0.001)
        XCTAssertEqual(summary.explanation, .prefersWarmer(evidenceCount: 2))
        XCTAssertEqual(summary.evidenceContext.transportMode, .pushchairSeat)
        XCTAssertEqual(summary.evidenceContext.temperatureBand, .cold)
    }

    func test_sparseAndOpposingEvidenceHaveHonestExplanations() {
        let store = makeStore()
        let profile = makeProfile()
        store.record(
            .tooCold,
            for: profile,
            context: makeContext(),
            source: .walkLog,
            recordedAt: now.addingTimeInterval(-10 * 60 * 60)
        )

        XCTAssertEqual(
            store.summary(for: profile, context: makeContext()).explanation,
            .insufficientEvidence(similarWalkCount: 1)
        )

        store.record(
            .tooWarm,
            for: profile,
            context: makeContext(),
            source: .walkLog,
            recordedAt: now.addingTimeInterval(-5 * 60 * 60)
        )
        let summary = store.summary(for: profile, context: makeContext())
        XCTAssertEqual(summary.appliedOffset, 0, accuracy: 0.001)
        XCTAssertEqual(summary.explanation, .balanced(evidenceCount: 2))
    }

    func test_expiredEvidenceDoesNotAffectSimilarityOrOffset() {
        let store = makeStore()
        let profile = makeProfile()
        for index in 0..<2 {
            store.record(
                .tooCold,
                for: profile,
                context: makeContext(),
                source: .walkLog,
                recordedAt: now.addingTimeInterval(-PersonalizationPolicy.observationLifetime - Double(index + 1) * 5 * 60 * 60)
            )
        }

        let summary = store.summary(for: profile, context: makeContext())
        XCTAssertEqual(summary.appliedOffset, 0, accuracy: 0.001)
        XCTAssertEqual(summary.similarObservationCount, 0)
        XCTAssertEqual(summary.explanation, .insufficientEvidence(similarWalkCount: 0))
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

    func test_legacyOutfitScreenFeedback_decodesWithoutMigration() throws {
        let context = makeContext()

        let observation = PersonalizationObservation(
            sourceID: UUID(),
            recordedAt: now,
            feedback: .tooCold,
            source: .outfitScreen,
            context: context
        )
        let decoded = try JSONDecoder().decode(
            PersonalizationObservation.self,
            from: JSONEncoder().encode(observation)
        )

        XCTAssertEqual(decoded, observation)
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

    // MARK: - Stable child identity

    func test_legacyProfile_getsUUIDThatSurvivesRoundTrip() throws {
        let legacyJSON = """
        {"name":"Лиза","gender":"girl","birthday":1850000000}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ChildProfile.self, from: legacyJSON)
        let roundTripped = try JSONDecoder().decode(
            ChildProfile.self,
            from: JSONEncoder().encode(decoded)
        )

        XCTAssertFalse(decoded.id.uuidString.isEmpty)
        XCTAssertEqual(roundTripped.id, decoded.id)
    }

    func test_renameWithSameUUID_retainsObservations() {
        let store = makeStore()
        let original = makeChildProfile(name: "Лиза")
        var renamed = ChildProfile(
            id: original.id,
            name: "Елизавета",
            gender: original.gender,
            birthday: original.birthday
        )
        renamed.stableTraits = original.stableTraits

        record(.tooCold, count: 2, store: store, profile: original)

        let summary = store.summary(for: renamed, context: makeContext())
        XCTAssertEqual(summary.totalProfileObservationCount, 2)
        XCTAssertEqual(summary.appliedOffset, OutfitConfig.TOG.feedbackStepTOG, accuracy: 0.001)
    }

    func test_distinctUUIDs_keepPersonalizationIsolated() {
        let store = makeStore()
        let first = makeChildProfile(name: "Лиза")
        let second = ChildProfile(
            id: UUID(),
            name: first.name,
            gender: first.gender,
            birthday: first.birthday
        )

        record(.tooCold, count: 2, store: store, profile: first)
        record(.tooWarm, count: 2, store: store, profile: second)

        XCTAssertEqual(store.currentOffset(for: first, tMicro: 5), 0.2, accuracy: 0.001)
        XCTAssertEqual(store.currentOffset(for: second, tMicro: 5), -0.2, accuracy: 0.001)
    }

    func test_legacyObservations_migrateExactlyOnceToUUID() {
        let store = makeStore()
        let legacyProfile = makeChildProfile(name: "Legacy-\(UUID().uuidString)")
        let migratedProfile = ChildProfile(
            name: "Переименованный",
            gender: legacyProfile.gender,
            birthday: legacyProfile.birthday
        )

        record(.tooCold, count: 2, store: store, profile: legacyProfile.thermalProfile)
        store.migrateLegacyIdentity(from: legacyProfile, to: migratedProfile)
        store.migrateLegacyIdentity(from: legacyProfile, to: migratedProfile)

        let summary = store.summary(for: migratedProfile, context: makeContext())
        XCTAssertEqual(summary.totalProfileObservationCount, 2)
        XCTAssertNil(defaults.data(forKey: "tog_personalization_v2_\(storageProfileKey(for: legacyProfile.thermalProfile))"))
        XCTAssertNotNil(defaults.data(forKey: "tog_personalization_v2_\(migratedProfile.id.uuidString)"))
    }

    func test_feedbackHistoryReadDoesNotInvalidateObservableState() {
        let store = makeStore()
        let profile = makeChildProfile()
        store.record(
            .tooCold,
            for: profile,
            context: makeContext(),
            source: .outfitScreen,
            recordedAt: now
        )
        let invalidation = ObservationInvalidationBox()

        withObservationTracking {
            _ = store.statesByProfile
        } onChange: {
            invalidation.value = true
        }

        _ = store.feedbackHistory(for: profile)

        XCTAssertFalse(invalidation.value)
    }

    func test_legacyProfileMigration_persistsUUIDAndSurvivesRestart() throws {
        let legacyJSON = """
        {"name":"Лиза","gender":"girl","birthday":1850000000}
        """.data(using: .utf8)!
        let legacyProfile = try JSONDecoder().decode(ChildProfile.self, from: legacyJSON)
        let legacyKey = storageProfileKey(for: legacyProfile.thermalProfile)
        let legacyOffsets = [TempBand.cold.rawValue: 0.6]

        defaults.set(legacyJSON, forKey: AppGroup.profileKey)
        defaults.set(try JSONEncoder().encode(legacyOffsets), forKey: "tog_offset_v1_\(legacyKey)")
        defaults.set([legacyKey], forKey: "tog_offset_v1_index")

        let firstStore = makeStore()
        let firstProfile = try XCTUnwrap(loadStoredProfileForTest())
        let firstID = firstProfile.id

        XCTAssertEqual(
            firstStore.currentOffset(for: firstProfile, context: makeContext()),
            0.6,
            accuracy: 0.001
        )
        XCTAssertNotNil(defaults.data(forKey: AppGroup.profileKey))
        XCTAssertNotNil(defaults.data(forKey: "tog_personalization_v2_\(firstID.uuidString)"))

        // A new store instance models the next app launch. The profile and
        // personalization must resolve to the same UUID and baseline.
        let secondStore = makeStore()
        let secondProfile = try XCTUnwrap(loadStoredProfileForTest())

        XCTAssertEqual(secondProfile.id, firstID)
        XCTAssertEqual(
            secondStore.currentOffset(for: secondProfile, context: makeContext()),
            0.6,
            accuracy: 0.001
        )
        XCTAssertNil(defaults.data(forKey: "tog_offset_v1_\(legacyKey)"))
    }

    func test_profileStoreEdit_preservesImmutableUUID() {
        let profileStore = ChildProfileStore.shared
        let previousProfile = profileStore.profile
        defer { profileStore.profile = previousProfile }

        let original = makeChildProfile(name: "Лиза")
        profileStore.profile = original

        var edited = original
        edited.name = "Елизавета"
        profileStore.profile = edited

        XCTAssertEqual(profileStore.profile?.id, original.id)
        XCTAssertEqual(profileStore.profile?.name, "Елизавета")
    }

    func test_walkLogUpdateAndDelete_keepObservationInSync() {
        let personalStore = makeStore()
        let logStore = WalkLogStore(
            defaults: defaults,
            personalizationStore: personalStore,
            nowProvider: { [now] in now }
        )
        let profile = makeChildProfile()
        let first = makeLog(date: now.addingTimeInterval(-10 * 60 * 60), comfort: .cold)
        var second = makeLog(date: now.addingTimeInterval(-5 * 60 * 60), comfort: .cold)

        logStore.add(first, profile: profile)
        logStore.add(second, profile: profile)
        XCTAssertEqual(
            personalStore.currentOffset(for: profile, context: makeContext()),
            0.2,
            accuracy: 0.001
        )

        second.comfortLevel = .comfortable
        logStore.update(second, profile: profile)
        XCTAssertEqual(
            personalStore.currentOffset(for: profile, context: makeContext()),
            0,
            accuracy: 0.001
        )

        guard let firstIndex = logStore.logs.firstIndex(where: { $0.id == first.id }) else {
            return XCTFail("First log must exist")
        }
        logStore.delete(at: IndexSet(integer: firstIndex))
        let summary = personalStore.summary(for: profile, context: makeContext())
        XCTAssertEqual(summary.totalProfileObservationCount, 1)
    }

    func test_editingHistoricalWalk_evaluatesFreshnessAtWalkDate() {
        let personalStore = makeStore()
        let logStore = makeLogStore(personalStore: personalStore)
        let profile = makeChildProfile()
        let walkDate = now.addingTimeInterval(-10 * 60 * 60)
        var log = makeLog(date: walkDate, comfort: .cold)

        logStore.add(log, profile: profile)
        XCTAssertEqual(
            personalStore.summary(for: profile, context: makeContext()).totalProfileObservationCount,
            1
        )

        log.comfortLevel = .comfortable
        logStore.update(log, profile: profile)

        XCTAssertEqual(
            personalStore.summary(for: profile, context: makeContext()).totalProfileObservationCount,
            1
        )
        XCTAssertEqual(
            personalStore.summary(for: profile, context: makeContext()).comfortableConfirmationCount,
            1
        )
    }

    // MARK: - Walk origin and training eligibility

    func test_manualWalk_remainsInHistory_butDoesNotCreateObservation() {
        let personalStore = makeStore()
        let logStore = makeLogStore(personalStore: personalStore)
        let manual = WalkLog(
            date: now,
            durationMinutes: 30,
            comfortLevel: .cold,
            weatherTemperature: 5,
            apparentTemperature: 5,
            origin: .manual
        )

        logStore.add(manual, profile: makeChildProfile())

        XCTAssertEqual(logStore.logs.count, 1)
        XCTAssertEqual(
            manual.personalizationEligibility(at: now),
            .excluded(.manualWalk)
        )
        XCTAssertEqual(
            personalStore.summary(for: makeChildProfile(), context: makeContext())
                .totalProfileObservationCount,
            0
        )
    }

    func test_trackedWalkWithFreshKnownSnapshot_createsObservation() {
        let personalStore = makeStore()
        let logStore = makeLogStore(personalStore: personalStore)
        let profile = makeChildProfile()
        let tracked = makeLog(date: now, comfort: .cold)

        logStore.add(tracked, profile: profile)

        XCTAssertEqual(tracked.personalizationEligibility(at: now), .eligible)
        XCTAssertEqual(
            personalStore.summary(for: profile, context: makeContext())
                .totalProfileObservationCount,
            1
        )
    }

    func test_staleAndUnknownWeatherProvenance_doNotTrain() throws {
        let personalStore = makeStore()
        let logStore = makeLogStore(personalStore: personalStore)
        let staleSnapshot = try XCTUnwrap(makeSnapshot(capturedAt: now.addingTimeInterval(-3 * 60 * 60)))
        let stale = makeLog(date: now, comfort: .cold, snapshot: staleSnapshot)
        let unknownSnapshot = try XCTUnwrap(
            WeatherSnapshot(
                provider: .manual,
                temperature: 5,
                fieldStatuses: temperatureStatus,
                capturedAt: now
            )
        )
        let unknown = makeLog(date: now, comfort: .cold, snapshot: unknownSnapshot)

        logStore.add(stale, profile: makeChildProfile())
        logStore.add(unknown, profile: makeChildProfile())

        XCTAssertEqual(
            stale.personalizationEligibility(at: now),
            .excluded(.staleWeatherSnapshot)
        )
        XCTAssertEqual(
            unknown.personalizationEligibility(at: now),
            .excluded(.unknownWeatherProvenance)
        )
        XCTAssertEqual(
            personalStore.summary(for: makeChildProfile(), context: makeContext())
                .totalProfileObservationCount,
            0
        )
    }

    func test_trackedWalkWithMissingContext_doesNotUseDefaultsForTraining() {
        let personalStore = makeStore()
        let logStore = makeLogStore(personalStore: personalStore)
        let log = WalkLog(
            date: now,
            durationMinutes: 30,
            comfortLevel: .cold,
            weatherTemperature: 5,
            apparentTemperature: 5,
            isLiveTracked: true,
            origin: .tracked,
            weatherSnapshot: makeSnapshot()
        )

        logStore.add(log, profile: makeChildProfile())

        XCTAssertEqual(
            log.personalizationEligibility(at: now),
            .excluded(.missingWalkContext)
        )
        XCTAssertEqual(
            personalStore.summary(for: makeChildProfile(), context: makeContext())
                .totalProfileObservationCount,
            0
        )
    }

    func test_legacyTrackedWalkWithoutProvenance_isConservativelyIneligible() throws {
        let legacyLog = makeLog(date: now, comfort: .cold)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(legacyLog)
            ) as? [String: Any]
        )
        object.removeValue(forKey: "origin")
        object.removeValue(forKey: "weatherSnapshot")
        let data = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(WalkLog.self, from: data)

        XCTAssertEqual(decoded.origin, .tracked)
        XCTAssertEqual(
            decoded.personalizationEligibility(at: now),
            .excluded(.missingWeatherSnapshot)
        )
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

    private func makeContext(
        active: Bool = false,
        weatherCode: Int? = nil,
        outfitTOG: Double? = nil,
        durationMinutes: Int? = nil,
        clothingAdjustment: ClothingAdjustment? = nil
    ) -> PersonalizationContext {
        PersonalizationContext(
            microclimateTemperature: 5,
            transportMode: active ? .walking : .pushchairSeat,
            activityLevel: active ? .walkingCrawling : .calmAwake,
            walkType: .regular,
            effectiveOutfitTOG: outfitTOG,
            durationMinutes: durationMinutes,
            weatherCode: weatherCode,
            clothingAdjustment: clothingAdjustment
        )
    }

    private func record(
        _ feedback: UserFeedback,
        count: Int,
        store: PersonalOffsetStore,
        profile: ChildProfile
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
        makeLog(
            date: date,
            comfort: comfort,
            snapshot: makeSnapshot(capturedAt: date.addingTimeInterval(-60))
        )
    }

    private func makeLog(
        date: Date,
        comfort: BabyComfortLevel,
        snapshot: WeatherSnapshot?
    ) -> WalkLog {
        WalkLog(
            date: date,
            durationMinutes: 30,
            comfortLevel: comfort,
            weatherTemperature: 4,
            apparentTemperature: 5,
            microclimateTemperature: 5,
            transportMode: .pushchairSeat,
            activityLevel: .calmAwake,
            walkType: .regular,
            isLiveTracked: true,
            origin: .tracked,
            weatherSnapshot: snapshot
        )
    }

    private func makeLogStore(personalStore: PersonalOffsetStore) -> WalkLogStore {
        WalkLogStore(
            defaults: defaults,
            personalizationStore: personalStore,
            nowProvider: { [now] in now }
        )
    }

    private let temperatureStatus = [
        WeatherSnapshotField.temperature: WeatherSnapshotFieldStatus(
            origin: .provider,
            quality: .observed,
            note: nil
        )
    ]

    private func makeSnapshot(capturedAt: Date? = nil) -> WeatherSnapshot? {
        WeatherSnapshot(
            provider: .openMeteo,
            temperature: 5,
            fieldStatuses: temperatureStatus,
            capturedAt: capturedAt ?? now.addingTimeInterval(-60)
        )
    }

    private func storageProfileKey(for profile: ChildThermalProfile) -> String {
        let timestamp = Int(profile.birthday.timeIntervalSince1970)
        let safeName = profile.name.filter { $0.isLetter || $0.isNumber }
        return "\(safeName)_\(timestamp)"
    }

    private func loadStoredProfileForTest() -> ChildProfile? {
        guard let data = defaults.data(forKey: AppGroup.profileKey) else { return nil }
        return try? JSONDecoder().decode(ChildProfile.self, from: data)
    }
}

private final class ObservationInvalidationBox: @unchecked Sendable {
    var value = false
}
