import SwiftUI

// Круглая кнопка в общем ряду вкладок. Активна — нативное Liquid Glass
// стекло с очень медленной волной погодного цвета, идущей по диагонали;
// неактивна — то же стекло без тонировки, с «+».

struct WalkCircleButton: View {
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
