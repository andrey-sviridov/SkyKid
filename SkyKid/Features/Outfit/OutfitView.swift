import SwiftUI

// MARK: - OutfitView

struct OutfitView: View {
    let weather: NormalizedWeather
    var profile: ChildProfile?
    let recommendation: OutfitRecommendation?
    let walkContext: WalkContext?
    let onWalkContextChange: (WalkContext) -> Void
    let onFeedbackRecorded: () -> Void

    @Environment(NotificationService.self) private var notificationService
    @State private var viewModel: OutfitViewModel
    @State private var showWalkPreparation = false

    init(
        weather: NormalizedWeather,
        profile: ChildProfile? = nil,
        recommendation: OutfitRecommendation? = nil,
        walkContext: WalkContext? = nil,
        personalOffsetStore: PersonalOffsetStore = .shared,
        onWalkContextChange: @escaping (WalkContext) -> Void = { _ in },
        onFeedbackRecorded: @escaping () -> Void = {}
    ) {
        self.weather = weather
        self.profile = profile
        self.recommendation = recommendation
        self.walkContext = walkContext
        self.onWalkContextChange = onWalkContextChange
        self.onFeedbackRecorded = onFeedbackRecorded
        _viewModel = State(initialValue: OutfitViewModel(
            profile: profile,
            recommendation: recommendation,
            walkContext: walkContext,
            personalizationStore: personalOffsetStore
        ))
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            if let profile,
               let rec = viewModel.recommendation,
               let blockingWarning = viewModel.blockingWarning {
                OutfitBlockedScenarioView(
                    recommendation: rec,
                    warning: blockingWarning,
                    profile: profile.thermalProfile
                ) {
                    showWalkPreparation = true
                }
            } else if let profile, let rec = viewModel.recommendation {
                ScrollView(.vertical) {
                    VStack(spacing: 14) {
                        if let walkContext {
                            ParentOutfitSummaryCard(summary: OutfitParentSummaryBuilder.make(
                                recommendation: rec,
                                weather: weather,
                                profile: profile.thermalProfile,
                                walkContext: walkContext
                            ))
                            WalkContextSummaryCard(context: walkContext) {
                                showWalkPreparation = true
                            }
                        }
                        let safetyWarnings = visibleSafetyWarnings(in: rec)
                        if !safetyWarnings.isEmpty {
                            OutfitSafetyWarningsSection(warnings: safetyWarnings)
                        }
                        if let window = rec.walkWindow {
                            walkWindowCard(window)
                        }
                        layersSection(layers: viewModel.displayLayers)
                        if let guidance = wardrobeGuidance(in: rec) {
                            WardrobeAlternativesCard(
                                alternatives: rec.suggestedAlternatives,
                                fit: rec.fit,
                                severity: guidance.severity
                            )
                        }
                        OutfitFeedbackSection(
                            feedback: viewModel.feedbackSent,
                            confirmationMessage: viewModel.feedbackMessage
                        ) { feedback in
                            if viewModel.recordFeedback(feedback) {
                                onFeedbackRecorded()
                            }
                        }
                    }
                    .containerRelativeFrame(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            } else {
                unavailableContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .skyKidBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task(id: recommendation) {
            // P2-3: уведомления синхронизируются раз на обновление погоды,
            // не в computed property (он вызывается каждый рендер)
            guard let walkContext, let rec = viewModel.recommendation else { return }
            await notificationService.sync(
                recommendation: rec,
                gearSetup: walkContext.gearSetup
            )
        }
        .onChange(of: recommendation) { _, newValue in
            viewModel.update(
                profile: profile,
                recommendation: newValue,
                walkContext: walkContext
            )
        }
        .onChange(of: profile) { _, newValue in
            viewModel.update(
                profile: newValue,
                recommendation: recommendation,
                walkContext: walkContext
            )
        }
        .onChange(of: walkContext) { _, newValue in
            viewModel.update(
                profile: profile,
                recommendation: recommendation,
                walkContext: newValue
            )
        }
        .sheet(isPresented: $showWalkPreparation) {
            if let profile, let walkContext {
                WalkPreparationView(
                    profile: profile.thermalProfile,
                    context: walkContext,
                    onSave: onWalkContextChange
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 7) {
                    Image(systemName: "wand.and.stars")
                        .font(.subheadline.weight(.semibold))
                    Text(
                        profile.map {
                            L10n.format("Помощник · %@", $0.name)
                        } ?? L10n.text("Помощник")
                    )
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(.primary)
            }
        }
    }

    @ViewBuilder
    private var unavailableContent: some View {
        if profile == nil {
            ContentUnavailableView(
                "Создайте профиль ребёнка",
                systemImage: "person.badge.plus",
                description: Text("Профиль поможет рассчитать одежду точнее")
            )
        } else {
            ContentUnavailableView(
                "Обновляем рекомендацию",
                systemImage: "arrow.clockwise",
                description: Text("Дождитесь свежего расчёта по текущей погоде")
            )
        }
    }

    // MARK: - Walk window card (P1-3)

    private func walkWindowCard(_ window: DateInterval) -> some View {
        let fmt = Date.FormatStyle.dateTime
            .hour(.twoDigits(amPM: .omitted))
            .minute()
            .locale(L10n.locale)
        let isTomorrow = !Calendar.current.isDateInToday(window.start)
        let start = window.start.formatted(fmt)
        let end = window.end.formatted(fmt)
        let label = isTomorrow
            ? L10n.format(
                "Более подходящее время для прогулки: завтра %@–%@",
                start,
                end
            )
            : L10n.format(
                "Более подходящее время для прогулки: %@–%@",
                start,
                end
            )
        return HStack(spacing: 12) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 24)
            Text(label)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.green.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Layers section

    @ViewBuilder
    private func layersSection(layers: [RecommendedLayer]) -> some View {
        if layers.isEmpty {
            Text("Лёгкое и удобное — больше ничего не нужно")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Label(L10n.text("Комплект"), systemImage: "hanger")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(layers.count) \(itemsWord(layers.count))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(Array(layers.enumerated()), id: \.element.id) { idx, layer in
                        layerRow(layer: layer, index: idx, isLast: idx == layers.count - 1)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal:   .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: layers.map(\.name))
            }
        }
    }


    private func layerRow(layer: RecommendedLayer, index: Int, isLast: Bool) -> some View {
        let isFirst = index == 0
        let radius: (CGFloat, CGFloat) = (isFirst ? 18 : 6, isLast ? 18 : 6)

        return HStack(spacing: 14) {
            if let item = GarmentCatalog.byID[layer.id] {
                GarmentIconView(
                    item: item,
                    isSelected: true,
                    accentColor: rowAccent(index),
                    size: 44,
                    shape: .roundedRectangle(11)
                )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(rowAccent(index).opacity(0.22))
                        .frame(width: 44, height: 44)
                    Image(systemName: layer.systemImage)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(rowAccent(index))
                        .symbolRenderingMode(.hierarchical)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(layer.name)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text(layer.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "checkmark")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.regularMaterial)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius:     radius.0,
                bottomLeadingRadius:  radius.1,
                bottomTrailingRadius: radius.1,
                topTrailingRadius:    radius.0
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius:     radius.0,
                bottomLeadingRadius:  radius.1,
                bottomTrailingRadius: radius.1,
                topTrailingRadius:    radius.0
            )
            .strokeBorder(.primary.opacity(0.10), lineWidth: 1)
        )
        .padding(.vertical, 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(layer.name). \(layer.reason). Добавлено в комплект")
    }

    // MARK: - Guidance filtering

    private func visibleSafetyWarnings(
        in recommendation: OutfitRecommendation
    ) -> [SafetyWarning] {
        recommendation.warnings.filter { warning in
            warning.code != .wardrobeGap && warning.code != .outfitFitUncertain
        }
    }

    private func wardrobeGuidance(
        in recommendation: OutfitRecommendation
    ) -> SafetyWarning? {
        recommendation.warnings.first { warning in
            warning.code == .wardrobeGap || warning.code == .outfitFitUncertain
        }
    }

    // MARK: - Helpers

    private func rowAccent(_ index: Int) -> Color {
        let palette: [Color] = [.blue, .teal, .green, .orange, .purple, .pink, .indigo, .cyan]
        return palette[index % palette.count]
    }

    private func itemsWord(_ n: Int) -> String {
        let mod10 = n % 10, mod100 = n % 100
        if mod100 >= 11 && mod100 <= 19 { return L10n.text("вещей") }
        switch mod10 {
        case 1: return L10n.text("вещь")
        case 2, 3, 4: return L10n.text("вещи")
        default: return L10n.text("вещей")
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("🧥 Весна · 2 года") {
    let weather = NormalizedWeather.mock
    let profile = ChildProfile.mock
    let context = WalkContext.standard(
        for: profile.thermalProfile,
        availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
    )
    let recommendation = OutfitRecommendationService.shared.recommend(
        weather: weather,
        profile: profile.thermalProfile,
        walkContext: context
    )
    NavigationStack {
        OutfitView(
            weather: weather,
            profile: profile,
            recommendation: recommendation,
            walkContext: context
        )
    }
    .environment(NotificationService.shared)
}

#Preview("❄️ Зима · 4 мес") {
    let weather = NormalizedWeather.mockWinter
    let profile = ChildProfile.mockInfant
    let context = WalkContext.standard(
        for: profile.thermalProfile,
        availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
    )
    let recommendation = OutfitRecommendationService.shared.recommend(
        weather: weather,
        profile: profile.thermalProfile,
        walkContext: context
    )
    NavigationStack {
        OutfitView(
            weather: weather,
            profile: profile,
            recommendation: recommendation,
            walkContext: context
        )
    }
    .environment(NotificationService.shared)
}

#Preview("Нет профиля") {
    NavigationStack {
        OutfitView(weather: .mock)
    }
    .environment(NotificationService.shared)
}
#endif
