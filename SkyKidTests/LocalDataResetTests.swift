import XCTest
@testable import SkyKid

@MainActor
final class LocalDataResetTests: XCTestCase {
    func test_cancelIsNoOpAndConfirmedResetClearsRegisteredDomains() throws {
        let fixture = ResetFixture()
        defer { fixture.cleanup() }
        let profile = ChildProfile(name: "Лиза", gender: .girl, birthday: .now)
        fixture.profileStore.replaceForRestore(with: profile)
        fixture.walkStore.replaceForRestore(with: [WalkLog(durationMinutes: 10, comfortLevel: .comfortable)])
        fixture.defaults.set("secret", forKey: "owmApiKey")
        fixture.defaults.set(Data([0x01]), forKey: AppGroupRecommendationSnapshotStore.storageKey)
        let activeWalk = ActiveWalk(outfitItemIDs: ["jeans"])
        XCTAssertEqual(fixture.active.start(activeWalk), .started)

        XCTAssertThrowsError(try fixture.reset.reset(confirmed: false))
        XCTAssertNotNil(fixture.profileStore.profile)

        try fixture.reset.reset(confirmed: true)
        XCTAssertNil(fixture.profileStore.profile)
        XCTAssertTrue(fixture.walkStore.logs.isEmpty)
        XCTAssertTrue(fixture.personalization.exportStates().isEmpty)
        XCTAssertNil(fixture.defaults.object(forKey: "owmApiKey"))
        XCTAssertNil(fixture.context.context)
        XCTAssertNil(fixture.active.current)
        XCTAssertNil(fixture.defaults.object(forKey: ActiveWalkStorage.key))
        XCTAssertNil(fixture.defaults.object(forKey: AppGroupRecommendationSnapshotStore.storageKey))

        let relaunchedProfileStore = ChildProfileStore(defaults: fixture.defaults)
        let relaunchedPersonalization = PersonalOffsetStore(defaults: fixture.defaults)
        let relaunchedWalkStore = WalkLogStore(
            defaults: fixture.defaults,
            personalizationStore: relaunchedPersonalization
        )
        XCTAssertNil(relaunchedProfileStore.profile)
        XCTAssertTrue(relaunchedWalkStore.logs.isEmpty)
        XCTAssertTrue(relaunchedPersonalization.exportStates().isEmpty)
    }

    func test_failureRollsBackProfileAndWalks() throws {
        let fixture = ResetFixture(failAt: .wardrobe)
        defer { fixture.cleanup() }
        let profile = ChildProfile(name: "Лиза", gender: .girl, birthday: .now)
        let log = WalkLog(durationMinutes: 15, comfortLevel: .comfortable)
        fixture.profileStore.replaceForRestore(with: profile)
        fixture.walkStore.replaceForRestore(with: [log])

        XCTAssertThrowsError(try fixture.reset.reset(confirmed: true))
        XCTAssertEqual(fixture.profileStore.profile?.id, profile.id)
        XCTAssertEqual(fixture.walkStore.logs.map(\.id), [log.id])
    }
}

@MainActor
private final class ResetFixture {
    let suiteName = "ResetTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let profileStore: ChildProfileStore
    let personalization: PersonalOffsetStore
    let walkStore: WalkLogStore
    let wardrobe: UserWardrobeStore
    let context = WalkContextStore()
    let active: ActiveWalkStore
    let backup: LocalBackupService
    let reset: LocalDataResetService

    init(failAt: LocalDataResetService.Step? = nil) {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        profileStore = ChildProfileStore(defaults: defaults)
        personalization = PersonalOffsetStore(defaults: defaults)
        walkStore = WalkLogStore(defaults: defaults, personalizationStore: personalization)
        wardrobe = UserWardrobeStore(defaults: defaults)
        backup = LocalBackupService(
            profileStore: profileStore, walkStore: walkStore,
            personalizationStore: personalization, wardrobeStore: wardrobe,
            appDefaults: defaults, standardDefaults: defaults
        )
        active = ActiveWalkStore(defaults: defaults, logStore: walkStore)
        reset = LocalDataResetService(
            profileStore: profileStore, walkStore: walkStore, activeWalkStore: active,
            personalizationStore: personalization, wardrobeStore: wardrobe,
            recommendationStore: AppGroupRecommendationSnapshotStore(defaults: defaults),
            walkContextStore: context, backupService: backup, defaults: defaults,
            beforeStep: { if $0 == failAt { throw ResetFixtureError.forced } }
        )
    }

    func cleanup() { defaults.removePersistentDomain(forName: suiteName) }
}

private enum ResetFixtureError: Error { case forced }
