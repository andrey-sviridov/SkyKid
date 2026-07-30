import SwiftUI

// Заменяет нативный `.tabItem` таб-бар. Форма — скруглённая сверху стеклянная
// карточка с большой круглой кнопкой «Прогулка», выступающей над баром по
// центру (форма/расположение — по референсу пользователя; цвет/тема — наши:
// weather-градиент с переливанием, а не цвета референса).
//
// Подключается через `.safeAreaInset(edge: .bottom)` в ContentView — SwiftUI
// сам прижимает бар к низу экрана и ужимает safe area вкладок на его высоту,
// поэтому ручной арифметики с отступами внутри вкладок больше нет.
//
// Выступ круга включён в СОБСТВЕННУЮ высоту бара (через .padding(.top,...)):
// круг целиком лежит внутри фрейма, значит гарантированно принимает тапы и
// не перекрывает контент вкладок.

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let items: [TabBarItem]
    let walkTag: Int
    let isWalkActive: Bool
    let walkStartDate: Date?
    let weatherCode: Int?
    var onWalkTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private typealias Metrics = SkyKidTabBarMetrics

    private var sideItems: (left: [TabBarItem], right: [TabBarItem]) {
        let others = items.filter { $0.tag != walkTag }
        let mid = others.count / 2
        return (Array(others.prefix(mid)), Array(others.suffix(others.count - mid)))
    }

    private var barShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: Metrics.barCornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: Metrics.barCornerRadius,
            style: .continuous
        )
    }

    var body: some View {
        // Кнопка «Прогулка» — обычный элемент того же HStack, что и
        // остальные вкладки: центрируется по той же оси, что и они, вместо
        // того чтобы выступать отдельным кружком над баром.
        HStack(spacing: 4) {
            ForEach(sideItems.left) { item in
                StandardTabButton(item: item, isSelected: selectedTab == item.tag) {
                    selectedTab = item.tag
                }
            }
            WalkCircleButton(
                isActive: isWalkActive,
                startDate: walkStartDate,
                weatherCode: weatherCode,
                isSelected: selectedTab == walkTag,
                diameter: Metrics.circleDiameter,
                onTapActive: { selectedTab = walkTag },
                onTapInactive: onWalkTap
            )
            .frame(maxWidth: .infinity)
            ForEach(sideItems.right) { item in
                StandardTabButton(item: item, isSelected: selectedTab == item.tag) {
                    selectedTab = item.tag
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, Metrics.contentTopPadding)
        .padding(.bottom, Metrics.contentBottomPadding)
        .background(glassBackground)
    }

    /// Матовое стекло в стиле `skyKidCard`: материал + белый тинт + тонкая
    /// светлая рамка.
    ///
    /// Отрицательный нижний padding растягивает подложку под home indicator.
    /// `.ignoresSafeArea()` здесь НЕ работает: внутри `.safeAreaInset` у
    /// контента уже нулевые safe area insets, расширяться некуда — и полоса
    /// под баром оставалась прозрачной, сквозь неё просвечивал контент.
    private var glassBackground: some View {
        let tintOpacity: Double = colorScheme == .dark ? 0.05 : 0.42
        let strokeOpacity: Double = colorScheme == .dark ? 0.14 : 0.65

        return ZStack {
            barShape.fill(.ultraThinMaterial)
            barShape.fill(Color.white.opacity(tintOpacity))
        }
        .overlay(barShape.strokeBorder(Color.white.opacity(strokeOpacity), lineWidth: 1))
        .padding(.bottom, -80)
    }
}
