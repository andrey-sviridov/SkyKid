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
