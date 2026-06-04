import SwiftUI

struct OutfitView: View {
    let weather: WeatherData
    var profile: ChildProfile?

    private var items: [OutfitItem] { OutfitAdvisor.recommend(weather: weather, profile: profile) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryBanner
                itemsList
            }
            .padding(20)
        }
        .navigationTitle(profile.map { "Одеваем \($0.name(.accusative))" } ?? "Что надеть малышу")
        .navigationBarTitleDisplayMode(.large)
    }

    private var summaryBanner: some View {
        HStack(spacing: 16) {
            Text(outfitEmoji)
                .font(.system(size: 56))

            VStack(alignment: .leading, spacing: 4) {
                Text(outfitTitle)
                    .font(.headline)
                if let profile {
                    let offset = profile.ageGroup.temperatureOffset
                    let effective = Int((weather.apparentTemperature + offset).rounded())
                    Text("Для \(profile.ageLabel) ощущается как \(effective)°")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("На улице \(Int(weather.temperature.rounded()))°, ощущается \(Int(weather.apparentTemperature.rounded()))°")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(bannerGradient, in: RoundedRectangle(cornerRadius: 20))
    }

    private var itemsList: some View {
        VStack(spacing: 1) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 14) {
                    Text(item.icon)
                        .font(.title)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.body.weight(.medium))
                        Text(item.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(roundedShape(index: index, total: items.count))
                .padding(.vertical, 0.5)
            }
        }
    }

    private func roundedShape(index: Int, total: Int) -> some Shape {
        let top: CGFloat = index == 0 ? 16 : 4
        let bottom: CGFloat = index == total - 1 ? 16 : 4
        return UnevenRoundedRectangle(
            topLeadingRadius: top, bottomLeadingRadius: bottom,
            bottomTrailingRadius: bottom, topTrailingRadius: top
        )
    }

    private var effectiveTemp: Double {
        weather.apparentTemperature + (profile?.ageGroup.temperatureOffset ?? 0)
    }

    private var outfitEmoji: String {
        switch effectiveTemp {
        case ..<0:    return "🥶"
        case 0..<10:  return "🧥"
        case 10..<18: return "😊"
        default:      return "☀️"
        }
    }

    private var outfitTitle: String {
        switch effectiveTemp {
        case ..<0:    return "Одеваемся тепло!"
        case 0..<10:  return "Не забудьте куртку"
        case 10..<18: return "Лёгкий слой"
        default:      return "Легко и комфортно"
        }
    }

    private var bannerGradient: LinearGradient {
        let t = effectiveTemp
        let colors: [Color] = t < 0 ? [.blue.opacity(0.3), .cyan.opacity(0.2)]
            : t < 15 ? [.teal.opacity(0.3), .blue.opacity(0.2)]
            : [.orange.opacity(0.3), .yellow.opacity(0.2)]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
