import SwiftUI

// MARK: - WalkTabView

/// Корень вкладки «Прогулка» — роутер на три состояния: своя прогулка идёт,
/// идёт прогулка второго родителя, не идёт ничего.
///
/// Обычно сюда не попадают с пустыми руками: `ContentView.tabSelection`
/// перехватывает выбор вкладки и без единой живой прогулки открывает
/// `WalkSetupSheet`, не переключая вкладку.
struct WalkTabView: View {
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    var onChanged: () -> Void = {}
    var onFinished: (WalkLog) -> Void = { _ in }
    var onStartOwnWalk: () -> Void = {}

    @Environment(ActiveWalkStore.self) private var activeWalkStore
    @Environment(LiveWalkObserver.self) private var liveWalkObserver

    var body: some View {
        // Своя прогулка важнее чужой: если гуляют оба, владельцу нужен свой
        // экран с кнопками, а не наблюдение за вторым родителем.
        if activeWalkStore.isActive {
            ActiveWalkView(
                weather: weather,
                profile: profile,
                onChanged: onChanged,
                onFinished: onFinished
            )
        } else if let partner = liveWalkObserver.partner {
            LiveWalkDetailView(
                snapshot: partner,
                weather: weather,
                profile: profile,
                onStartOwnWalk: onStartOwnWalk
            )
        } else {
            ContentUnavailableView("Нет активной прогулки", systemImage: "figure.walk")
                .skyKidBackground()
        }
    }
}
