import XCTest
@testable import SkyKid

@MainActor
final class WalkSummaryTests: XCTestCase {
    private let startDate = Date(timeIntervalSince1970: 1_900_000_000)

    func test_summarySumsMultipleSleepIntervals() {
        let log = makeLog(events: [
            event(at: 5, kind: .sleep),
            event(at: 17, kind: .wake),
            event(at: 30, kind: .sleep),
            event(at: 42, kind: .wake)
        ])

        let summary = WalkSummaryBuilder.make(from: log)

        XCTAssertEqual(summary.sleepDurationMinutes, 24)
        XCTAssertEqual(summary.sleepSessionCount, 2)
        XCTAssertFalse(summary.isSleepInProgressAtFinish)
    }

    func test_openSleepIntervalIsCountedUntilWalkEnds() {
        let log = makeLog(
            durationMinutes: 45,
            events: [event(at: 20, kind: .sleep)]
        )

        let summary = WalkSummaryBuilder.make(from: log)

        XCTAssertEqual(summary.sleepDurationMinutes, 25)
        XCTAssertEqual(summary.sleepSessionCount, 1)
        XCTAssertTrue(summary.isSleepInProgressAtFinish)
    }

    func test_summaryCountsBassinetteAndGarmentEvents() {
        let log = makeLog(events: [
            event(at: 2, kind: .openedBassinette),
            event(at: 12, kind: .addedGarment),
            event(at: 14, kind: .removedGarment),
            event(at: 22, kind: .closedBassinette),
            event(at: 30, kind: .checkpoint)
        ])

        let summary = WalkSummaryBuilder.make(from: log)

        XCTAssertEqual(summary.bassinetteDurationMinutes, 20)
        XCTAssertEqual(summary.bassinetteSessionCount, 1)
        XCTAssertEqual(summary.garmentChangeCount, 2)
        XCTAssertEqual(summary.checkpointCount, 1)
        XCTAssertEqual(summary.eventCount, 5)
    }

    func test_summaryWithoutSleepEventsHasNoSleepValue() {
        let summary = WalkSummaryBuilder.make(from: makeLog(events: []))

        XCTAssertNil(summary.sleepDurationMinutes)
        XCTAssertEqual(summary.sleepSessionCount, 0)
        XCTAssertFalse(summary.hasSleepData)
    }

    // MARK: - Fixtures

    private func event(at minute: Int, kind: WalkEventKind) -> WalkEvent {
        WalkEvent(
            timestamp: startDate.addingTimeInterval(TimeInterval(minute * 60)),
            kind: kind
        )
    }

    private func makeLog(
        durationMinutes: Int = 60,
        events: [WalkEvent]
    ) -> WalkLog {
        WalkLog(
            date: startDate,
            durationMinutes: durationMinutes,
            comfortLevel: .comfortable,
            weatherTemperature: 12,
            apparentTemperature: 12,
            events: events,
            isLiveTracked: true
        )
    }
}
