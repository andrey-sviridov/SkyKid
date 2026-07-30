import SwiftUI

// MARK: - TabBarItem

struct TabBarItem: Identifiable {
    let tag: Int
    let title: String
    let systemImage: String
    var id: Int { tag }
}

// MARK: - SkyKidTabBarMetrics
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

// MARK: - CustomTabBar
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

// MARK: - StandardTabButton

private struct StandardTabButton: View {
    let item: TabBarItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 21))
                Text(item.title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.blue : Color.secondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - WalkCircleButton
// Круглая кнопка в общем ряду вкладок. Активна — нативное Liquid Glass
// стекло с очень медленной волной погодного цвета, идущей по диагонали;
// неактивна — то же стекло без тонировки, с «+».

private struct WalkCircleButton: View {
    let isActive: Bool
    let startDate: Date?
    let weatherCode: Int?
    let isSelected: Bool
    let diameter: CGFloat
    let onTapActive: () -> Void
    let onTapInactive: () -> Void

    // Угол непрерывно растёт 0→360 без autoreverse — на стыке цикла разворота
    // не видно (0° и 360° выглядят одинаково), поэтому волна идёт гладко,
    // без того самого "дёрганья" на развороте, как раньше.
    @State private var waveAngle: Double = 0

    private var tone: WeatherTone { WeatherTone(weatherCode: weatherCode) }

    var body: some View {
        Button(action: isActive ? onTapActive : onTapInactive) {
            ZStack {
                glassBase

                if isActive {
                    Circle()
                        .fill(waveGradient)
                        .opacity(0.8)
                        .clipShape(Circle())
                }

                Circle()
                    .strokeBorder(
                        isActive
                            ? Color.white.opacity(isSelected ? 0.65 : 0.35)
                            : Color.white.opacity(0.4),
                        lineWidth: isActive && isSelected ? 2 : 1.2
                    )

                if isActive, let startDate {
                    VStack(spacing: 0) {
                        Text(startDate, style: .timer)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Image(systemName: "figure.walk")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(tone.onColor)
                    .padding(.horizontal, 4)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .frame(width: diameter, height: diameter)
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                waveAngle = 360
            }
        }
        .accessibilityLabel(isActive ? L10n.text("Идёт прогулка") : L10n.text("Начать прогулку"))
    }

    @ViewBuilder
    private var glassBase: some View {
        if #available(iOS 26.0, *) {
            Circle()
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: Circle())
        } else {
            Circle().fill(.ultraThinMaterial)
        }
    }

    /// Угловой (конический) градиент, вращающийся очень медленно и без
    /// разворота — визуально это ровно та самая "волна по диагонали",
    /// проходящая через круг, а не мигающая туда-сюда заливка.
    private var waveGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: tone.colors + tone.colors.reversed()),
            center: .center,
            angle: .degrees(waveAngle)
        )
    }
}
