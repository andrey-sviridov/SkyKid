import Foundation

// MARK: - Personalization policy

enum PersonalizationPolicy {
    static let minimumConsistentSignals = 2
    static let independentSignalInterval: TimeInterval = 4 * 60 * 60
    static let observationLifetime: TimeInterval = 120 * 24 * 60 * 60
    static let maximumStoredObservations = 80
}

// MARK: - Personalization engine

enum PersonalizationEngine {
    static func offset(
        for state: PersonalizationProfileState,
        band: TempBand,
        scenario: PersonalizationScenario,
        now: Date
    ) -> Double {
        let baseline = state.legacyOffsetsByBand[band.rawValue] ?? 0
        let netScore = independentDirectionalObservations(
            in: state,
            band: band,
            scenario: scenario,
            now: now
        ).reduce(into: 0) { score, observation in
            score += direction(for: observation.feedback)
        }

        let evidenceBeyondFirst = max(
            0,
            abs(netScore) - (PersonalizationPolicy.minimumConsistentSignals - 1)
        )
        let learnedDelta = Double(evidenceBeyondFirst)
            * OutfitConfig.TOG.feedbackStepTOG
            * Double(netScore.signum())

        return clamp(baseline + learnedDelta)
    }

    static func summary(
        for state: PersonalizationProfileState,
        band: TempBand,
        scenario: PersonalizationScenario,
        now: Date
    ) -> PersonalizationSummary {
        let relevant = relevantObservations(
            in: state,
            band: band,
            scenario: scenario,
            now: now
        )
        let directional = independentDirectionalObservations(
            in: state,
            band: band,
            scenario: scenario,
            now: now
        )
        let netScore = directional.reduce(into: 0) { score, observation in
            score += direction(for: observation.feedback)
        }

        return PersonalizationSummary(
            temperatureBand: band,
            scenario: scenario,
            appliedOffset: offset(for: state, band: band, scenario: scenario, now: now),
            independentDirectionalCount: directional.count,
            netDirectionalScore: netScore,
            comfortableConfirmationCount: relevant.filter { $0.feedback == .comfortable }.count,
            totalProfileObservationCount: state.observations.count,
            hasLegacyBaseline: state.legacyOffsetsByBand.values.contains { abs($0) > 0.000_1 }
        )
    }

    static func trimmed(
        _ state: PersonalizationProfileState,
        now: Date
    ) -> PersonalizationProfileState {
        var result = state
        result.observations = history(
            in: state,
            now: now,
            limit: PersonalizationPolicy.maximumStoredObservations
        )
        return result
    }

    static func history(
        in state: PersonalizationProfileState,
        now: Date,
        limit: Int
    ) -> [PersonalizationObservation] {
        guard limit > 0 else { return [] }
        let cutoff = now.addingTimeInterval(-PersonalizationPolicy.observationLifetime)
        let futureTolerance = now.addingTimeInterval(5 * 60)

        return state.observations
            .filter { $0.recordedAt >= cutoff && $0.recordedAt <= futureTolerance }
            .sorted { $0.recordedAt > $1.recordedAt }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Evidence selection

    private static func relevantObservations(
        in state: PersonalizationProfileState,
        band: TempBand,
        scenario: PersonalizationScenario,
        now: Date
    ) -> [PersonalizationObservation] {
        let cutoff = now.addingTimeInterval(-PersonalizationPolicy.observationLifetime)
        let futureTolerance = now.addingTimeInterval(5 * 60)

        return state.observations.filter { observation in
            observation.context.temperatureBand == band
                && observation.context.scenario == scenario
                && observation.recordedAt >= cutoff
                && observation.recordedAt <= futureTolerance
        }
    }

    private static func independentDirectionalObservations(
        in state: PersonalizationProfileState,
        band: TempBand,
        scenario: PersonalizationScenario,
        now: Date
    ) -> [PersonalizationObservation] {
        let directional = relevantObservations(
            in: state,
            band: band,
            scenario: scenario,
            now: now
        )
        .filter { $0.feedback != .comfortable }
        .sorted { $0.recordedAt < $1.recordedAt }

        return directional.reduce(into: []) { independent, observation in
            guard let previous = independent.last else {
                independent.append(observation)
                return
            }

            if observation.recordedAt.timeIntervalSince(previous.recordedAt)
                < PersonalizationPolicy.independentSignalInterval {
                independent[independent.count - 1] = observation
            } else {
                independent.append(observation)
            }
        }
    }

    private static func direction(for feedback: UserFeedback) -> Int {
        switch feedback {
        case .tooCold:  return 1
        case .tooWarm:  return -1
        case .comfortable: return 0
        }
    }

    private static func clamp(_ value: Double) -> Double {
        max(
            -OutfitConfig.TOG.maxPersonalOffsetTOG,
            min(OutfitConfig.TOG.maxPersonalOffsetTOG, value)
        )
    }
}
