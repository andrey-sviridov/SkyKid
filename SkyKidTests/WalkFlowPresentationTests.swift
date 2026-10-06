import XCTest
@testable import SkyKid

@MainActor
final class WalkFlowPresentationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_900_000_000)

    func test_weatherFreshnessTurnsStaleAfterTwoHours() {
        let fresh = WeatherFreshness(
            updatedAt: now.addingTimeInterval(-119 * 60),
            now: now
        )
        let stale = WeatherFreshness(
            updatedAt: now.addingTimeInterval(-120 * 60),
            now: now
        )

        XCTAssertFalse(fresh.isStale)
        XCTAssertTrue(stale.isStale)
    }

    func test_walkOutfitVerdict_isHonestWhenRecommendationIsUnknown() {
        let verdict = WalkTOGVerdict(effective: 1.2, target: nil)

        XCTAssertNil(verdict.delta)
        XCTAssertEqual(verdict.level, .unknown)
        XCTAssertEqual(verdict.level.label, L10n.text("Проверьте комплект"))
    }

    func test_walkOutfitVerdict_usesPlainAddSuitableAndRemoveGuidance() {
        XCTAssertEqual(
            WalkTOGVerdict(effective: 0.5, target: 2).level.label,
            L10n.text("Добавьте тёплый слой")
        )
        XCTAssertEqual(
            WalkTOGVerdict(effective: 2, target: 2).level.label,
            L10n.text("Комплект подходит")
        )
        XCTAssertEqual(
            WalkTOGVerdict(effective: 3.5, target: 2).level.label,
            L10n.text("Снимите один тёплый слой")
        )
    }

    func test_undoRemovesLastEventAndRevertsGarmentChange() {
        let walk = ActiveWalk(
            startDate: now,
            weatherTemperature: 12,
            apparentTemperature: 10,
            outfitItemIDs: ["bodysuit_ss"],
            events: [
                WalkEvent(
                    timestamp: now.addingTimeInterval(60),
                    kind: .sleep
                ),
                WalkEvent(
                    timestamp: now.addingTimeInterval(120),
                    kind: .addedGarment,
                    garmentID: "fleece"
                )
            ]
        )

        let undone = WalkEventUndo.apply(to: walk)

        XCTAssertEqual(undone?.events.count, 1)
        XCTAssertEqual(undone?.events.first?.kind, .sleep)
        XCTAssertEqual(undone?.outfitItemIDs, ["bodysuit_ss"])
    }

    func test_trackedWalkWithoutWeather_staysUnknownAndDoesNotPersistTwelveDegrees() throws {
        let walk = WalkSetupSheet.makeTrackedWalk(
            startDate: now,
            plannedDurationMinutes: 30,
            weather: nil,
            recommendation: nil,
            walkContext: nil,
            outfitItemIDs: ["bodysuit_ss"]
        )

        XCTAssertNil(walk.weatherSnapshot)
        XCTAssertNil(walk.weatherCode)
        XCTAssertNil(walk.microclimateTemperature)
        XCTAssertNil(walk.weatherTemperature)
        XCTAssertNil(walk.apparentTemperature)

        let data = try JSONEncoder().encode(walk)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(payload["weatherTemperature"])
        XCTAssertNil(payload["apparentTemperature"])
    }

    func test_manualLog_doesNotBorrowCurrentWeatherOrRecommendation() {
        let log = LogWalkSheet.makeManualLog(
            date: now,
            durationMinutes: 30,
            outfitItemIDs: ["bodysuit_ss"],
            comfortLevel: .comfortable,
            temperature: nil,
            effectiveOutfitTOG: 0.3
        )

        XCTAssertNil(log.weatherTemperature)
        XCTAssertNil(log.apparentTemperature)
        XCTAssertNil(log.weatherSnapshot)
        XCTAssertNil(log.microclimateTemperature)
        XCTAssertNil(log.transportMode)
        XCTAssertNil(log.activityLevel)
        XCTAssertNil(log.walkType)
        XCTAssertNil(log.targetTOG)
    }

    func test_trackedWalkSnapshotPreservesWeatherCaptureTime() throws {
        let capturedAt = now.addingTimeInterval(-30 * 60)
        let weather = NormalizedWeather(
            temperature: 8,
            apparentTemperature: 6,
            humidity: 70,
            windSpeed: 2,
            windDirection: 0,
            precipitation: 0,
            weatherCode: 1,
            windGust: 2,
            uvIndex: 0,
            cloudCover: 50
        )

        let walk = WalkSetupSheet.makeTrackedWalk(
            startDate: now,
            plannedDurationMinutes: 30,
            weather: weather,
            weatherCapturedAt: capturedAt,
            recommendation: nil,
            walkContext: nil,
            outfitItemIDs: []
        )

        XCTAssertEqual(walk.weatherSnapshot?.capturedAt, capturedAt)
    }

    func test_historyInsightsUseOnlyRecentWalks() {
        let recentWalk = WalkLog(
            date: now.addingTimeInterval(-24 * 60 * 60),
            durationMinutes: 40,
            comfortLevel: .comfortable,
            weatherTemperature: 12,
            apparentTemperature: 10,
            events: [
                WalkEvent(
                    timestamp: now.addingTimeInterval(-23 * 60 * 60 - 30 * 60),
                    kind: .sleep
                ),
                WalkEvent(
                    timestamp: now.addingTimeInterval(-23 * 60 * 60 - 20 * 60),
                    kind: .wake
                )
            ],
            isLiveTracked: true
        )
        let secondRecentWalk = WalkLog(
            date: now.addingTimeInterval(-3 * 24 * 60 * 60),
            durationMinutes: 60,
            comfortLevel: .warm,
            weatherTemperature: 14,
            apparentTemperature: 13,
            isLiveTracked: true
        )
        let oldWalk = WalkLog(
            date: now.addingTimeInterval(-10 * 24 * 60 * 60),
            durationMinutes: 180,
            comfortLevel: .cold,
            weatherTemperature: 0,
            apparentTemperature: -2
        )

        let insights = WalkHistoryInsights.make(
            from: [recentWalk, secondRecentWalk, oldWalk],
            now: now
        )

        XCTAssertEqual(insights?.walkCount, 2)
        XCTAssertEqual(insights?.averageDurationMinutes, 50)
        XCTAssertEqual(insights?.sleepMinutes, 10)
        XCTAssertEqual(insights?.comfortablePercent, 50)
    }
}
