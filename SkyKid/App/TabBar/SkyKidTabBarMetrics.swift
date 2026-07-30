import CoreGraphics

// `.safeAreaInset` на TabView правильно ПОЗИЦИОНИРУЕТ бар внизу экрана, но НЕ
// ужимает safe area контента вкладок (он лежит в отдельных NavigationStack'ах),
// а PreferenceKey/Environment для проброса РЕАЛЬНО измеренной высоты через
// границу `.safeAreaInset` на практике не сработал (кнопка «Завершить
// прогулку» пропадала — проверено эмпирически на симуляторе). Раз геометрия
// бара целиком в наших руках, надёжнее посчитать её один раз статически и
// использовать эту константу везде, где нужно оставить место под баром
// (ActiveWalkView, WalkHistoryView), вместо измерения в рантайме.

enum SkyKidTabBarMetrics {
    static let circleDiameter: CGFloat = 46
    static let barCornerRadius: CGFloat = 24
    static let contentTopPadding: CGFloat = 10
    static let contentBottomPadding: CGFloat = 6
    /// Высота ряда обычных пунктов: иконка(21) + spacing(3) + подпись(~11).
    static let iconRowHeight: CGFloat = 38

    /// Кнопка «Прогулка» лежит В ОДНОМ ряду с остальными пунктами (не
    /// выступает над баром) — высота ряда берётся по более высокому элементу.
    static var rowHeight: CGFloat { max(iconRowHeight, circleDiameter) }
    /// Полная высота бара — именно её нужно резервировать снизу, чтобы
    /// ничего не пряталось под баром (см. ActiveWalkView, WalkHistoryView).
    static var totalHeight: CGFloat { contentTopPadding + rowHeight + contentBottomPadding }
}
