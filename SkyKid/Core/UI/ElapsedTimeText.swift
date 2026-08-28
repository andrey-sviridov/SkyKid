import SwiftUI

// MARK: - ElapsedTimeText

/// Счётчик времени «с момента X», который тикает сам.
///
/// `Text(date, style: .timer)` обновляется системой без таймера в модели —
/// поэтому счётчик и вынесен в отдельный компонент: его можно ставить и в
/// шапку идущей прогулки, и в строку списка, не таща за собой состояние.
/// Цвет намеренно не задаётся — его накладывает вызывающая сторона.
struct ElapsedTimeText: View {
    enum Size {
        case hero
        case compact

        var font: Font {
            switch self {
            case .hero:    .system(size: 54, weight: .semibold, design: .rounded)
            case .compact: .system(.subheadline, design: .rounded).weight(.semibold)
            }
        }
    }

    let since: Date
    var size: Size = .hero

    var body: some View {
        Text(since, style: .timer)
            .font(size.font)
            .monospacedDigit()
    }
}
