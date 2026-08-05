import XCTest
@testable import SkyKid

@MainActor
final class BackgroundScenarioTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_900_000_000)

    // MARK: - Snapshot metadata

    func test_snapshotCapturesWeatherAndWalkConditions() {
        let profile = makeProfile(name: "Snapshot")
        var context = WalkContext.standard(
            for: profile,
            availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
        )
        context.transportMode = .carrier
        context.activityLevel = .calmAwake
        context.walkType = .short

        let output = BuildOutfitRecommendationUseCase(
            recommendationService: .shared,
            snapshotStore: RecordingStore()
        ).execute(
            weather: makeWeather(),
            profile: profile,
            walkContext: context,
            cityName: "Алматы",
            generatedAt: now
        )

        XCTAssertEqual(output.snapshot.generatedAt, now)
        XCTAssertEqual(output.snapshot.context?.transport, "Слинг / эргорюкзак")
        XCTAssertEqual(output.snapshot.context?.activity, BabyActivityLevel.calmAwake.label)
        XCTAssertEqual(output.snapshot.context?.walkType, WalkType.short.label)
        XCTAssertEqual(output.snapshot.context?.weatherSource, WeatherSource.manual.displayName)
        XCTAssertFalse(output.snapshot.context?.weatherCondition.isEmpty ?? true)
    }

    func test_legacySnapshotWithoutContextStillDecodes() throws {
        let profile = makeProfile(name: "Legacy")
        let context = WalkContext.standard(
            for: profile,
            availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
        )
        let output = BuildOutfitRecommendationUseCase(
            recommendationService: .shared,
            snapshotStore: RecordingStore()
        ).execute(
            weather: makeWeather(),
            profile: profile,
            walkContext: context,
            cityName: "Алматы",
            generatedAt: now
        )
        let encoded = try JSONEncoder().encode(output.snapshot)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "context")

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(
            OutfitRecommendationSnapshot.self,
            from: legacyData
        )

        XCTAssertNil(decoded.context)
        XCTAssertEqual(decoded.recommendation, output.recommendation)
    }

    func test_recalculationOnTheSameWeatherDoesNotExtendFreshness() {
        let profile = makeProfile(name: "Freshness")
        let context = WalkContext.standard(
            for: profile,
            availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
        )
        let useCase = BuildOutfitRecommendationUseCase(
            recommendationService: .shared,
            snapshotStore: RecordingStore()
        )

        let first = useCase.execute(
            weather: makeWeather(),
            profile: profile,
            walkContext: context,
            cityName: "Алматы",
            generatedAt: now
        )
        let recalculated = useCase.execute(
            weather: makeWeather(),
            profile: profile,
            walkContext: context,
            cityName: "Алматы",
            generatedAt: first.snapshot.generatedAt
        )

        XCTAssertEqual(recalculated.snapshot.expiresAt, first.snapshot.expiresAt)
        XCTAssertFalse(recalculated.snapshot.isFresh(at: first.snapshot.expiresAt))
    }

    // MARK: - Feedback history

    func test_feedbackHistoryIsProfileScopedNewestFirstAndLimited() {
        let suiteName = "BackgroundScenarioTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = PersonalOffsetStore(defaults: defaults, nowProvider: { [now] in now })
        let profile = makeProfile(name: "History")
        let otherProfile = makeProfile(name: "Other")

        record(.tooCold, at: now.addingTimeInterval(-3_600), for: profile, in: store)
        record(.comfortable, at: now.addingTimeInterval(-1_800), for: profile, in: store)
        record(.tooWarm, at: now.addingTimeInterval(-7_200), for: profile, in: store)
        record(.tooWarm, at: now, for: otherProfile, in: store)

        let history = store.feedbackHistory(for: profile, limit: 2)

        XCTAssertEqual(history.map(\.feedback), [.comfortable, .tooCold])
        XCTAssertEqual(history.count, 2)
        XCTAssertTrue(history.allSatisfy { $0.context.transportMode == .pushchairSeat })
    }

    func test_feedbackHistoryBuilderExplainsSourceAndContext() {
        let observation = PersonalizationObservation(
            sourceID: UUID(),
            recordedAt: now,
            feedback: .tooCold,
            source: .walkLog,
            context: makePersonalizationContext()
        )

        let item = FeedbackHistoryItemBuilder.make(from: [observation]).first

        XCTAssertEqual(item?.title, "Ребёнку было холодно")
        XCTAssertEqual(item?.source, "Журнал прогулки")
        XCTAssertTrue(item?.context.contains("Прогулочная коляска") == true)
        XCTAssertTrue(item?.context.contains("5°C") == true)
    }

    // MARK: - Safe reminders

    func test_dailyReminderNeverRepeatsAnOutfitOrTemperature() {
        let reminder = SafeReminderContentFactory.dailyWeatherRefresh()
        let text = (reminder.title + " " + reminder.body).lowercased()

        XCTAssertTrue(text.contains("обнов"))
        XCTAssertFalse(text.contains("куртк"))
        XCTAssertFalse(text.contains("°"))
    }

    func test_walkWindowReminderAvoidsSafetyGuaranteeAndRequestsRefresh() {
        let reminder = SafeReminderContentFactory.suitableWalkWindow(start: now)
        let text = (reminder.title + " " + reminder.body).lowercased()
        let expectedTime = now.formatted(
            Date.FormatStyle.dateTime.hour(.twoDigits(amPM: .omitted)).minute()
        )

        XCTAssertTrue(text.contains("более подходящее"))
        XCTAssertTrue(reminder.body.contains(expectedTime))
        XCTAssertTrue(text.contains("обновите погоду"))
        XCTAssertTrue(text.contains("самочувствие"))
        XCTAssertFalse(text.contains("(time)"))
        XCTAssertFalse(text.contains("безопас"))
        XCTAssertFalse(text.contains("условия подходят"))
    }

    // MARK: - Fixtures

    private func makeProfile(name: String) -> ChildThermalProfile {
        ChildThermalProfile(
            name: name,
            gender: .girl,
            birthday: Calendar.current.date(byAdding: .month, value: -8, to: now) ?? now
        )
    }

    private func makeWeather() -> NormalizedWeather {
        NormalizedWeather(
            temperature: 12,
            apparentTemperature: 10,
            humidity: 65,
            windSpeed: 3,
            windDirection: 180,
            precipitation: 0,
            weatherCode: 2,
            windGust: 4,
            uvIndex: 2,
            cloudCover: 50
        )
    }

    private func makePersonalizationContext() -> PersonalizationContext {
        PersonalizationContext(
            microclimateTemperature: 5,
            transportMode: .pushchairSeat,
            activityLevel: .calmAwake,
            walkType: .regular
        )
    }

    private func record(
        _ feedback: UserFeedback,
        at date: Date,
        for profile: ChildThermalProfile,
        in store: PersonalOffsetStore
    ) {
        store.record(
            feedback,
            for: profile,
            context: makePersonalizationContext(),
            source: .outfitScreen,
            recordedAt: date
        )
    }

}

// MARK: - RecordingStore

private final class RecordingStore: RecommendationSnapshotStoring {
    private(set) var snapshot: OutfitRecommendationSnapshot?

    func save(_ snapshot: OutfitRecommendationSnapshot) {
        self.snapshot = snapshot
    }

    func load() -> OutfitRecommendationSnapshot? {
        snapshot
    }

    func clear() {
        snapshot = nil
    }
}
