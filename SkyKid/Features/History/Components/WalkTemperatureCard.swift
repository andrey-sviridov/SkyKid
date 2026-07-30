import SwiftUI

struct WalkTemperatureCard: View {
    @Binding var temperature: Double

    private var tempColor: Color {
        switch temperature {
        case ...0:    return .blue
        case 0..<15:  return Color(red: 0.2, green: 0.55, blue: 1.0)
        case 15..<22: return .green
        case 22..<28: return .orange
        default:      return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Температура на прогулке", systemImage: "thermometer.medium")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Введите температуру того момента — если записываете позже.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 20) {
                stepButton(icon: "minus", action: { temperature = max(-30, temperature - 1) })

                Spacer()

                Text("\(Int(temperature.rounded()))°C")
                    .font(.system(size: 44, weight: .thin, design: .rounded))
                    .foregroundStyle(tempColor)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25), value: temperature)
                    .frame(minWidth: 100)

                Spacer()

                stepButton(icon: "plus", action: { temperature = min(45, temperature + 1) })
            }

            Slider(value: $temperature, in: -30...45, step: 1)
                .tint(tempColor)
                .transaction { t in t.animation = nil }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    private func stepButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation { action() } }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
            }
        }
        .buttonStyle(.plain)
    }
}
