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
    static func evaluateEligibility(
        for log: WalkLog,
        now: Date
    ) -> PersonalizationEligibility {
        guard log.origin == .tracked else {
            return .excluded(.manualWalk)
        }

        guard log.isLiveTracked else {
            return .excluded(.notLiveTracked)
        }

        guard let snapshot = log.weatherSnapshot else {
            return .excluded(.missingWeatherSnapshot)
        }

        guard snapshot.schemaVersion == WeatherSnapshot.currentSchemaVersion,
              snapshot.temperature?.isFinite == true,
              snapshot.capturedAt.timeIntervalSinceReferenceDate.isFinite,
              snapshot.freshnessInput.staleAfter.isFinite,
              snapshot.freshnessInput.staleAfter > 0
        else {
            return .excluded(.invalidWeatherSnapshot)
        }

        guard snapshot.provider != .manual,
              let temperatureStatus = snapshot.status(for: .temperature),
              temperatureStatus.quality != .unavailable,
              temperatureStatus.origin != .safetyFallback
        else {
            return .excluded(.unknownWeatherProvenance)
        }

        guard snapshot.freshness(at: now) == .fresh else {
            return .excluded(.staleWeatherSnapshot)
        }

        guard let microclimateTemperature = log.microclimateTemperature,
              microclimateTemperature.isFinite,
              log.transportMode != nil,
              log.activityLevel != nil,
              log.walkType != nil
        else {
            return .excluded(.missingWalkContext)
        }

        return .eligible
    }

    static func offset(
        for state: PersonalizationProfileState,
        context: PersonalizationContext,
        now: Date
    ) -> Double {
        let baseline = state.legacyOffsetsByBand[context.temperatureBand.rawValue] ?? 0
        let netScore = independentDirectionalObservations(
            in: state,
            context: context,
            now: now
        ).reduce(into: 0) { score, observation in
            score += direction(for: observation)
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
        context: PersonalizationContext,
        now: Date
    ) -> PersonalizationSummary {
        let relevant = relevantObservations(
            in: state,
            context: context,
            now: now
        )
        let directional = independentDirectionalObservations(
            in: state,
            context: context,
            now: now
        )
        let netScore = directional.reduce(into: 0) { score, observation in
            score += direction(for: observation)
        }

        let appliedOffset = offset(for: state, context: context, now: now)
        let hasLegacyBaseline = state.legacyOffsetsByBand.values.contains { abs($0) > 0.000_1 }
        return PersonalizationSummary(
            temperatureBand: context.temperatureBand,
            scenario: context.scenario,
            appliedOffset: appliedOffset,
            independentDirectionalCount: directional.count,
            netDirectionalScore: netScore,
            comfortableConfirmationCount: relevant.filter { $0.feedback == .comfortable }.count,
            totalProfileObservationCount: state.observations.count,
            hasLegacyBaseline: hasLegacyBaseline,
            similarObservationCount: relevant.count,
            evidenceContext: PersonalizationEvidenceContext(context: context),
            explanation: explanation(
                similarCount: relevant.count,
                netScore: netScore,
                appliedOffset: appliedOffset,
                hasLegacyBaseline: hasLegacyBaseline
            )
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
        context: PersonalizationContext,
        now: Date
    ) -> [PersonalizationObservation] {
        let cutoff = now.addingTimeInterval(-PersonalizationPolicy.observationLifetime)
        let futureTolerance = now.addingTimeInterval(5 * 60)

        return state.observations.filter { observation in
            isSimilar(observation.context, to: context)
                && observation.recordedAt >= cutoff
                && observation.recordedAt <= futureTolerance
        }
    }

    private static func independentDirectionalObservations(
        in state: PersonalizationProfileState,
        context: PersonalizationContext,
        now: Date
    ) -> [PersonalizationObservation] {
        let directional = relevantObservations(
            in: state,
            context: context,
            now: now
        )
        .filter { direction(for: $0) != 0 }
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

    private static func isSimilar(
        _ observation: PersonalizationContext,
        to query: PersonalizationContext
    ) -> Bool {
        guard observation.temperatureBand == query.temperatureBand,
              observation.transportMode == query.transportMode,
              observation.activityLevel == query.activityLevel,
              observation.walkType == query.walkType else { return false }

        return optionalMatch(observation.childAgeBand, query.childAgeBand)
            && optionalMatch(observation.weatherClass, query.weatherClass)
            && optionalMatch(observation.insulationBand, query.insulationBand)
            && optionalMatch(observation.durationBand, query.durationBand)
    }

    private static func optionalMatch<T: Equatable>(_ left: T?, _ right: T?) -> Bool {
        guard let left, let right else { return true }
        return left == right
    }

    private static func explanation(
        similarCount: Int,
        netScore: Int,
        appliedOffset: Double,
        hasLegacyBaseline: Bool
    ) -> PersonalizationExplanation {
        guard similarCount >= PersonalizationPolicy.minimumConsistentSignals else {
            if similarCount == 0, hasLegacyBaseline { return .legacyBaseline }
            return .insufficientEvidence(similarWalkCount: similarCount)
        }
        if appliedOffset > 0 { return .prefersWarmer(evidenceCount: abs(netScore)) }
        if appliedOffset < 0 { return .prefersLighter(evidenceCount: abs(netScore)) }
        return .balanced(evidenceCount: similarCount)
    }

    private static func direction(for observation: PersonalizationObservation) -> Int {
        switch observation.feedback {
        case .tooCold:  return 1
        case .tooWarm:  return -1
        case .comfortable:
            switch observation.context.clothingAdjustment {
            case .addedLayer: return 1
            case .removedLayer: return -1
            case .some(.none), .some(.unknown), nil: return 0
            }
        }
    }

    private static func clamp(_ value: Double) -> Double {
        max(
            -OutfitConfig.TOG.maxPersonalOffsetTOG,
            min(OutfitConfig.TOG.maxPersonalOffsetTOG, value)
        )
    }
}
