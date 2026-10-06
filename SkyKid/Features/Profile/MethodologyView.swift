import SwiftUI

// MARK: - MethodologyView

struct MethodologyView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                introduction
                methodologySection(
                    title: L10n.text("Что учитывает SkyKid"),
                    icon: "list.bullet.clipboard",
                    text: L10n.text("Расчёт использует свежую погоду и её качество, возраст ребёнка, условия прогулки и отмеченный гардероб. Неизвестные данные не выдаются за измеренные.")
                )
                methodologySection(
                    title: L10n.text("Как получается рекомендация"),
                    icon: "function",
                    text: L10n.text("SkyKid оценивает влияние погоды и транспорта, затем подбирает совместимые слои одежды. TOG используется только внутри расчёта: итог показан как практичный список вещей, а не как медицинская точность.")
                )
                methodologySection(
                    title: L10n.text("Как работает персонализация"),
                    icon: "arrow.triangle.2.circlepath",
                    text: L10n.text("Учитываются только повторяющиеся оценки завершённых отслеживаемых прогулок с достоверным контекстом. Один отзыв не меняет расчёт, а все данные остаются на устройстве.")
                )
                methodologySection(
                    title: L10n.text("Актуальность и версия"),
                    icon: "clock.badge.checkmark",
                    text: L10n.format(
                        "Рекомендация привязана ко времени использованной погоды и через два часа требует обновления. Версия методики расчёта: %lld.",
                        RecommendationAlgorithmVersion.current
                    )
                )
                methodologySection(
                    title: L10n.text("Ограничения"),
                    icon: "exclamationmark.shield",
                    text: L10n.text("SkyKid — информационный помощник, а не медицинский прибор. Погода и микроклимат могут меняться: проверяйте живот или заднюю поверхность шеи ребёнка и при недомогании следуйте рекомендациям врача.")
                )
                methodologySection(
                    title: L10n.text("Источники и безопасность"),
                    icon: "checkmark.seal",
                    text: L10n.text("Фактический погодный источник и качество данных показаны в приложении. Правила безопасности отделены от расчёта одежды и не скрываются при неполных данных.")
                )
            }
            .padding(20)
        }
        .skyKidBackground()
        .navigationTitle(L10n.text("Как работает SkyKid"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("profile.methodology")
    }

    private var introduction: some View {
        Text(L10n.text("SkyKid помогает собрать ребёнка на прогулку и объясняет, какие данные повлияли на подсказку."))
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("methodology.introduction")
    }

    private func methodologySection(title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.indigo)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}
