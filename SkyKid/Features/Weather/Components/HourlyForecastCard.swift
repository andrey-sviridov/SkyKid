import SwiftUI

struct HourlyForecastCard: View {
    let hourly: [HourlyForecast]

    private var next24: [HourlyForecast] {
        let now = Date()
        return Array(
                hourly
                .filter { $0.time >= now.addingTimeInterval(-1800) }
                .prefix(6)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Почасовой прогноз", systemImage: "clock")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            if next24.isEmpty {
                Text("Нет данных о прогнозе")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: 8) {
                        ForEach(next24, id: \.time) { item in
                            hourCell(item: item)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    private func hourCell(item: HourlyForecast) -> some View {
        VStack(spacing: 6) {
            Text(item.time, format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Image(systemName: wmoIcon(item.weatherCode))
                .font(.system(size: 22))
                .symbolRenderingMode(.multicolor)
                .frame(height: 30)

            Text("\(Int(item.temperature.rounded()))°")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(tempColorFor(item.temperature))
        }
        .frame(width: 44)
    }

    private func wmoIcon(_ code: Int) -> String {
        switch code {
        case 0:              return "sun.max.fill"
        case 1:              return "cloud.sun.fill"
        case 2, 3:           return "cloud.fill"
        case 45, 48:         return "cloud.fog.fill"
        case 51, 53, 55:     return "cloud.drizzle.fill"
        case 61, 63, 65:     return "cloud.rain.fill"
        case 71, 73, 75, 77: return "snowflake"
        case 80, 81, 82:     return "cloud.heavyrain.fill"
        case 95, 96, 99:     return "cloud.bolt.rain.fill"
        default:             return "cloud.fill"
        }
    }

    private func tempColorFor(_ t: Double) -> Color {
        switch t {
        case ..<0:    return .blue
        case 0..<12:  return Color(red: 0.2, green: 0.55, blue: 1.0)
        case 12..<22: return .green
        case 22..<28: return .orange
        default:      return .red
        }
    }
}
