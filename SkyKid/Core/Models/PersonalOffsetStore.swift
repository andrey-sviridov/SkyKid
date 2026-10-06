import Foundation
import Observation

// MARK: - PersonalOffsetStore

/// Persists contextual thermal feedback per child profile.
///
/// Version 2 stores observations instead of mutating a TOG value after every
/// tap. The old v1 offset is retained as a migration baseline so an existing
/// user's established setting is not silently lost.
@MainActor
@Observable
final class PersonalOffsetStore {
    static let shared = PersonalOffsetStore()

    private(set) var statesByProfile: [String: PersonalizationProfileState] = [:]

    private let defaults: UserDefaults
    private let nowProvider: () -> Date

    init(
        defaults: UserDefaults = AppGroup.defaults,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.nowProvider = nowProvider
        load()
        migrateVersionOneOffsets()
        migrateCurrentProfileLegacyIdentity()
    }

    // MARK: - Reading

    func currentOffset(
        for profile: ChildThermalProfile,
        tMicro: Double,
        walkContext: WalkContext
    ) -> Double {
        let context = PersonalizationContext(
            microclimateTemperature: tMicro,
            transportMode: walkContext.transportMode,
            activityLevel: walkContext.activityLevel,
            walkType: walkContext.walkType
        )
        return currentOffset(
            for: profile,
            context: context,
            profileID: resolvedProfileID(for: profile)
        )
    }

    func currentOffset(
        for profile: ChildThermalProfile,
        context: PersonalizationContext
    ) -> Double {
        currentOffset(
            for: profile,
            context: context,
            profileID: resolvedProfileID(for: profile)
        )
    }

    private func currentOffset(
        for profile: ChildThermalProfile,
        context: PersonalizationContext,
        profileID: UUID?
    ) -> Double {
        PersonalizationEngine.offset(
            for: state(for: profile, profileID: profileID),
            context: context.with(childAgeGroup: profile.ageGroup),
            now: nowProvider()
        )
    }

    func summary(
        for profile: ChildThermalProfile,
        context: PersonalizationContext
    ) -> PersonalizationSummary {
        summary(
            for: profile,
            context: context,
            profileID: resolvedProfileID(for: profile)
        )
    }

    private func summary(
        for profile: ChildThermalProfile,
        context: PersonalizationContext,
        profileID: UUID?
    ) -> PersonalizationSummary {
        PersonalizationEngine.summary(
            for: state(for: profile, profileID: profileID),
            context: context.with(childAgeGroup: profile.ageGroup),
            now: nowProvider()
        )
    }

    func feedbackHistory(
        for profile: ChildThermalProfile,
        limit: Int = 20
    ) -> [PersonalizationObservation] {
        PersonalizationEngine.history(
            in: state(for: profile, profileID: resolvedProfileID(for: profile)),
            now: nowProvider(),
            limit: limit
        )
    }

    // MARK: - Recording

    @discardableResult
    func record(
        _ feedback: UserFeedback,
        for profile: ChildThermalProfile,
        context: PersonalizationContext,
        sourceID: UUID = UUID(),
        source: PersonalizationFeedbackSource,
        recordedAt: Date? = nil
    ) -> PersonalizationUpdate {
        return record(
            feedback,
            for: profile,
            context: context,
            profileID: resolvedProfileID(for: profile),
            sourceID: sourceID,
            source: source,
            recordedAt: recordedAt
        )
    }

    private func record(
        _ feedback: UserFeedback,
        for profile: ChildThermalProfile,
        context: PersonalizationContext,
        profileID: UUID?,
        sourceID: UUID,
        source: PersonalizationFeedbackSource,
        recordedAt: Date?
    ) -> PersonalizationUpdate {
        let profileKey = key(for: profile, profileID: profileID)
        var profileState = state(for: profile, profileID: profileID)
        let resolvedContext = context.with(childAgeGroup: profile.ageGroup)
        let previousOffset = currentOffset(
            for: profile,
            context: resolvedContext,
            profileID: profileID
        )

        profileState.observations.removeAll { $0.sourceID == sourceID }
        profileState.observations.append(PersonalizationObservation(
            sourceID: sourceID,
            recordedAt: recordedAt ?? nowProvider(),
            feedback: feedback,
            source: source,
            context: resolvedContext
        ))
        profileState = PersonalizationEngine.trimmed(profileState, now: nowProvider())

        statesByProfile[profileKey] = profileState
        persist(profileKey: profileKey, state: profileState)

        let currentSummary = PersonalizationEngine.summary(
            for: profileState,
            context: resolvedContext,
            now: nowProvider()
        )
        return PersonalizationUpdate(
            previousOffset: previousOffset,
            currentOffset: currentSummary.appliedOffset,
            summary: currentSummary
        )
    }

    @discardableResult
    func removeObservation(sourceID: UUID) -> Bool {
        var changed = false

        for profileKey in Array(statesByProfile.keys) {
            guard var profileState = statesByProfile[profileKey] else { continue }
            let previousCount = profileState.observations.count
            profileState.observations.removeAll { $0.sourceID == sourceID }
            guard profileState.observations.count != previousCount else { continue }

            statesByProfile[profileKey] = profileState
            persist(profileKey: profileKey, state: profileState)
            changed = true
        }

        return changed
    }

    func clearOffset(for profile: ChildThermalProfile) {
        let profileKey = key(for: profile, profileID: resolvedProfileID(for: profile))
        statesByProfile.removeValue(forKey: profileKey)
        defaults.removeObject(forKey: defaultsKey(profileKey))
        defaults.removeObject(forKey: legacyDefaultsKey(profileKey))
        remove(profileKey, from: indexKey)
        remove(profileKey, from: legacyIndexKey)

        // Also clear a not-yet-migrated legacy key when this compatibility
        // API is called before the stored profile has been loaded.
        let legacyProfileKey = legacyKey(for: profile)
        statesByProfile.removeValue(forKey: legacyProfileKey)
        defaults.removeObject(forKey: defaultsKey(legacyProfileKey))
        defaults.removeObject(forKey: legacyDefaultsKey(legacyProfileKey))
        remove(legacyProfileKey, from: indexKey)
        remove(legacyProfileKey, from: legacyIndexKey)
    }

    func exportStates() -> [String: PersonalizationProfileState] {
        statesByProfile
    }

    func replaceForRestore(with states: [String: PersonalizationProfileState]) {
        clearAll()
        statesByProfile = states
        for (profileKey, state) in states {
            persist(profileKey: profileKey, state: state)
        }
    }

    func clearAll() {
        let profileKeys = Set(indexedKeys(for: indexKey) + indexedKeys(for: legacyIndexKey))
        for profileKey in profileKeys {
            defaults.removeObject(forKey: defaultsKey(profileKey))
            defaults.removeObject(forKey: legacyDefaultsKey(profileKey))
        }
        defaults.removeObject(forKey: indexKey)
        defaults.removeObject(forKey: legacyIndexKey)
        statesByProfile = [:]
    }

    // MARK: - Compatibility API

    func currentOffset(for profile: ChildThermalProfile, tMicro: Double) -> Double {
        currentOffset(for: profile, context: .compatibility(tMicro: tMicro))
    }

    @discardableResult
    func record(
        _ feedback: UserFeedback,
        for profile: ChildThermalProfile,
        tMicro: Double,
        sourceID: UUID = UUID(),
        recordedAt: Date? = nil
    ) -> PersonalizationUpdate {
        return record(
            feedback,
            for: profile,
            context: .compatibility(tMicro: tMicro),
            sourceID: sourceID,
            source: .compatibilityAPI,
            recordedAt: recordedAt
        )
    }

    // MARK: - Persistence

    private func state(
        for profile: ChildThermalProfile,
        profileID: UUID? = nil
    ) -> PersonalizationProfileState {
        statesByProfile[key(for: profile, profileID: profileID)] ?? PersonalizationProfileState()
    }

    private func state(for profileID: UUID) -> PersonalizationProfileState {
        statesByProfile[profileID.uuidString] ?? PersonalizationProfileState()
    }

    private func key(for profile: ChildThermalProfile, profileID: UUID?) -> String {
        profileID?.uuidString ?? legacyKey(for: profile)
    }

    private func legacyKey(for profile: ChildThermalProfile) -> String {
        let timestamp = Int(profile.birthday.timeIntervalSince1970)
        let safeName = profile.name.filter { $0.isLetter || $0.isNumber }
        return "\(safeName)_\(timestamp)"
    }

    private func resolvedProfileID(for profile: ChildThermalProfile) -> UUID? {
        guard let currentProfile = loadStoredProfile(),
              currentProfile.thermalProfile == profile else { return nil }
        return currentProfile.id
    }

    private func defaultsKey(_ profileKey: String) -> String {
        "tog_personalization_v2_\(profileKey)"
    }

    private func legacyDefaultsKey(_ profileKey: String) -> String {
        "tog_offset_v1_\(profileKey)"
    }

    private func load() {
        for profileKey in indexedKeys(for: indexKey) {
            guard let data = defaults.data(forKey: defaultsKey(profileKey)),
                  let state = try? JSONDecoder().decode(PersonalizationProfileState.self, from: data)
            else { continue }
            statesByProfile[profileKey] = state
        }
    }

    private func migrateCurrentProfileLegacyIdentity() {
        guard let profile = loadStoredProfile() else { return }
        migrateLegacyIdentity(from: profile, to: profile)
    }

    /// Loads the profile from this store's persistence and writes back the
    /// UUID generated while decoding a legacy payload. The write-back is
    /// essential: decoding the raw legacy data directly would generate a new
    /// UUID on every app launch and orphan the migrated personalization state.
    private func loadStoredProfile() -> ChildProfile? {
        guard let data = defaults.data(forKey: AppGroup.profileKey),
              let profile = try? JSONDecoder().decode(ChildProfile.self, from: data)
        else { return nil }

        guard let upgradedData = try? JSONEncoder().encode(profile) else {
            return profile
        }
        if upgradedData != data {
            defaults.set(upgradedData, forKey: AppGroup.profileKey)
        }
        return profile
    }

    /// Moves pre-UUID personalization data to the destination UUID. Source
    /// keys are removed after the destination is persisted, making the
    /// migration idempotent and preventing duplicate observations.
    func migrateLegacyIdentity(from legacyProfile: ChildProfile, to profile: ChildProfile) {
        let sourceKey = legacyKey(for: legacyProfile.thermalProfile)
        let destinationKey = profile.id.uuidString
        guard sourceKey != destinationKey else { return }

        let destinationState = statesByProfile[destinationKey]
        var migratedState = destinationState
        var hasLegacySource = false

        if let sourceState = statesByProfile[sourceKey] {
            hasLegacySource = true
            if migratedState == nil {
                migratedState = sourceState
            }
        }
        if let data = defaults.data(forKey: defaultsKey(sourceKey)) {
            hasLegacySource = true
            if migratedState == nil {
                migratedState = try? JSONDecoder().decode(PersonalizationProfileState.self, from: data)
            }
        }
        if let data = defaults.data(forKey: legacyDefaultsKey(sourceKey)) {
            hasLegacySource = true
            if migratedState == nil,
               let legacyOffsets = try? JSONDecoder().decode([String: Double].self, from: data) {
                migratedState = PersonalizationProfileState(
                    legacyOffsetsByBand: clampedLegacyOffsets(legacyOffsets),
                    observations: []
                )
            }
        }
        hasLegacySource = hasLegacySource
            || indexedKeys(for: indexKey).contains(sourceKey)
            || indexedKeys(for: legacyIndexKey).contains(sourceKey)
        guard hasLegacySource else { return }

        if destinationState == nil, let migratedState {
            statesByProfile[destinationKey] = migratedState
            guard persist(profileKey: destinationKey, state: migratedState) else { return }
        }

        statesByProfile.removeValue(forKey: sourceKey)
        defaults.removeObject(forKey: defaultsKey(sourceKey))
        defaults.removeObject(forKey: legacyDefaultsKey(sourceKey))
        remove(sourceKey, from: indexKey)
        remove(sourceKey, from: legacyIndexKey)
    }

    private func migrateVersionOneOffsets() {
        for profileKey in indexedKeys(for: legacyIndexKey) where statesByProfile[profileKey] == nil {
            guard let data = defaults.data(forKey: legacyDefaultsKey(profileKey)),
                  let legacyOffsets = try? JSONDecoder().decode([String: Double].self, from: data)
            else { continue }

            let clampedOffsets = clampedLegacyOffsets(legacyOffsets)
            let migrated = PersonalizationProfileState(
                legacyOffsetsByBand: clampedOffsets,
                observations: []
            )
            statesByProfile[profileKey] = migrated
            persist(profileKey: profileKey, state: migrated)
        }
    }

    private func clampedLegacyOffsets(_ offsets: [String: Double]) -> [String: Double] {
        offsets.mapValues { value in
            max(
                -OutfitConfig.TOG.maxPersonalOffsetTOG,
                min(OutfitConfig.TOG.maxPersonalOffsetTOG, value)
            )
        }
    }

    @discardableResult
    private func persist(profileKey: String, state: PersonalizationProfileState) -> Bool {
        guard let data = try? JSONEncoder().encode(state) else { return false }
        defaults.set(data, forKey: defaultsKey(profileKey))

        var keys = indexedKeys(for: indexKey)
        if !keys.contains(profileKey) {
            keys.append(profileKey)
            defaults.set(keys, forKey: indexKey)
        }
        return true
    }

    private func indexedKeys(for key: String) -> [String] {
        (defaults.array(forKey: key) as? [String]) ?? []
    }

    private func remove(_ profileKey: String, from indexKey: String) {
        let current = indexedKeys(for: indexKey)
        let updated = current.filter { $0 != profileKey }
        guard updated != current else { return }
        defaults.set(updated, forKey: indexKey)
    }

    private let indexKey = "tog_personalization_v2_index"
    private let legacyIndexKey = "tog_offset_v1_index"
}

// MARK: - ChildProfile compatibility

extension PersonalOffsetStore {
    func currentOffset(
        for profile: ChildProfile,
        tMicro: Double,
        walkContext: WalkContext
    ) -> Double {
        migrateLegacyIdentity(from: profile, to: profile)
        let context = PersonalizationContext(
            microclimateTemperature: tMicro,
            transportMode: walkContext.transportMode,
            activityLevel: walkContext.activityLevel,
            walkType: walkContext.walkType
        )
        return currentOffset(for: profile.thermalProfile, context: context, profileID: profile.id)
    }

    func currentOffset(for profile: ChildProfile, tMicro: Double) -> Double {
        migrateLegacyIdentity(from: profile, to: profile)
        return currentOffset(
            for: profile.thermalProfile,
            context: .compatibility(tMicro: tMicro),
            profileID: profile.id
        )
    }

    func currentOffset(
        for profile: ChildProfile,
        context: PersonalizationContext
    ) -> Double {
        migrateLegacyIdentity(from: profile, to: profile)
        return currentOffset(for: profile.thermalProfile, context: context, profileID: profile.id)
    }

    func summary(
        for profile: ChildProfile,
        context: PersonalizationContext
    ) -> PersonalizationSummary {
        migrateLegacyIdentity(from: profile, to: profile)
        return summary(for: profile.thermalProfile, context: context, profileID: profile.id)
    }

    func feedbackHistory(
        for profile: ChildProfile,
        limit: Int = 20
    ) -> [PersonalizationObservation] {
        migrateLegacyIdentity(from: profile, to: profile)
        return PersonalizationEngine.history(
            in: state(for: profile.id),
            now: nowProvider(),
            limit: limit
        )
    }

    @discardableResult
    func record(
        _ feedback: UserFeedback,
        for profile: ChildProfile,
        context: PersonalizationContext,
        sourceID: UUID = UUID(),
        source: PersonalizationFeedbackSource,
        recordedAt: Date? = nil
    ) -> PersonalizationUpdate {
        migrateLegacyIdentity(from: profile, to: profile)
        return record(
            feedback,
            for: profile.thermalProfile,
            context: context,
            profileID: profile.id,
            sourceID: sourceID,
            source: source,
            recordedAt: recordedAt
        )
    }

    func clearOffset(for profile: ChildProfile) {
        migrateLegacyIdentity(from: profile, to: profile)
        let profileKey = profile.id.uuidString
        statesByProfile.removeValue(forKey: profileKey)
        defaults.removeObject(forKey: defaultsKey(profileKey))
        defaults.removeObject(forKey: legacyDefaultsKey(profileKey))
        remove(profileKey, from: indexKey)
        let legacyProfileKey = legacyKey(for: profile.thermalProfile)
        statesByProfile.removeValue(forKey: legacyProfileKey)
        defaults.removeObject(forKey: defaultsKey(legacyProfileKey))
        defaults.removeObject(forKey: legacyDefaultsKey(legacyProfileKey))
        remove(legacyProfileKey, from: indexKey)
        remove(legacyProfileKey, from: legacyIndexKey)
    }
}
