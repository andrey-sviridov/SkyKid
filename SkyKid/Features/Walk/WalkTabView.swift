import SwiftUI

// MARK: - WalkTabView

/// Корень вкладки «Прогулка». Попасть сюда можно только когда прогулка уже
/// идёт: `ContentView.tabSelection` перехватывает выбор этой вкладки и без
/// активной прогулки открывает `WalkSetupSheet`, не переключая вкладку.
struct WalkTabView: View {
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    var onChanged: () -> Void = {}

    var body: some View {
        ActiveWalkView(weather: weather, profile: profile, onChanged: onChanged)
    }
}
