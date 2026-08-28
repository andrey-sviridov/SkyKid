import SwiftUI

// MARK: - CountdownLabel

/// Обратный отсчёт до цели: пока цель впереди — тикающий остаток, после —
/// фиксированная подпись «цель достигнута».
///
/// Цвет накладывает вызывающая сторона, как и у [ElapsedTimeText].
struct CountdownLabel: View {
    let target: Date
    var systemImage: String = "hourglass"
    var ongoingText: String
    var finishedText: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            if target > .now {
                Text(ongoingText)
                Text(target, style: .timer)
                    .monospacedDigit()
            } else {
                Text(finishedText)
            }
        }
        .font(.subheadline.weight(.medium))
    }
}
