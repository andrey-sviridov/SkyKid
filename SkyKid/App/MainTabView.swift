import SwiftUI

// MARK: - MainTab

enum MainTab: CaseIterable, Hashable {
    case today
    case walk
    case history
    case profile
}

// MARK: - MainTabView

struct MainTabView: View {
    @Binding var selection: MainTab
    @Binding var profile: ChildProfile?

    let weatherViewModel: WeatherViewModel
    let walkContext: WalkContext?
    let personalOffsetStore: PersonalOffsetStore
    let onWalkContextChange: (WalkContext) -> Void
    let onRefresh: () -> Void
    let onStartWalk: () -> Void
    let onFinishWalk: (WalkLog) -> Void
    let onPersonalizationChange: () -> Void

    @Environment(ActiveWalkStore.self) private var activeWalkStore

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                TodayView(
                    weatherViewModel: weatherViewModel,
                    profile: profile,
                    walkContext: walkContext,
                    personalOffsetStore: personalOffsetStore,
                    onWalkContextChange: onWalkContextChange,
                    onRefresh: onRefresh,
                    onStartWalk: onStartWalk
                )
            }
            .tabItem { Label(L10n.text("Сегодня"), systemImage: "sun.max.fill") }
            .tag(MainTab.today)
            .accessibilityIdentifier("tab.today")

            if activeWalkStore.isActive {
                NavigationStack {
                    WalkTabView(
                        weather: weatherViewModel.weather,
                        profile: profile,
                        onChanged: onPersonalizationChange,
                        onFinished: onFinishWalk
                    )
                }
                .tabItem { Label(L10n.text("Прогулка"), systemImage: "figure.walk.motion") }
                .tag(MainTab.walk)
                .accessibilityIdentifier("tab.walk")
            }

            NavigationStack {
                WalkHistoryView(
                    weather: weatherViewModel.weather,
                    profile: profile,
                    recommendation: weatherViewModel.outfitRecommendation,
                    walkContext: walkContext,
                    onPersonalizationChange: onPersonalizationChange
                )
            }
            .tabItem { Label(L10n.text("История"), systemImage: "clock.arrow.circlepath") }
            .tag(MainTab.history)
            .accessibilityIdentifier("tab.history")

            NavigationStack { ProfileSummaryView(profile: $profile) }
                .tabItem {
                    Label(profile.map(\.name) ?? L10n.text("Малыш"), systemImage: "person.circle.fill")
                }
                .tag(MainTab.profile)
                .accessibilityIdentifier("tab.profile")
        }
    }
}
