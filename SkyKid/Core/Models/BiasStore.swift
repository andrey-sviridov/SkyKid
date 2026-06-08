import Foundation
import Observation

// MARK: - TempZone

/// Климатическая зона прогулки. Basis for per-zone bias — child may run cold in
/// freezing weather but be fine in mild. One global offset misses this nuance.
enum TempZone: String, Codable, CaseIterable {
    case freezing  // feelsLike < 0°C
    case cold      // 0 ≤ feelsLike < 10°C
    case mild      // 10 ≤ feelsLike < 20°C
    case warm      // feelsLike ≥ 20°C

    init(feelsLike: Double) {
        switch feelsLike {
        case ..<0:    self = .freezing
        case 0..<10:  self = .cold
        case 10..<20: self = .mild
        default:      self = .warm
        }
    }

    var label: String {
        switch self {
        case .freezing: return "Мороз (ниже 0°C)"
        case .cold:     return "Холодно (0–10°C)"
        case .mild:     return "Умеренно (10–20°C)"
        case .warm:     return "Тепло (выше 20°C)"
        }
    }
}

// MARK: - StoredFeedback

enum StoredFeedback: String, Codable {
    case tooCold
    case tooWarm

    init(_ feedback: UserFeedback) {
        self = feedback == .tooCold ? .tooCold : .tooWarm
    }
}

// MARK: - FeedbackEvent

struct FeedbackEvent: Identifiable, Codable {
    let id: UUID
    let date: Date
    let feedback: StoredFeedback
    /// Реальное ощущение температуры (apparentTemperature) в момент отзыва.
    let feelsLike: Double
    let zone: TempZone
}

// MARK: - ClothingBiasEngine (pure computation — no I/O, fully testable)

/// Time-weighted, per-zone bias calculator.
///
/// Formula:
///   vote_i  = −1 (tooCold) or +1 (tooWarm)
///   w_i     = exp(−λ · daysSince_i)          — recency decay
///   raw     = Σ(vote_i · w_i) / Σ(w_i)       — weighted mean ∈ [−1, 1]
///   confidence = min(1, Σ(w_i) / refCount)    — grows with feedback volume
///   bias    = raw · maxBias · confidence       — ∈ [−maxBias, +maxBias]
///
/// Properties:
///   - 1 fresh event → bias ≈ ±1°C (small nudge)
///   - 3+ consistent events → bias saturates at ±maxBias
///   - Decays naturally: after ~35 days, a single event contributes half weight
///   - Mixed feedback cancels out — no permanent drift from noise
enum ClothingBiasEngine {

    /// Decay rate. λ=0.02 → half-life ≈ 35 days.
    private static let lambda: Double = 0.02
    /// Events-equivalent needed to reach full confidence.
    private static let referenceCount: Double = 3.0
    /// Maximum bias magnitude (°C). Beyond this, adding more clothing won't help.
    static let maxBias: Double = 3.0
    /// Hard cap on stored events per profile (drop oldest on overflow).
    static let eventCap: Int = 60

    // MARK: Core

    /// Compute adaptive bias (°C) for the given temperature zone.
    ///
    /// - Returns: value ∈ [−maxBias, +maxBias].
    ///   Negative → child felt cold → lower effectiveTemp → more clothing recommended.
    ///   Positive → child felt warm → raise effectiveTemp → less clothing recommended.
    static func bias(events: [FeedbackEvent], zone: TempZone, now: Date = Date()) -> Double {
        let relevant = events.filter { $0.zone == zone }
        guard !relevant.isEmpty else { return 0 }

        var voteSum   = 0.0
        var weightSum = 0.0

        for e in relevant {
            let days = max(0, now.timeIntervalSince(e.date) / 86_400)
            let w    = exp(-lambda * days)
            voteSum   += (e.feedback == .tooCold ? -1.0 : 1.0) * w
            weightSum += w
        }

        let raw        = voteSum / weightSum                       // ∈ [−1, 1]
        let confidence = min(1.0, weightSum / referenceCount)
        let result     = raw * maxBias * confidence

        return max(-maxBias, min(maxBias, result))
    }

    /// Bias for every zone — for UI display (e.g. profile settings badge).
    static func allZones(events: [FeedbackEvent], now: Date = Date()) -> [TempZone: Double] {
        Dictionary(uniqueKeysWithValues: TempZone.allCases.map {
            ($0, bias(events: events, zone: $0, now: now))
        })
    }

    /// Total feedback count in a given zone (useful for "learning progress" UI).
    static func eventCount(events: [FeedbackEvent], zone: TempZone) -> Int {
        events.filter { $0.zone == zone }.count
    }

    /// Drop oldest events beyond the cap. Call before persisting.
    static func trimmed(_ events: [FeedbackEvent]) -> [FeedbackEvent] {
        guard events.count > eventCap else { return events }
        return Array(events.sorted { $0.date > $1.date }.prefix(eventCap))
    }
}

// MARK: - BiasStore

/// Persists per-profile feedback history in AppGroup UserDefaults and
/// exposes the current adaptive bias for use by `ClothingRecommendationEngine`.
///
/// Usage:
///   // Record feedback (from OutfitView or ClothingCalculatorView)
///   BiasStore.shared.record(.tooCold, for: profile, feelsLike: weather.apparentTemperature)
///
///   // Read bias when computing effectiveTemp
///   let bias = BiasStore.shared.currentBias(for: profile, feelsLike: weather.apparentTemperature)
@MainActor
@Observable
final class BiasStore {

    // MARK: Singleton

    static let shared = BiasStore()

    // MARK: Observable state

    /// Raw events keyed by profile storage key. Observed by views for live updates.
    private(set) var eventsByProfile: [String: [FeedbackEvent]] = [:]

    private init() { load() }

    // MARK: - Public API

    /// Current adaptive bias (°C) for a profile at a given feelsLike temperature.
    func currentBias(for profile: ChildProfile, feelsLike: Double) -> Double {
        ClothingBiasEngine.bias(
            events: eventsByProfile[key(for: profile)] ?? [],
            zone:   TempZone(feelsLike: feelsLike)
        )
    }

    /// All stored events for a profile (for debug / settings UI).
    func events(for profile: ChildProfile) -> [FeedbackEvent] {
        eventsByProfile[key(for: profile)] ?? []
    }

    /// Bias value for every temperature zone — use for a "learning card" in settings.
    func zoneSummary(for profile: ChildProfile) -> [TempZone: Double] {
        ClothingBiasEngine.allZones(events: events(for: profile))
    }

    /// Total feedback events recorded for a profile.
    func totalEventCount(for profile: ChildProfile) -> Int {
        events(for: profile).count
    }

    /// Record a feedback event and persist immediately.
    func record(_ feedback: UserFeedback, for profile: ChildProfile, feelsLike: Double) {
        let k = key(for: profile)
        var current = eventsByProfile[k] ?? []
        current.append(FeedbackEvent(
            id:       UUID(),
            date:     Date(),
            feedback: StoredFeedback(feedback),
            feelsLike: feelsLike,
            zone:     TempZone(feelsLike: feelsLike)
        ))
        eventsByProfile[k] = ClothingBiasEngine.trimmed(current)
        persist(key: k)
    }

    /// Reset all learned bias for a profile (e.g., child profile was recreated).
    func clearBias(for profile: ChildProfile) {
        let k = key(for: profile)
        eventsByProfile.removeValue(forKey: k)
        AppGroup.defaults.removeObject(forKey: defaultsKey(k))
        removeFromIndex(k)
    }

    // MARK: - Private: key helpers

    private func key(for profile: ChildProfile) -> String {
        let ts       = Int(profile.birthday.timeIntervalSince1970)
        let safeName = profile.name.filter { $0.isLetter || $0.isNumber }
        return "\(safeName)_\(ts)"
    }

    private func defaultsKey(_ k: String) -> String { "bias_v1_\(k)" }

    // MARK: - Private: persistence

    private static let indexKey = "bias_v1_index"

    private func load() {
        let d    = AppGroup.defaults
        let keys = (d.array(forKey: Self.indexKey) as? [String]) ?? []
        for k in keys {
            guard let data   = d.data(forKey: defaultsKey(k)),
                  let events = try? JSONDecoder().decode([FeedbackEvent].self, from: data)
            else { continue }
            eventsByProfile[k] = events
        }
    }

    private func persist(key k: String) {
        guard let events = eventsByProfile[k],
              let data   = try? JSONEncoder().encode(events) else { return }
        let d = AppGroup.defaults
        d.set(data, forKey: defaultsKey(k))
        addToIndex(k)
    }

    private func addToIndex(_ k: String) {
        let d = AppGroup.defaults
        var index = (d.array(forKey: Self.indexKey) as? [String]) ?? []
        guard !index.contains(k) else { return }
        index.append(k)
        d.set(index, forKey: Self.indexKey)
    }

    private func removeFromIndex(_ k: String) {
        let d = AppGroup.defaults
        var index = (d.array(forKey: Self.indexKey) as? [String]) ?? []
        index.removeAll { $0 == k }
        d.set(index, forKey: Self.indexKey)
    }
}
