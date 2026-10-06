import SwiftUI

// MARK: - WalkTabView

/// Корень вкладки «Прогулка» — роутер локального состояния прогулки.
///
/// Обычно сюда не попадают с пустыми руками: `ContentView.tabSelection`
/// перехватывает выбор вкладки и без единой живой прогулки открывает
/// `WalkSetupSheet`, не переключая вкладку.
struct WalkTabView: View {
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    var onChanged: () -> Void = {}
    var onFinished: (WalkLog) -> Void = { _ in }

    @Environment(ActiveWalkStore.self) private var activeWalkStore

    var body: some View {
        if activeWalkStore.isActive {
            ActiveWalkView(
                weather: weather,
                profile: profile,
                onChanged: onChanged,
                onFinished: onFinished
            )
        } else {
            ContentUnavailableView("Нет активной прогулки", systemImage: "figure.walk")
                .skyKidBackground()
        }
    }
}
