import Foundation

// MARK: - ThermalComfortCheckPolicy

/// Produces the practical observation that accompanies every recommendation.
enum ThermalComfortCheckPolicy {

    static var instruction: String {
        L10n.text("Через 10–15 минут и при смене условий проверьте живот или заднюю поверхность шеи: тёплая и сухая кожа — комфортно; горячая или влажная — снимите один лёгкий слой; прохладная — добавьте слой. Холодные кисти и стопы сами по себе не означают, что ребёнок замёрз.")
    }
}
