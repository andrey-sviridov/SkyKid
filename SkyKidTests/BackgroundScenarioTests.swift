import XCTest
@testable import SkyKid
import CoreLocation

@MainActor
final class BackgroundScenarioTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_900_000_000)

    func test_activeWalkElapsedTimeDoesNotDependOnTimezoneOrDSTCalendar() {
        let start = Date(timeIntervalSince1970: 1_900_000_000)
        let finish = start.addingTimeInterval(5_400)
        let walk = ActiveWalk(startDate: start)
        var almaty = Calendar(identifier: .gregorian)
        almaty.timeZone = TimeZone(identifier: "Asia/Almaty")!
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!

        XCTAssertNotEqual(almaty.dateComponents([.hour], from: start), newYork.dateComponents([.hour], from: start))
        XCTAssertEqual(walk.elapsedSeconds(now: finish), 5_400)
    }

    // MARK: - Phase 3 navigation and Today states

    func test_rootRouteMatrixKeepsOnboardingAheadOfLocationAndMainFlow() {
        XCTAssertEqual(RootRoute.resolve(profileExists: false, authorization: .authorizedWhenInUse), .onboarding)
        XCTAssertEqual(RootRoute.resolve(profileExists: true, authorization: .notDetermined), .locationPermission)
        XCTAssertEqual(RootRoute.resolve(profileExists: true, authorization: .denied), .locationDenied)
        XCTAssertEqual(RootRoute.resolve(profileExists: true, authorization: .authorizedWhenInUse), .main)
        XCTAssertEqual(
            RootRoute.resolve(
                profileExists: true,
                authorization: .denied,
                hasManualLocation: true
            ),
            .main
        )
    }

    func test_manualLocationPersistsAndCanSwitchBackToCurrentLocation() {
        let suiteName = "SkyKidTests.location.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let city = ManualLocation(cityName: "Алматы", latitude: 43.238, longitude: 76.945)

        let store = LocationSelectionStore(defaults: defaults)
        store.selectManualCity(city)
        XCTAssertEqual(LocationSelectionStore(defaults: defaults).selection, .manualCity(city))

        store.selectCurrentLocation()
        XCTAssertEqual(LocationSelectionStore(defaults: defaults).selection, .currentLocation)
    }

    func test_cityGeocoderFailureRemainsAnExplicitError() async {
        let geocoder = FailingCityGeocoder()

        do {
            _ = try await geocoder.location(for: "unknown")
            XCTFail("Expected geocoding to fail")
        } catch {
            XCTAssertEqual(error as? CityGeocodingError, .notFound)
        }
    }

    func test_weatherViewModelDistinguishesFreshCacheStaleCacheAndUnavailable() {
        let freshCache = CachedWeather(
            temperature: 12,
            apparentTemperature: 10,
            weatherCode: 0,
            windSpeed: 2,
            precipitation: 0,
            cityName: "Алматы",
            updatedAt: now.addingTimeInterval(-60)
        )
        let fresh = makeWeatherViewModel(cache: freshCache)
        XCTAssertEqual(fresh.contentState, .fresh(isCached: true))

        let staleCache = CachedWeather(
            temperature: 12,
            apparentTemperature: 10,
            weatherCode: 0,
            windSpeed: 2,
            precipitation: 0,
            cityName: "Алматы",
            updatedAt: now.addingTimeInterval(-7_200)
        )
        let stale = makeWeatherViewModel(cache: staleCache)
        XCTAssertEqual(stale.contentState, .cachedStale(updatedAt: staleCache.updatedAt))

        let unavailable = makeWeatherViewModel(cache: nil)
        XCTAssertEqual(
            unavailable.contentState,
            .unavailable(message: L10n.text("Погода недоступна"))
        )
    }

    func test_weatherViewModelReloadUsesPersistedCoordinateAfterCacheHydration() async {
        let coordinate = CLLocationCoordinate2D(latitude: 43.238, longitude: 76.945)
        let service = RecordingWeatherService()
        let viewModel = WeatherViewModel(
            service: service,
            outfitUseCase: BuildOutfitRecommendationUseCase(recommendationService: .shared),
            cachedWeatherProvider: { nil },
            lastCoordinateProvider: { coordinate }
        )

        await viewModel.reload()

        let fetchedCoordinate = await service.fetchedCoordinate
        XCTAssertEqual(fetchedCoordinate?.latitude, coordinate.latitude)
        XCTAssertEqual(fetchedCoordinate?.longitude, coordinate.longitude)
        XCTAssertNotNil(viewModel.weather)
    }

    func test_mainShellDefinesActiveWalkTab() {
        XCTAssertEqual(MainTab.allCases, [.today, .walk, .history, .profile])
    }

    func test_todayStateDistinguishesLoadingErrorAndStaleWeather() {
        let viewModel = TodayViewModel()

        viewModel.update(
            isLoading: true,
            error: nil,
            weather: nil,
            weatherUpdatedAt: nil,
            recommendation: nil,
            now: now
        )
        XCTAssertEqual(viewModel.state, .loading)

        viewModel.update(
            isLoading: false,
            error: "offline",
            weather: nil,
            weatherUpdatedAt: nil,
            recommendation: nil,
            now: now
        )
        XCTAssertEqual(viewModel.state, .unavailable(message: "offline"))

        viewModel.update(
            isLoading: false,
            error: nil,
            weather: makeWeather(),
            weatherUpdatedAt: now.addingTimeInterval(-120 * 60),
            recommendation: nil,
            now: now
        )
        XCTAssertEqual(viewModel.state, .stale)
    }

    func test_todayStateDoesNotRemainLoadingAfterWeatherFailure() {
        let viewModel = TodayViewModel()

        viewModel.update(
            isLoading: false,
            error: "offline",
            weather: makeWeather(),
            weatherUpdatedAt: now,
            recommendation: nil,
            now: now
        )

        XCTAssertEqual(viewModel.state, .unavailable(message: "offline"))
    }

    // MARK: - Snapshot metadata

    func test_recommendationFreshnessPolicyClassifiesBoundaryAndMissingTimestamp() {
        let policy = RecommendationFreshnessPolicy(now: now)

        XCTAssertEqual(
            policy.state(for: now.addingTimeInterval(-119 * 60)),
            .fresh
        )
        XCTAssertEqual(
            policy.state(for: now.addingTimeInterval(-120 * 60)),
            .stale
        )
        XCTAssertEqual(policy.state(for: nil), .unavailable)
    }

    func test_recommendationFreshnessPolicyRejectsFutureTimestamp() {
        let policy = RecommendationFreshnessPolicy(now: now)

        XCTAssertEqual(
            policy.state(for: now.addingTimeInterval(60)),
            .unavailable
        )
        XCTAssertNil(policy.timeUntilStale(from: now.addingTimeInterval(60)))
    }

    func test_snapshotCapturesWeatherAndWalkConditions() {
        let profile = makeProfile(name: "Snapshot")
        var context = WalkContext.standard(
            for: profile,
            availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
        )
        context.transportMode = .carrier
        context.activityLevel = .calmAwake
        context.walkType = .short

        let output = try! BuildOutfitRecommendationUseCase(
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

    func test_recommendationAlgorithmVersionIsCapturedAndRoundTrips() throws {
        let profile = makeProfile(name: "Versioned")
        let context = WalkContext.standard(
            for: profile,
            availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
        )
        let output = try BuildOutfitRecommendationUseCase(
            recommendationService: .shared,
            snapshotStore: RecordingStore()
        ).execute(
            weather: makeWeather(),
            profile: profile,
            walkContext: context,
            cityName: "Алматы",
            generatedAt: now
        )

        XCTAssertEqual(
            output.snapshot.algorithmVersion,
            OutfitRecommendationSnapshot.currentAlgorithmVersion
        )

        let decoded = try JSONDecoder().decode(
            OutfitRecommendationSnapshot.self,
            from: JSONEncoder().encode(output.snapshot)
        )
        XCTAssertEqual(decoded.algorithmVersion, output.snapshot.algorithmVersion)

        let log = WalkLog(
            date: now,
            durationMinutes: 30,
            comfortLevel: .comfortable,
            weatherTemperature: 12,
            apparentTemperature: 10
        )
        XCTAssertEqual(log.algorithmVersion, OutfitRecommendationSnapshot.currentAlgorithmVersion)
    }

    func test_useCaseBlocksUnsupportedAgeBeforeCalculationAndSnapshotSave() {
        let calendar = fixedCalendar
        let now = date("2026-09-07")
        let profile = ChildThermalProfile(
            name: "Старше года",
            gender: .girl,
            birthday: date("2025-09-06")
        )
        let context = WalkContext.standard(
            for: profile,
            availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
        )
        let store = RecordingStore()
        let useCase = BuildOutfitRecommendationUseCase(
            recommendationService: .shared,
            snapshotStore: store
        )

        XCTAssertThrowsError(
            try useCase.execute(
                weather: makeWeather(),
                profile: profile,
                walkContext: context,
                cityName: "Алматы",
                generatedAt: now,
                now: now
            )
        ) { error in
            XCTAssertEqual(
                error as? BuildOutfitRecommendationUseCase.Error,
                .unsupportedAge(.olderThanMaximum)
            )
        }
        XCTAssertNil(store.snapshot)
        XCTAssertEqual(
            ChildThermalProfile.supportedAgeScope(
                for: profile.birthday,
                now: calendar.date(byAdding: .day, value: -1, to: now)!,
                calendar: calendar
            ),
            .supported
        )
    }

    func test_savedSnapshotStopsBeingUsableAfterAgeBoundary() throws {
        let calendar = fixedCalendar
        let boundary = date("2026-09-06")
        let profile = ChildThermalProfile(
            name: "Переход",
            gender: .girl,
            birthday: date("2025-09-06")
        )
        let context = WalkContext.standard(
            for: profile,
            availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
        )
        let suiteName = "BackgroundScenarioTests.ageSnapshot.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppGroupRecommendationSnapshotStore(defaults: defaults)
        let output = try BuildOutfitRecommendationUseCase(
            recommendationService: .shared,
            snapshotStore: store
        ).execute(
            weather: makeWeather(),
            profile: profile,
            walkContext: context,
            cityName: "Алматы",
            generatedAt: boundary,
            now: boundary
        )

        XCTAssertNotNil(store.load(at: boundary))
        XCTAssertNil(store.load(at: calendar.date(byAdding: .day, value: 1, to: boundary)!))
        XCTAssertEqual(output.snapshot.childBirthday, profile.birthday)
    }

    func test_legacySnapshotWithoutContextStillDecodes() throws {
        let profile = makeProfile(name: "Legacy")
        let context = WalkContext.standard(
            for: profile,
            availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
        )
        let output = try BuildOutfitRecommendationUseCase(
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

    func test_legacyRecommendationPayloadHasUnknownAlgorithmVersion() throws {
        let profile = makeProfile(name: "Legacy algorithm")
        let context = WalkContext.standard(
            for: profile,
            availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
        )
        let snapshot = try BuildOutfitRecommendationUseCase(
            recommendationService: .shared,
            snapshotStore: RecordingStore()
        ).execute(
            weather: makeWeather(),
            profile: profile,
            walkContext: context,
            cityName: "Алматы",
            generatedAt: now
        ).snapshot

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any]
        )
        object.removeValue(forKey: "algorithmVersion")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decodedSnapshot = try JSONDecoder().decode(
            OutfitRecommendationSnapshot.self,
            from: legacyData
        )
        XCTAssertNil(decodedSnapshot.algorithmVersion)

        let log = WalkLog(
            date: now,
            durationMinutes: 30,
            comfortLevel: .comfortable,
            weatherTemperature: 12,
            apparentTemperature: 10
        )
        var logObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(log)) as? [String: Any]
        )
        logObject.removeValue(forKey: "algorithmVersion")
        let decodedLog = try JSONDecoder().decode(
            WalkLog.self,
            from: JSONSerialization.data(withJSONObject: logObject)
        )
        XCTAssertNil(decodedLog.algorithmVersion)
    }

    func test_algorithmVersionFixtureDoesNotInferFromCurrentVersion() throws {
        let profile = makeProfile(name: "Previous behavior")
        let context = WalkContext.standard(
            for: profile,
            availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
        )
        let recommendation = OutfitRecommendationService.shared.recommend(
            weather: makeWeather(),
            profile: profile,
            walkContext: context
        )
        let historicalVersion = 7
        let snapshot = OutfitRecommendationSnapshot(
            recommendation: recommendation,
            childName: profile.name,
            childAgeLabel: profile.ageLabel,
            cityName: "Алматы",
            algorithmVersion: historicalVersion,
            generatedAt: now
        )

        let decoded = try JSONDecoder().decode(
            OutfitRecommendationSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
        XCTAssertEqual(decoded.algorithmVersion, historicalVersion)
        XCTAssertNotEqual(decoded.algorithmVersion, OutfitRecommendationSnapshot.currentAlgorithmVersion)
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

        let first = try! useCase.execute(
            weather: makeWeather(),
            profile: profile,
            walkContext: context,
            cityName: "Алматы",
            generatedAt: now
        )
        let recalculated = try! useCase.execute(
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

    private var fixedCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: "\(value)T00:00:00Z")!
    }

    private func makeWeatherViewModel(cache: CachedWeather?) -> WeatherViewModel {
        let fixedNow = now
        return WeatherViewModel(
            service: BackgroundWeatherService(),
            outfitUseCase: BuildOutfitRecommendationUseCase(recommendationService: .shared),
            nowProvider: { fixedNow },
            cachedWeatherProvider: { cache }
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

private struct BackgroundWeatherService: WeatherService {
    func fetch(coordinate: CLLocationCoordinate2D) async throws -> NormalizedWeather {
        throw URLError(.notConnectedToInternet)
    }
}

private actor RecordingWeatherService: WeatherService {
    private(set) var fetchedCoordinate: CLLocationCoordinate2D?

    func fetch(coordinate: CLLocationCoordinate2D) async throws -> NormalizedWeather {
        fetchedCoordinate = coordinate
        return NormalizedWeather(
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
}

@MainActor
private struct FailingCityGeocoder: CityGeocoding {
    func location(for city: String) async throws -> ManualLocation {
        throw CityGeocodingError.notFound
    }
}
