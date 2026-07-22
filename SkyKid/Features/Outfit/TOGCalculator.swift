import Foundation

// MARK: - TOGCalculator §4

enum TOGCalculator {

    struct Input: Sendable {
        let T_micro: Double
        let profile: ChildThermalProfile
        let walkContext: WalkContext
        let personalOffset: Double    // from PersonalOffsetStore (§8)

        init(
            T_micro: Double,
            profile: ChildThermalProfile,
            walkContext: WalkContext,
            personalOffset: Double
        ) {
            self.T_micro = T_micro
            self.profile = profile
            self.walkContext = walkContext
            self.personalOffset = personalOffset
        }

        /// Compatibility initializer for tests and the isolated legacy path.
        init(T_micro: Double, profile: ChildProfile, personalOffset: Double) {
            self.init(
                T_micro: T_micro,
                profile: profile.thermalProfile,
                walkContext: .migrated(
                    from: profile,
                    gearSetup: .from(profile: profile),
                    availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
                ),
                personalOffset: personalOffset
            )
        }
    }

    struct Output: Sendable {
        let TOG_required: Double
        let TOG_base: Double          // pre-modifier base for fever cap
        let steps: [CalcStep]
    }

    static func calculate(_ input: Input) -> Output {
        var steps: [CalcStep] = []
        let T = input.T_micro
        let profile = input.profile

        // §4.1 Base curve
        let TOG_base = baseTOG(T)
        steps.append(CalcStep(label: "Базовый TOG (§4.1)",
                               value: TOG_base, unit: "TOG",
                               note: "T_micro = \(String(format:"%.1f", T))°C"))

        // §4.2 Age Adjustment
        let dAge = ageDelta(correctedWeeks: profile.correctedAgeWeeks, T_micro: T)
        if dAge != 0 {
            steps.append(CalcStep(label: "Возрастная поправка (§4.2)",
                                   value: dAge, unit: "TOG",
                                   note: "Скорр. возраст \(profile.correctedAgeWeeks) нед."))
        }

        // §4.3 Prematurity
        let dPreterm = pretermDelta(profile: profile)
        if dPreterm != 0 {
            steps.append(CalcStep(label: "Недоношенность (§4.3)",
                                   value: dPreterm, unit: "TOG", note: nil))
        }

        // §4.4 Activity
        let dActivity = activityDelta(
            activity: input.walkContext.activityLevel,
            walkType: input.walkContext.walkType
        )
        if dActivity != 0 {
            steps.append(CalcStep(label: "Активность (§4.4)",
                                   value: dActivity, unit: "TOG",
                                   note: input.walkContext.activityLevel.label))
        }

        // §4.5 Health
        let (dHealth, feverActive) = healthDelta(
            profile: profile,
            walkContext: input.walkContext
        )
        if dHealth != 0 {
            steps.append(CalcStep(label: "Здоровье (§4.5)",
                                   value: dHealth, unit: "TOG", note: nil))
        }

        var TOG_required = TOG_base + dAge + dPreterm + dActivity + dHealth

        // §8 Personal Offset
        if input.personalOffset != 0 {
            TOG_required += input.personalOffset
            steps.append(CalcStep(label: "Персональная поправка (§8)",
                                   value: input.personalOffset, unit: "TOG", note: nil))
        }

        // §4.5 Fever hard cap — safety rules always win over personalization.
        if feverActive {
            TOG_required = min(TOG_required, TOG_base)
            steps.append(CalcStep(label: "Ограничение при температуре (§4.5)",
                                   value: TOG_required, unit: "TOG",
                                   note: "Применено после персональной поправки"))
        }

        // §4.6 Clamp
        TOG_required = min(max(TOG_required, OutfitConfig.TOG.minTOG), OutfitConfig.TOG.maxTOG)
        steps.append(CalcStep(label: "Итоговый TOG_required (§4.6)",
                               value: TOG_required, unit: "TOG", note: nil))

        return Output(TOG_required: TOG_required, TOG_base: TOG_base, steps: steps)
    }

    // MARK: - §4.1 Base curve (piecewise linear interpolation)

    static func baseTOG(_ T: Double) -> Double {
        let anchors = OutfitConfig.TOG.baseCurveAnchors
        guard !anchors.isEmpty else { return 1.0 }

        if T >= anchors[0].temp { return anchors[0].tog }
        if T <= anchors[anchors.count - 1].temp { return anchors[anchors.count - 1].tog }

        for i in 0..<(anchors.count - 1) {
            let hi = anchors[i]
            let lo = anchors[i + 1]
            if T <= hi.temp && T >= lo.temp {
                let frac = (hi.temp - T) / (hi.temp - lo.temp)
                return hi.tog + frac * (lo.tog - hi.tog)
            }
        }
        return anchors[anchors.count - 1].tog
    }

    // MARK: - §4.2 Age Adjustment

    private static func ageDelta(correctedWeeks: Int, T_micro: Double) -> Double {
        let table = OutfitConfig.TOG.ageAdjTable
        let coldThresh = OutfitConfig.TOG.ageAdjColdThreshold
        let hotThresh  = OutfitConfig.TOG.ageAdjHotThreshold

        var cold = 0.0
        var hot  = 0.0

        // Negative correctedWeeks → treat as 0–4 weeks (youngest bucket)
        let clampedWeeks = max(0, correctedWeeks)

        var lo = 0
        for entry in table {
            if clampedWeeks >= lo && clampedWeeks <= entry.maxWeeks {
                cold = entry.cold
                hot  = entry.hot
                break
            }
            lo = entry.maxWeeks + 1
        }

        if T_micro < coldThresh { return cold }
        if T_micro >= hotThresh { return hot }
        // Linear interpolation between cold and hot in [18, 24] range
        let t = (T_micro - coldThresh) / (hotThresh - coldThresh)
        return cold + t * (hot - cold)
    }

    // MARK: - §4.3 Prematurity

    private static func pretermDelta(profile: ChildThermalProfile) -> Double {
        let corrWeeks   = profile.correctedAgeWeeks
        let gestWeeks   = profile.gestationalAgeWeeks
        let chronoMonths = profile.chronologicalAgeMonths

        let isPreterm = corrWeeks < 0
                     || (gestWeeks < OutfitConfig.TOG.pretermGestationThreshold
                         && chronoMonths < OutfitConfig.TOG.pretermChronoMonthsThreshold)
        return isPreterm ? OutfitConfig.TOG.pretermDelta : 0
    }

    // MARK: - §4.4 Activity

    private static func activityDelta(activity: BabyActivityLevel, walkType: WalkType) -> Double {
        var delta: Double
        switch activity {
        case .sleeping:         delta = OutfitConfig.TOG.actSleepingDelta
        case .calmAwake:        delta = OutfitConfig.TOG.actCalmDelta
        case .activeInStroller: delta = OutfitConfig.TOG.actActiveInStrollerDelta
        case .walkingCrawling:  delta = OutfitConfig.TOG.actWalkingCrawlingDelta
        }
        // WalkType errandsInOut adds an extra penalty and prefers layered outfit
        if walkType == .long { delta += OutfitConfig.TOG.errandsInOutDelta }  // reuse long penalty
        return delta
    }

    // MARK: - §4.5 Health

    private static func healthDelta(
        profile: ChildThermalProfile,
        walkContext: WalkContext
    ) -> (delta: Double, feverActive: Bool) {
        var delta = 0.0
        let feverActive = walkContext.hasFever

        if feverActive {
            delta += OutfitConfig.TOG.feverDelta
        }

        for trait in profile.stableTraits {
            switch trait {
            case .frequentIllness:
                delta += OutfitConfig.TOG.legacyFreqIllnessDelta
            case .coldSensitive:
                delta += OutfitConfig.TOG.legacyColdSensitiveDelta
            case .heatSensitive:
                delta += OutfitConfig.TOG.legacyHeatSensitiveDelta
            case .anemia:
                delta += OutfitConfig.TOG.anemiaOutDelta
            case .atopicDermatitis, .cardioRespiratory:
                break
            }
        }

        return (delta, feverActive)
    }
}
