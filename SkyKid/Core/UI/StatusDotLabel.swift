import SwiftUI

// MARK: - StatusDotLabel

/// Цветная точка + подпись: «идёт сейчас», «нет связи», «обновлено недавно».
///
/// Пульсация включается только там, где она несёт смысл («прямо сейчас»), —
/// постоянно мигающая точка в списке превращается в шум.
struct StatusDotLabel: View {
    let text: String
    var color: Color = .green
    var isPulsing: Bool = false

    @State private var isDimmed = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .opacity(isDimmed ? 0.35 : 1)
                .animation(
                    isPulsing
                        ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                        : nil,
                    value: isDimmed
                )

            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .onAppear {
            guard isPulsing else { return }
            isDimmed = true
        }
        // Точка декоративна — VoiceOver читает только подпись.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}
