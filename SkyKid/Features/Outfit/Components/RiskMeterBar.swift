import SwiftUI

struct RiskMeterBar: View {
    let progress: Double   // 0 = extreme cold · 0.5 = optimal · 1 = extreme heat

    private static let gradient = LinearGradient(
        colors: [.blue, Color(red: 0.3, green: 0.7, blue: 1), .green, .yellow, .orange, .red],
        startPoint: .leading, endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let p = max(0, min(1, progress))
                let D: CGFloat = 28
                let thumbX = (geo.size.width - D) * CGFloat(p)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Self.gradient)
                        .frame(height: 14)
                        .padding(.horizontal, D / 2)

                    Circle()
                        .fill(.white)
                        .frame(width: D, height: D)
                        .overlay(Circle().strokeBorder(thumbColor(p), lineWidth: 3))
                        .shadow(color: .black.opacity(0.14), radius: 3, x: 0, y: 2)
                        .offset(x: thumbX)
                        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: progress)
                }
            }
            .frame(height: 28)

            HStack {
                Label("Холодно", systemImage: "snowflake")
                Spacer()
                Text("Ок")
                Spacer()
                Label("Жарко", systemImage: "flame.fill")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func thumbColor(_ p: Double) -> Color {
        switch p {
        case ..<0.25:     return .blue
        case 0.25..<0.45: return Color(red: 0.3, green: 0.7, blue: 1)
        case 0.45..<0.55: return .green
        case 0.55..<0.75: return .orange
        default:          return .red
        }
    }
}
