import Foundation
import Observation

// MARK: - PersonalOffsetStore §8
//
// Stores per-profile TOG offset per temperature band (cold / mild / hot).
// Separate from BiasStore (which stores °C offsets for the old engine).
// Key prefix "tog_offset_v1_" prevents collision with BiasStore's "bias_v1_" keys.

@MainActor
@Observable
final class PersonalOffsetStore {

    static let shared = PersonalOffsetStore()

    // profileKey → [TempBand.rawValue: Double]
    private(set) var offsetsByProfile: [String: [String: Double]] = [:]

    init() { load() }

    // MARK: - Public API

    func currentOffset(for profile: ChildProfile, tMicro: Double) -> Double {
        let band = TempBand(tMicro: tMicro)
        return offsetsByProfile[key(for: profile)]?[band.rawValue] ?? 0.0
    }

    /// Update offset for the relevant band. §8 learning rule.
    func record(_ feedback: UserFeedback, for profile: ChildProfile, tMicro: Double) {
        let band = TempBand(tMicro: tMicro)
        let k = key(for: profile)
        var bandMap = offsetsByProfile[k] ?? [:]
        var current = bandMap[band.rawValue] ?? 0.0

        switch feedback {
        case .tooCold:     current += OutfitConfig.TOG.feedbackStepTOG
        case .tooWarm:     current -= OutfitConfig.TOG.feedbackStepTOG
        case .comfortable: current *= OutfitConfig.TOG.feedbackDecayFactor
        }

        current = max(-OutfitConfig.TOG.maxPersonalOffsetTOG,
                      min( OutfitConfig.TOG.maxPersonalOffsetTOG, current))

        bandMap[band.rawValue] = current
        offsetsByProfile[k] = bandMap
        persist(key: k, bandMap: bandMap)
    }

    func clearOffset(for profile: ChildProfile) {
        let k = key(for: profile)
        offsetsByProfile.removeValue(forKey: k)
        AppGroup.defaults.removeObject(forKey: defaultsKey(k))
    }

    // MARK: - Private

    private func key(for profile: ChildProfile) -> String {
        let ts = Int(profile.birthday.timeIntervalSince1970)
        let safe = profile.name.filter { $0.isLetter || $0.isNumber }
        return "\(safe)_\(ts)"
    }

    private func defaultsKey(_ k: String) -> String { "tog_offset_v1_\(k)" }

    private func load() {
        let d = AppGroup.defaults
        // Index key reuses a separate namespace from BiasStore
        let keys = (d.array(forKey: indexKey) as? [String]) ?? []
        for k in keys {
            guard let data = d.data(forKey: defaultsKey(k)),
                  let map  = try? JSONDecoder().decode([String: Double].self, from: data)
            else { continue }
            offsetsByProfile[k] = map
        }
    }

    private func persist(key k: String, bandMap: [String: Double]) {
        guard let data = try? JSONEncoder().encode(bandMap) else { return }
        let d = AppGroup.defaults
        d.set(data, forKey: defaultsKey(k))
        var index = (d.array(forKey: indexKey) as? [String]) ?? []
        if !index.contains(k) {
            index.append(k)
            d.set(index, forKey: indexKey)
        }
    }

    private let indexKey = "tog_offset_v1_index"
}
