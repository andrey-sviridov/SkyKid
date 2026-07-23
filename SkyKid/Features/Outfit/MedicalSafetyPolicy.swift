import Foundation

// MARK: - MedicalSafetyAssessment

struct MedicalSafetyAssessment: Sendable {
    let warnings: [SafetyWarning]
    let exposureLimits: OutdoorSafetyLimits

    var blocksWalk: Bool {
        warnings.contains(where: \.blocksScenario)
    }
}

// MARK: - MedicalSafetyPolicy

/// Handles current illness and stable conditions that require extra caution.
/// The policy deliberately avoids calculating a medically "safe" walk time.
enum MedicalSafetyPolicy {

    static func evaluate(
        _ context: SafetyAssessmentContext,
        ageLimits: OutdoorSafetyLimits
    ) -> MedicalSafetyAssessment {
        var warnings: [SafetyWarning] = []
        let limits = adjustedExposureLimits(
            ageLimits,
            for: context.profile
        )

        if context.walkContext.hasFever {
            warnings.append(feverWarning(
                profile: context.profile,
                measuredTemperature: context.walkContext.bodyTemperatureCelsius
            ))
        } else if context.walkContext.healthStatus == .coldWithoutFever {
            warnings.append(contentsOf: coldWarnings(for: context))
        }

        if limits.usesAdditionalMedicalCaution {
            warnings.append(SafetyWarning(
                code: .medicalPlanPriority,
                severity: .info,
                message: L10n.text("Включён более осторожный режим для недоношенности или особенностей сердца/дыхания. Индивидуальный план врача важнее расчёта SkyKid."),
                systemImage: "cross.case.fill"
            ))
        }

        return MedicalSafetyAssessment(
            warnings: warnings,
            exposureLimits: limits
        )
    }
}

// MARK: - Exposure limits

private extension MedicalSafetyPolicy {
    static func adjustedExposureLimits(
        _ ageLimits: OutdoorSafetyLimits,
        for profile: ChildThermalProfile
    ) -> OutdoorSafetyLimits {
        let wasBornPreterm = profile.gestationalAgeWeeks < 37
        let hasCardioRespiratoryCondition = profile.stableTraits.contains(.cardioRespiratory)
        let withinEarlyCorrectedAge = profile.correctedAgeWeeks
            <= OutfitConfig.Safety.pretermCardioRespMaxCorrMonths * 4

        guard withinEarlyCorrectedAge,
              wasBornPreterm || hasCardioRespiratoryCondition else {
            return ageLimits
        }

        return OutdoorSafetyLimits(
            coldBelow: max(
                ageLimits.coldBelow,
                OutfitConfig.Safety.pretermCardioRespColdBelow
            ),
            hotAbove: min(
                ageLimits.hotAbove,
                OutfitConfig.Safety.pretermCardioRespHotAbove
            ),
            usesAdditionalMedicalCaution: true
        )
    }
}

// MARK: - Current illness

private extension MedicalSafetyPolicy {
    static func feverWarning(
        profile: ChildThermalProfile,
        measuredTemperature: Double?
    ) -> SafetyWarning {
        if profile.chronologicalAgeMonths < 3 {
            let measurementNote: String
            if let measuredTemperature {
                measurementNote = L10n.format(
                    "Измерено %.1f°C. ",
                    measuredTemperature
                )
            } else {
                measurementNote = L10n.text("Измерьте температуру термометром. ")
            }

            return SafetyWarning(
                code: .feverMedicalAttention,
                severity: .blocked,
                message: measurementNote
                    + L10n.text("Ребёнку меньше 3 месяцев: прогулку отмените. При 38°C и выше немедленно обратитесь за медицинской помощью."),
                systemImage: "cross.case.fill"
            )
        }

        return SafetyWarning(
            code: .feverStayHome,
            severity: .blocked,
            message: L10n.text("При повышенной температуре прогулку отмените. SkyKid не оценивает тяжесть болезни; ориентируйтесь на состояние ребёнка и рекомендации врача."),
            systemImage: "thermometer.high"
        )
    }

    static func coldWarnings(
        for context: SafetyAssessmentContext
    ) -> [SafetyWarning] {
        guard context.microclimateTemperature < 0 else { return [] }

        return [SafetyWarning(
            code: .illnessNeedsCaution,
            severity: .caution,
            message: L10n.text("ОРВИ без температуры и мороз: SkyKid не определяет, безопасна ли прогулка при болезни. Сократите или отложите выход; не закрывайте ребёнку рот и нос тканью."),
            systemImage: "lungs.fill"
        )]
    }
}
