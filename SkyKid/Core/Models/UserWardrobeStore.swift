import Foundation
import Observation

enum WardrobeOwnership: String, Codable, CaseIterable, Sendable {
    case unknown
    case owned
    case unavailable
}

struct WardrobeMigrationState: Equatable, Sendable {
    let confirmedOwnedIDs: Set<String>
    let unavailableIDs: Set<String>
}

@MainActor
@Observable
final class UserWardrobeStore {
    static let shared = UserWardrobeStore()

    static let key = "user_wardrobe"
    static let unavailableKey = "user_wardrobe_unavailable"
    static let seenKey = "user_wardrobe_seen"
    static let versionKey = "user_wardrobe_schema_version"
    static let currentSchemaVersion = 5

    private(set) var confirmedOwnedIDs: Set<String>
    private(set) var unavailableIDs: Set<String>

    /// Compatibility input for the existing recommendation pipeline. Unknown
    /// items remain candidates; only an explicit "don't have" removes one.
    var ownedIDs: Set<String> {
        allIDs.subtracting(unavailableIDs)
    }

    private let defaults: UserDefaults
    private let allIDs: Set<String>

    init(
        defaults: UserDefaults = AppGroup.defaults,
        catalogIDs: Set<String> = Set(GarmentCatalog.all.map(\.id))
    ) {
        self.defaults = defaults
        self.allIDs = catalogIDs
        let migrated = Self.migratedState(
            savedOwned: defaults.stringArray(forKey: Self.key).map(Set.init),
            savedUnavailable: defaults.stringArray(forKey: Self.unavailableKey).map(Set.init),
            seen: defaults.stringArray(forKey: Self.seenKey).map(Set.init),
            storedVersion: defaults.integer(forKey: Self.versionKey),
            allIDs: catalogIDs
        )
        confirmedOwnedIDs = migrated.confirmedOwnedIDs
        unavailableIDs = migrated.unavailableIDs
        persist()
    }

    static func migratedState(
        savedOwned: Set<String>?,
        savedUnavailable: Set<String>?,
        seen: Set<String>?,
        storedVersion: Int,
        allIDs: Set<String>
    ) -> WardrobeMigrationState {
        guard let savedOwned else {
            return WardrobeMigrationState(
                confirmedOwnedIDs: requiredIDs(in: allIDs),
                unavailableIDs: []
            )
        }

        let owned = canonicalized(savedOwned, allIDs: allIDs)
        let unavailable = canonicalized(savedUnavailable ?? [], allIDs: allIDs)

        if storedVersion < currentSchemaVersion {
            let legacySeen = canonicalized(seen ?? allIDs, allIDs: allIDs)
            let wasAutomaticallySeeded = owned == legacySeen && unavailable.isEmpty
            if wasAutomaticallySeeded {
                return WardrobeMigrationState(
                    confirmedOwnedIDs: requiredIDs(in: allIDs),
                    unavailableIDs: []
                )
            }

            return WardrobeMigrationState(
                confirmedOwnedIDs: owned.union(requiredIDs(in: allIDs)),
                unavailableIDs: legacySeen
                    .subtracting(owned)
                    .subtracting(requiredIDs(in: allIDs))
            )
        }

        return WardrobeMigrationState(
            confirmedOwnedIDs: owned.union(requiredIDs(in: allIDs)),
            unavailableIDs: unavailable
                .subtracting(owned)
                .subtracting(requiredIDs(in: allIDs))
        )
    }

    static func migratedOwnedIDs(
        saved: Set<String>?,
        seen: Set<String>?,
        storedVersion: Int,
        allIDs: Set<String>
    ) -> Set<String> {
        migratedState(
            savedOwned: saved,
            savedUnavailable: nil,
            seen: seen,
            storedVersion: storedVersion,
            allIDs: allIDs
        ).confirmedOwnedIDs
    }

    private static func canonicalized(
        _ identifiers: Set<String>,
        allIDs: Set<String>
    ) -> Set<String> {
        Set(identifiers.map { identifier in
            let canonical = GarmentCatalog.canonicalID(for: identifier)
            return allIDs.contains(canonical) ? canonical : identifier
        }).intersection(allIDs)
    }

    private static func requiredIDs(in allIDs: Set<String>) -> Set<String> {
        allIDs.contains("diaper") ? ["diaper"] : []
    }

    func ownership(of id: String) -> WardrobeOwnership {
        if confirmedOwnedIDs.contains(id) { return .owned }
        if unavailableIDs.contains(id) { return .unavailable }
        return .unknown
    }

    func isOwned(_ id: String) -> Bool {
        ownership(of: id) == .owned
    }

    func setOwnership(_ ownership: WardrobeOwnership, for id: String) {
        guard allIDs.contains(id), id != "diaper" else { return }
        confirmedOwnedIDs.remove(id)
        unavailableIDs.remove(id)
        switch ownership {
        case .unknown: break
        case .owned: confirmedOwnedIDs.insert(id)
        case .unavailable: unavailableIDs.insert(id)
        }
        persist()
    }

    func toggle(_ id: String) {
        setOwnership(isOwned(id) ? .unknown : .owned, for: id)
    }

    func backupState() -> WardrobeBackup {
        WardrobeBackup(
            confirmedOwnedIDs: confirmedOwnedIDs,
            unavailableIDs: unavailableIDs
        )
    }

    func replaceForRestore(with backup: WardrobeBackup) {
        confirmedOwnedIDs = backup.confirmedOwnedIDs.intersection(allIDs)
            .union(Self.requiredIDs(in: allIDs))
        unavailableIDs = backup.unavailableIDs.intersection(allIDs)
            .subtracting(confirmedOwnedIDs)
        persist()
    }

    func clearAll() {
        confirmedOwnedIDs = Self.requiredIDs(in: allIDs)
        unavailableIDs = []
        persist()
    }

    private func persist() {
        defaults.set(Array(confirmedOwnedIDs).sorted(), forKey: Self.key)
        defaults.set(Array(unavailableIDs).sorted(), forKey: Self.unavailableKey)
        defaults.set(Array(allIDs).sorted(), forKey: Self.seenKey)
        defaults.set(Self.currentSchemaVersion, forKey: Self.versionKey)
    }
}
