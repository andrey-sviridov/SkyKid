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
        let TOG_base: Double          // base curve value, retained for explanation
        let steps: [CalcStep]
    }

    static func calculate(_ input: Input) -> Output {
        var steps: [CalcStep] = []
        let T = input.T_micro
        let profile = input.profile

        // §4.1 Base curve
        let TOG_base = baseTOG(T)
        steps.append(CalcStep(
            label: L10n.text("Базовый TOG (§4.1)"),
            value: TOG_base,
            unit: "TOG",
            note: L10n.format("T_micro = %.1f°C", T)
        ))

        // §4.2 Age Adjustment
        let dAge = ageDelta(
            chronologicalWeeks: profile.chronologicalAgeWeeks,
            T_micro: T
        )
        if dAge != 0 {
            steps.append(CalcStep(
                label: L10n.text("Возрастная поправка (§4.2)"),
                value: dAge,
                unit: "TOG",
                note: L10n.format(
                    "Возраст %lld нед.",
                    profile.chronologicalAgeWeeks
                )
            ))
        }

        // §4.3 Activity
        let dActivity = activityDelta(
            activity: input.walkContext.activityLevel,
            walkType: input.walkContext.walkType
        )
        if dActivity != 0 {
            steps.append(CalcStep(
                label: L10n.text("Активность (§4.3)"),
                value: dActivity,
                unit: "TOG",
                note: input.walkContext.activityLevel.label
            ))
        }

        // Medical conditions and acute illness never change the thermal
        // arithmetic. Their limitations are evaluated independently by
        // MedicalSafetyPolicy and SafetyRulesEngine.
        var TOG_required = TOG_base + dAge + dActivity

        // §8 Personal Offset
        if input.personalOffset != 0 {
            TOG_required += input.personalOffset
            steps.append(CalcStep(
                label: L10n.text("Персональная поправка (§8)"),
                value: input.personalOffset,
                unit: "TOG",
                note: nil
            ))
        }

        // §4.5 Clamp
        TOG_required = min(max(TOG_required, OutfitConfig.TOG.minTOG), OutfitConfig.TOG.maxTOG)
        steps.append(CalcStep(
            label: L10n.text("Итоговый TOG_required (§4.5)"),
            value: TOG_required,
            unit: "TOG",
            note: nil
        ))

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

    private static func ageDelta(chronologicalWeeks: Int, T_micro: Double) -> Double {
        let table = OutfitConfig.TOG.ageAdjTable
        let coldThresh = OutfitConfig.TOG.ageAdjColdThreshold
        let hotThresh  = OutfitConfig.TOG.ageAdjHotThreshold

        var cold = 0.0
        var hot  = 0.0

        let clampedWeeks = max(0, chronologicalWeeks)

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

    // MARK: - §4.3 Activity

    private static func activityDelta(activity: BabyActivityLevel, walkType: WalkType) -> Double {
        var delta: Double
        switch activity {
        case .sleeping:         delta = OutfitConfig.TOG.actSleepingDelta
        case .calmAwake:        delta = OutfitConfig.TOG.actCalmDelta
        case .activeInStroller: delta = OutfitConfig.TOG.actActiveInStrollerDelta
        case .walkingCrawling:  delta = OutfitConfig.TOG.actWalkingCrawlingDelta
        }
        // Long exposure is a safety concern, not a standalone thermal input.
        // Keep its explicitly named rule separate from the legacy errands
        // constant; activity and transport determine the thermal target.
        if walkType == .long {
            delta += OutfitConfig.TOG.longWalkThermalDelta
        }
        return delta
    }

}
