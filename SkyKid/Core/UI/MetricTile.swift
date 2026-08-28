import SwiftUI

// MARK: - MetricTile

/// Метрика «значение + подпись + иконка» — один лист, из которого собираются
/// все счётчики приложения.
///
/// До этого компонента в проекте жили две несовместимые реализации одного и
/// того же: центрированная ячейка с окрашенным значением (сводка истории) и
/// левая плитка с иконкой в квадрате (карточки погоды). Оба стиля сохранены
/// как `Style`, чтобы ничего не поехало визуально, но код у них теперь общий.
///
/// Подложку компонент на себя не берёт: `.compact` живёт внутри общей
/// карточки, `.prominent` — сам себе карточка у вызывающей стороны.
struct MetricTile: View {
    enum Style {
        /// Ячейка в ряду сводки: всё по центру, значение окрашено.
        case compact
        /// Самостоятельная плитка: всё слева, иконка в скруглённом квадрате.
        case prominent
    }

    let icon: String
    let color: Color
    let value: String
    let label: String
    var style: Style = .compact
    var iconRotation: Double = 0

    var body: some View {
        switch style {
        case .compact:  compactBody
        case .prominent: prominentBody
        }
    }

    private var compactBody: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .rotationEffect(.degrees(iconRotation))

            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(color)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var prominentBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.13))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(color)
                    .rotationEffect(.degrees(iconRotation))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.weight(.semibold))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
