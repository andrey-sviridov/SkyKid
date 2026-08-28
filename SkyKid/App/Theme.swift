import SwiftUI

// MARK: - SkyKidTheme
// Единый адаптивный визуальный язык: светлая тема — белый→небесно-синий,
// тёмная — тёмно-синий→глубокое небо. Одна точка правды для всех вкладок.

enum SkyKidTheme {

    /// Градиент для светлой темы: почти белый → нежно-голубой → небесно-синий.
    static let lightColors: [Color] = [
        Color(red: 0.93, green: 0.97, blue: 1.00),
        Color(red: 0.78, green: 0.91, blue: 0.99),
        Color(red: 0.62, green: 0.83, blue: 0.97),
    ]

    /// Градиент для тёмной темы: глубокий тёмно-синий → тёмно-небесный.
    static let darkColors: [Color] = [
        Color(red: 0.04, green: 0.09, blue: 0.20),
        Color(red: 0.05, green: 0.17, blue: 0.35),
        Color(red: 0.07, green: 0.26, blue: 0.50),
    ]

    static func background(for colorScheme: ColorScheme) -> LinearGradient {
        let colors = colorScheme == .dark ? darkColors : lightColors
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    static let cardCornerRadius: CGFloat = 20
}

// MARK: - Weather-based gradients (walk event)
// Реализация — в Core/Models/WeatherTone.swift (dual-target: нужна и
// виджет-экстеншну для Live Activity). Здесь только проброс через module-
// qualified имя, чтобы не трогать существующие вызовы вида
// `SkyKidTheme.WeatherTone(...)` / `SkyKidTheme.weatherGradient(for:)`.

extension SkyKidTheme {
    typealias WeatherTone = SkyKid.WeatherTone

    static func weatherGradient(for weatherCode: Int?) -> LinearGradient {
        SkyKid.weatherGradient(for: weatherCode)
    }
}

// MARK: - Background modifier

private struct SkyKidBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(SkyKidTheme.background(for: colorScheme).ignoresSafeArea())
            .toolbarBackground(.hidden, for: .navigationBar)
            // Светлая тема → тёмные иконки навбара; тёмная → белые.
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
    }
}

// MARK: - Card modifier (стеклянный эффект)

private struct SkyKidCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var padding: CGFloat?
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        let tintOpacity: Double = colorScheme == .dark ? 0.05 : 0.42
        let strokeOpacity: Double = colorScheme == .dark ? 0.14 : 0.65

        return content
            .padding(padding ?? 18)
            .background(
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(Color.white.opacity(tintOpacity))
                }
            )
            .overlay(shape.strokeBorder(Color.white.opacity(strokeOpacity), lineWidth: 1))
    }
}

// MARK: - Glass card modifier (преобладающий в приложении вариант)

/// Матовое стекло + тонкая рамка цветом контента.
///
/// Это не то же самое, что [SkyKidCardModifier]: там поверх стекла лежит
/// белая подложка и белая рамка. Исторически по экранам разошёлся именно
/// этот, более сдержанный вариант, и модификатор фиксирует его как есть —
/// перевод всего приложения на один стиль карточек был бы редизайном, а не
/// рефакторингом.
private struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var padding: CGFloat?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)

        return content
            .padding(padding ?? 16)
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }
}

extension View {
    /// Адаптивный небесный фон + прозрачный навбар с правильным цветом иконок.
    func skyKidBackground() -> some View {
        modifier(SkyKidBackgroundModifier())
    }

    /// Стеклянная карточка со сдержанной рамкой.
    /// `padding == nil` → дефолтные 16pt; передайте 0, чтобы задать отступы вручную.
    func glassCard(cornerRadius: CGFloat = 16, padding: CGFloat? = nil) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    /// Карточка из матового стекла поверх градиента.
    /// `padding == nil` → дефолтные 18pt; передайте 0, чтобы управлять отступами вручную.
    func skyKidCard(cornerRadius: CGFloat = SkyKidTheme.cardCornerRadius,
                    padding: CGFloat? = nil) -> some View {
        modifier(SkyKidCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
