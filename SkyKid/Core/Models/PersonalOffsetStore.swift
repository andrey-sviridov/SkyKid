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
        return currentOffset(for: profile, context: context)
    }

    func currentOffset(
        for profile: ChildThermalProfile,
        context: PersonalizationContext
    ) -> Double {
        PersonalizationEngine.offset(
            for: state(for: profile),
            band: context.temperatureBand,
            scenario: context.scenario,
            now: nowProvider()
        )
    }

    func summary(
        for profile: ChildThermalProfile,
        context: PersonalizationContext
    ) -> PersonalizationSummary {
        PersonalizationEngine.summary(
            for: state(for: profile),
            band: context.temperatureBand,
            scenario: context.scenario,
            now: nowProvider()
        )
    }

    func feedbackHistory(
        for profile: ChildThermalProfile,
        limit: Int = 20
    ) -> [PersonalizationObservation] {
        PersonalizationEngine.history(
            in: state(for: profile),
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
        let profileKey = key(for: profile)
        var profileState = state(for: profile)
        let previousOffset = currentOffset(for: profile, context: context)

        profileState.observations.removeAll { $0.sourceID == sourceID }
        profileState.observations.append(PersonalizationObservation(
            sourceID: sourceID,
            recordedAt: recordedAt ?? nowProvider(),
            feedback: feedback,
            source: source,
            context: context
        ))
        profileState = PersonalizationEngine.trimmed(profileState, now: nowProvider())

        statesByProfile[profileKey] = profileState
        persist(profileKey: profileKey, state: profileState)

        let currentSummary = PersonalizationEngine.summary(
            for: profileState,
            band: context.temperatureBand,
            scenario: context.scenario,
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
        let profileKey = key(for: profile)
        statesByProfile.removeValue(forKey: profileKey)
        defaults.removeObject(forKey: defaultsKey(profileKey))
        defaults.removeObject(forKey: legacyDefaultsKey(profileKey))
        remove(profileKey, from: indexKey)
        remove(profileKey, from: legacyIndexKey)
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
        record(
            feedback,
            for: profile,
            context: .compatibility(tMicro: tMicro),
            sourceID: sourceID,
            source: .compatibilityAPI,
            recordedAt: recordedAt
        )
    }

    // MARK: - Persistence

    private func state(for profile: ChildThermalProfile) -> PersonalizationProfileState {
        statesByProfile[key(for: profile)] ?? PersonalizationProfileState()
    }

    private func key(for profile: ChildThermalProfile) -> String {
        let timestamp = Int(profile.birthday.timeIntervalSince1970)
        let safeName = profile.name.filter { $0.isLetter || $0.isNumber }
        return "\(safeName)_\(timestamp)"
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

    private func migrateVersionOneOffsets() {
        for profileKey in indexedKeys(for: legacyIndexKey) where statesByProfile[profileKey] == nil {
            guard let data = defaults.data(forKey: legacyDefaultsKey(profileKey)),
                  let legacyOffsets = try? JSONDecoder().decode([String: Double].self, from: data)
            else { continue }

            let clampedOffsets = legacyOffsets.mapValues { value in
                max(
                    -OutfitConfig.TOG.maxPersonalOffsetTOG,
                    min(OutfitConfig.TOG.maxPersonalOffsetTOG, value)
                )
            }
            let migrated = PersonalizationProfileState(
                legacyOffsetsByBand: clampedOffsets,
                observations: []
            )
            statesByProfile[profileKey] = migrated
            persist(profileKey: profileKey, state: migrated)
        }
    }

    private func persist(profileKey: String, state: PersonalizationProfileState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: defaultsKey(profileKey))

        var keys = indexedKeys(for: indexKey)
        if !keys.contains(profileKey) {
            keys.append(profileKey)
            defaults.set(keys, forKey: indexKey)
        }
    }

    private func indexedKeys(for key: String) -> [String] {
        (defaults.array(forKey: key) as? [String]) ?? []
    }

    private func remove(_ profileKey: String, from indexKey: String) {
        let updated = indexedKeys(for: indexKey).filter { $0 != profileKey }
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
        currentOffset(
            for: profile.thermalProfile,
            tMicro: tMicro,
            walkContext: walkContext
        )
    }

    func currentOffset(for profile: ChildProfile, tMicro: Double) -> Double {
        currentOffset(for: profile.thermalProfile, tMicro: tMicro)
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
        record(
            feedback,
            for: profile.thermalProfile,
            context: context,
            sourceID: sourceID,
            source: source,
            recordedAt: recordedAt
        )
    }

    func clearOffset(for profile: ChildProfile) {
        clearOffset(for: profile.thermalProfile)
    }
}
