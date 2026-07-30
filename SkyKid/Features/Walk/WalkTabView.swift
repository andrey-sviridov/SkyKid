import SwiftUI

// MARK: - WalkTabView

/// Корень вкладки «Прогулка». Кастомный таб-бар ([App/CustomTabBar.swift])
/// сам решает, когда сюда попадать: без активной прогулки тап открывает
/// `WalkSetupSheet` напрямую из `ContentView`, минуя эту вкладку — сюда
/// переключают только когда прогулка уже идёт.
struct WalkTabView: View {
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    var onChanged: () -> Void = {}

    var body: some View {
        ActiveWalkView(weather: weather, profile: profile, onChanged: onChanged)
    }
}
