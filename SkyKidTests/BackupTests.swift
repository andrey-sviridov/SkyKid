import XCTest
@testable import SkyKid

@MainActor
final class BackupTests: XCTestCase {
    func test_roundTripPreservesUUIDWalksPersonalizationAndWardrobe() throws {
        let fixture = makeFixture()
        defer { fixture.cleanup() }
        let profile = ChildProfile(name: "Лиза", gender: .girl, birthday: Date(timeIntervalSince1970: 1_800_000_000))
        fixture.profileStore.replaceForRestore(with: profile)
        let log = WalkLog(id: UUID(), date: .now, algorithmVersion: 7,
                          durationMinutes: 25, comfortLevel: .comfortable)
        fixture.walkStore.replaceForRestore(with: [log])
        fixture.wardrobe.setOwnership(.unavailable, for: "jeans")
        fixture.personalization.record(
            .tooCold,
            for: profile.thermalProfile,
            context: PersonalizationContext(
                microclimateTemperature: 4,
                transportMode: .pushchairSeat,
                activityLevel: .calmAwake,
                walkType: .regular
            ),
            sourceID: log.id,
            source: .walkLog
        )
        let personalizationBefore = fixture.personalization.exportStates()

        let data = try fixture.backup.exportData()
        fixture.profileStore.replaceForRestore(with: nil)
        fixture.walkStore.replaceForRestore(with: [])
        fixture.wardrobe.clearAll()
        fixture.personalization.clearAll()
        let decoded = try fixture.backup.prepareRestore(from: data)
        try fixture.backup.restore(decoded, confirmed: true)

        XCTAssertEqual(fixture.profileStore.profile?.id, profile.id)
        XCTAssertEqual(fixture.walkStore.logs.first?.id, log.id)
        XCTAssertEqual(fixture.walkStore.logs.first?.algorithmVersion, 7)
        XCTAssertEqual(fixture.wardrobe.ownership(of: "jeans"), .unavailable)
        XCTAssertEqual(fixture.personalization.exportStates(), personalizationBefore)
    }

    func test_corruptTruncatedAndFutureFilesAreRejectedBeforeMutation() throws {
        let fixture = makeFixture()
        defer { fixture.cleanup() }
        let profile = ChildProfile(name: "Current", gender: .boy, birthday: .now)
        fixture.profileStore.replaceForRestore(with: profile)

        XCTAssertThrowsError(try fixture.backup.prepareRestore(from: Data("{\"schema".utf8)))
        let future = Data("{\"schemaVersion\":999}".utf8)
        XCTAssertThrowsError(try fixture.backup.prepareRestore(from: future)) {
            XCTAssertEqual($0 as? BackupValidationError, .unsupportedFutureVersion(999))
        }
        XCTAssertEqual(fixture.profileStore.profile?.id, profile.id)
    }

    func test_legacySchemaMigratesAndValidationFailureDoesNotMutate() throws {
        let fixture = makeFixture()
        defer { fixture.cleanup() }
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: fixture.backup.exportData()) as? [String: Any]
        )
        object["schemaVersion"] = 1
        object.removeValue(forKey: "settings")
        let migrated = try fixture.backup.prepareRestore(from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(migrated.schemaVersion, SkyKidBackup.currentSchemaVersion)

        let invalid = SkyKidBackup(
            exportedAt: .now,
            profile: nil,
            walks: [],
            personalization: [:],
            wardrobe: WardrobeBackup(confirmedOwnedIDs: ["jeans"], unavailableIDs: ["jeans"])
        )
        XCTAssertThrowsError(try fixture.backup.restore(invalid, confirmed: true))
    }

    func test_restoreRollbackKeepsPreviousDataWhenCommitFails() throws {
        let fixture = makeFixture(failBackupAt: .wardrobe)
        defer { fixture.cleanup() }
        let current = ChildProfile(name: "Current", gender: .girl, birthday: .now)
        fixture.profileStore.replaceForRestore(with: current)
        let incoming = SkyKidBackup(
            exportedAt: .now,
            profile: ChildProfile(name: "Incoming", gender: .boy, birthday: .now),
            walks: [], personalization: [:],
            wardrobe: WardrobeBackup(confirmedOwnedIDs: ["diaper"], unavailableIDs: [])
        )

        XCTAssertThrowsError(try fixture.backup.restore(incoming, confirmed: true))
        XCTAssertEqual(fixture.profileStore.profile?.id, current.id)
        XCTAssertEqual(fixture.profileStore.profile?.name, "Current")
    }

    private func makeFixture(failBackupAt: LocalBackupService.CommitStep? = nil) -> BackupFixture {
        BackupFixture(failBackupAt: failBackupAt)
    }
}

@MainActor
private final class BackupFixture {
    let suiteName = "BackupTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let profileStore: ChildProfileStore
    let personalization: PersonalOffsetStore
    let walkStore: WalkLogStore
    let wardrobe: UserWardrobeStore
    let backup: LocalBackupService

    init(failBackupAt: LocalBackupService.CommitStep?) {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        profileStore = ChildProfileStore(defaults: defaults)
        personalization = PersonalOffsetStore(defaults: defaults)
        walkStore = WalkLogStore(defaults: defaults, personalizationStore: personalization)
        wardrobe = UserWardrobeStore(defaults: defaults)
        backup = LocalBackupService(
            profileStore: profileStore,
            walkStore: walkStore,
            personalizationStore: personalization,
            wardrobeStore: wardrobe,
            appDefaults: defaults,
            standardDefaults: defaults,
            beforeCommit: { step in
                if step == failBackupAt { throw BackupFixtureError.forced }
            }
        )
    }

    func cleanup() { defaults.removePersistentDomain(forName: suiteName) }
}

private enum BackupFixtureError: Error { case forced }
