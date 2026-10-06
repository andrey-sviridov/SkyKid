import SwiftUI

// MARK: - TodayView

struct TodayView: View {
    let weatherViewModel: WeatherViewModel
    let profile: ChildProfile?
    let walkContext: WalkContext?
    let personalOffsetStore: PersonalOffsetStore
    let onWalkContextChange: (WalkContext) -> Void
    let onRefresh: () -> Void
    let onStartWalk: () -> Void

    @Environment(ActiveWalkStore.self) private var activeWalkStore
    @Environment(NotificationService.self) private var notificationService
    @State private var viewModel = TodayViewModel()
    @State private var showWalkPreparation = false

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView(L10n.text("Загружаем погоду…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .unavailable(message):
                unavailableContent(message: message, stale: false)
            case .stale:
                unavailableContent(message: L10n.text("Обновите погоду перед прогулкой"), stale: true)
            case let .blocked(warning):
                blockedContent(warning: warning)
            case .ready:
                readyContent
            }
        }
        .skyKidBackground()
        .navigationTitle(L10n.text("Сегодня"))
        .toolbar { refreshToolbarItem }
        .task(id: stateInput) { updateState() }
        .task(id: weatherViewModel.outfitRecommendation) {
            guard let recommendation = weatherViewModel.outfitRecommendation,
                  let walkContext else { return }
            await notificationService.sync(
                recommendation: recommendation,
                gearSetup: walkContext.gearSetup
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
    }

    private var readyContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let weather = weatherViewModel.weather {
                    TodayWeatherSummaryCard(
                        weather: weather,
                        cityName: weatherViewModel.cityName,
                        updatedAt: weatherViewModel.weatherUpdatedAt
                    )
                }
                if let summary {
                    TodayOutfitCard(
                        summary: summary,
                        warning: weatherViewModel.outfitRecommendation?.primarySafetyWarning,
                        onEditContext: { showWalkPreparation = true }
                    )
                }
                if let items = weatherViewModel.outfitRecommendation?.suggestedAlternatives,
                   !items.isEmpty {
                    TodayTakeAlongCard(items: Array(items.prefix(2)))
                }
                if let interval = weatherViewModel.outfitRecommendation?.walkWindow {
                    TodayWalkWindowCard(interval: interval)
                }
                walkContent
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .accessibilityIdentifier("today.scroll")
    }

    @ViewBuilder
    private var walkContent: some View {
        TodayWalkStateCard(
            isActive: activeWalkStore.isActive,
            startedAt: activeWalkStore.current?.startDate,
            onStart: onStartWalk
        )
    }

    private func blockedContent(warning: SafetyWarning) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                if let weather = weatherViewModel.weather {
                    TodayWeatherSummaryCard(
                        weather: weather,
                        cityName: weatherViewModel.cityName,
                        updatedAt: weatherViewModel.weatherUpdatedAt
                    )
                }
                ContentUnavailableView(
                    "Рекомендация недоступна",
                    systemImage: warning.systemImage,
                    description: Text(warning.message)
                )
                .accessibilityIdentifier("today.blocked")
                walkContent
            }
            .padding(16)
        }
    }

    private func unavailableContent(message: String, stale: Bool) -> some View {
        ContentUnavailableView {
            Label(
                stale ? L10n.text("Погода устарела") : L10n.text("Погода недоступна"),
                systemImage: stale ? "clock.badge.exclamationmark" : "wifi.exclamationmark"
            )
        } description: {
            Text(message)
        } actions: {
            Button(L10n.text("Обновить погоду"), action: onRefresh)
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
        }
        .accessibilityIdentifier(stale ? "today.stale" : "today.error")
    }

    private var summary: OutfitParentSummary? {
        guard let recommendation = weatherViewModel.outfitRecommendation,
              let weather = weatherViewModel.weather,
              let profile,
              let walkContext else { return nil }
        return OutfitParentSummaryBuilder.make(
            recommendation: recommendation,
            weather: weather,
            profile: profile.thermalProfile,
            walkContext: walkContext
        )
    }

    private var stateInput: String {
        [
            String(weatherViewModel.isLoading),
            weatherViewModel.error ?? "",
            String(describing: weatherViewModel.weatherUpdatedAt),
            String(describing: weatherViewModel.outfitRecommendation)
        ].joined(separator: "|")
    }

    private func updateState() {
        viewModel.update(
            isLoading: weatherViewModel.isLoading,
            error: weatherViewModel.error,
            weather: weatherViewModel.weather,
            weatherUpdatedAt: weatherViewModel.weatherUpdatedAt,
            recommendation: weatherViewModel.outfitRecommendation
        )
    }

    private var refreshToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onRefresh) { Image(systemName: "arrow.clockwise") }
                .accessibilityLabel(L10n.text("Обновить погоду"))
                .disabled(weatherViewModel.isLoading)
        }
    }
}
