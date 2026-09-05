import SwiftUI

// MARK: - OutfitBlockedScenarioView

struct OutfitBlockedScenarioView: View {
    let recommendation: OutfitRecommendation
    let warning: SafetyWarning
    let profile: ChildThermalProfile
    let onEditContext: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header

                if let window = recommendation.walkWindow,
                   warning.isWeatherExposureBlock {
                    saferWindowCard(window)
                }

                guidanceCard

                let remainingWarnings = recommendation.warnings.filter {
                    $0 != warning
                }
                if !remainingWarnings.isEmpty {
                    OutfitSafetyWarningsSection(warnings: remainingWarnings)
                }

                OutfitCheckHintCard(
                    hint: recommendation.checkHint,
                    title: L10n.text("Для следующей прогулки")
                )

                Button(action: onEditContext) {
                    Label("Изменить условия прогулки", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(presentation.tint)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Header

private extension OutfitBlockedScenarioView {
    var header: some View {
        VStack(spacing: 12) {
            Image(systemName: warning.systemImage)
                .font(.largeTitle.weight(.light))
                .foregroundStyle(presentation.tint)
                .symbolEffect(.pulse)

            if warning.isWeatherExposureBlock {
                Text("\(Int(recommendation.temperatures.apparent.rounded()))°")
                    .font(.largeTitle.monospacedDigit().weight(.light))
                    .contentTransition(.numericText())
            }

            Text(presentation.title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(OutfitParentSummaryBuilder.ageContext(for: profile))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(warning.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    var guidanceCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .font(.subheadline)
                .foregroundStyle(presentation.tint)

            Text(presentation.guidance)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(presentation.tint.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Safer window

private extension OutfitBlockedScenarioView {
    func saferWindowCard(_ window: DateInterval) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "clock.badge.checkmark")
                .foregroundStyle(.green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text("Ближайшее более подходящее окно")
                    .font(.caption.weight(.semibold))
                Text(windowLabel(window))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    func windowLabel(_ window: DateInterval) -> String {
        let format = Date.FormatStyle.dateTime
            .weekday(.wide)
            .hour(.twoDigits(amPM: .omitted))
            .minute(.twoDigits)
            .locale(L10n.locale)
        let start = window.start.formatted(format)
        let end = window.end.formatted(
            Date.FormatStyle.dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(L10n.locale)
        )
        return "\(start)–\(end)"
    }
}

// MARK: - Presentation

private extension OutfitBlockedScenarioView {
    struct Presentation {
        let title: String
        let guidance: String
        let tint: Color
    }

    var presentation: Presentation {
        switch warning.code {
        case .feverMedicalAttention:
            return Presentation(
                title: L10n.text("Сначала проверьте самочувствие"),
                guidance: L10n.text(
                    "Я не подбираю одежду для прогулки при повышенной температуре. Если состояние ребёнка вызывает тревогу, обратитесь за медицинской помощью."
                ),
                tint: .red
            )
        case .feverStayHome:
            return Presentation(
                title: L10n.text("Сначала проверьте самочувствие"),
                guidance: L10n.text(
                    "Вернитесь к подбору одежды после нормализации температуры. При сомнениях ориентируйтесь на рекомендации врача."
                ),
                tint: .red
            )
        case .heatExposureLimit:
            return Presentation(
                title: L10n.text("Выберите другое время"),
                guidance: L10n.text(
                    "Выберите более прохладное время и тень. Не накрывайте коляску пледом или плотной тканью; используйте штатную вентиляцию."
                ),
                tint: .red
            )
        default:
            return Presentation(
                title: L10n.text("Нужен другой план"),
                guidance: L10n.text(
                    "Сейчас условия выходят за ориентир помощника. Выберите короткий маршрут через помещение или перенесите выход."
                ),
                tint: .blue
            )
        }
    }
}
