import Foundation

// MARK: - TransportSafetyPolicy

/// Safety rules caused by stroller and car-seat configuration.
enum TransportSafetyPolicy {

    static func evaluate(_ context: SafetyAssessmentContext) -> [SafetyWarning] {
        rainCoverWarnings(context)
            + carSeatWarnings(context)
            + sleepingChildWarnings(context)
    }
}

// MARK: - Rain cover

private extension TransportSafetyPolicy {
    static func rainCoverWarnings(
        _ context: SafetyAssessmentContext
    ) -> [SafetyWarning] {
        guard context.gearSetup.rainCover == .present_on else { return [] }

        if context.microclimateTemperature >= OutfitConfig.Safety.rainCoverGreenhouseAbove {
            return [SafetyWarning(
                code: .rainCoverGreenhouse,
                severity: .danger,
                message: L10n.text("Под дождевиком может быстро накапливаться тепло. Снимите его вне дождя, уйдите в тень, восстановите вентиляцию и проверьте живот или заднюю поверхность шеи ребёнка."),
                systemImage: "exclamationmark.triangle.fill"
            )]
        }

        if context.microclimateTemperature >= OutfitConfig.Safety.rainCoverVentilationAbove {
            return [SafetyWarning(
                code: .rainCoverVentilation,
                severity: .caution,
                message: L10n.text("Используйте дождевик только во время осадков, не закрывайте вентиляционные секции и регулярно проверяйте ребёнка."),
                systemImage: "wind.snow"
            )]
        }

        return [SafetyWarning(
            code: .rainCoverVentilation,
            severity: .info,
            message: L10n.text("Дождевик уменьшает движение воздуха. Используйте его только во время осадков и не закрывайте штатную вентиляцию."),
            systemImage: "cloud.rain.fill"
        )]
    }
}

// MARK: - Car seat and sleeping child

private extension TransportSafetyPolicy {
    static func carSeatWarnings(
        _ context: SafetyAssessmentContext
    ) -> [SafetyWarning] {
        guard context.gearSetup.transportMode == .carSeat else {
            return []
        }

        return [SafetyWarning(
            code: .carSeatBulkyCoatWarning,
            severity: .caution,
            message: L10n.text("Не надевайте объёмную куртку или комбинезон под ремни автокресла. Используйте тонкие слои, затяните ремни по инструкции, а плед положите поверх пристёгнутых ремней."),
            systemImage: "car.fill"
        )]
    }

    static func sleepingChildWarnings(
        _ context: SafetyAssessmentContext
    ) -> [SafetyWarning] {
        guard context.walkContext.activityLevel == .sleeping,
              context.gearSetup.transportMode != .carrier,
              context.gearSetup.rainCover == .present_on,
              context.gearSetup.hoodUp else {
            return []
        }

        return [SafetyWarning(
            code: .faceVentilationRisk,
            severity: .danger,
            message: L10n.text("Перед выходом откройте лицо ребёнка и обеспечьте приток воздуха: дождевик и поднятый капюшон не должны создавать закрытый карман."),
            systemImage: "zzz"
        )]
    }
}
