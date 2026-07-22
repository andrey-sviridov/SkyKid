import Foundation
import Observation

// MARK: - WalkContextStore

/// In-memory state for the walk currently being planned.
/// No `UserDefaults` persistence is used by design.
@MainActor
@Observable
final class WalkContextStore {
    static let shared = WalkContextStore()

    private(set) var context: WalkContext?
    private var profileIdentity: String?

    private init() {}

    // MARK: - Lifecycle

    func prepare(
        for profile: ChildProfile?,
        availableGarmentIDs: Set<String>
    ) {
        guard let profile else {
            context = nil
            profileIdentity = nil
            return
        }

        let identity = Self.identity(for: profile.thermalProfile)
        guard identity != profileIdentity || context == nil else {
            context?.availableGarmentIDs = availableGarmentIDs
            return
        }

        profileIdentity = identity
        context = .standard(
            for: profile.thermalProfile,
            availableGarmentIDs: availableGarmentIDs
        )
    }

    func update(_ context: WalkContext) {
        self.context = context
    }

    func updateAvailableGarments(_ identifiers: Set<String>) {
        context?.availableGarmentIDs = identifiers
    }

    func reset(for profile: ChildProfile, availableGarmentIDs: Set<String>) {
        profileIdentity = Self.identity(for: profile.thermalProfile)
        context = .standard(
            for: profile.thermalProfile,
            availableGarmentIDs: availableGarmentIDs
        )
    }

    // MARK: - Identity

    private static func identity(for profile: ChildThermalProfile) -> String {
        "\(profile.name)_\(Int(profile.birthday.timeIntervalSince1970))"
    }
}
