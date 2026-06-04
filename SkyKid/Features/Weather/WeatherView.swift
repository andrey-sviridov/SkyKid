import SwiftUI

struct WeatherView: View {
    let weather: WeatherData
    let cityName: String
    var profile: ChildProfile?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                if let profile {
                    ChildPerceptionCard(
                        perception: ChildWeatherPerception(profile: profile, weather: weather)
                    )
                }
                statsGrid
            }
            .padding(20)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(cityName)
                .font(.title2)
                .foregroundStyle(.secondary)

            Image(systemName: weather.conditionIcon)
                .font(.system(size: 72))
                .symbolRenderingMode(.multicolor)
                .padding(.vertical, 4)

            Text("\(Int(weather.temperature.rounded()))°")
                .font(.system(size: 80, weight: .thin))

            Text(weather.conditionDescription)
                .font(.title3)

            Text("Ощущается как \(Int(weather.apparentTemperature.rounded()))°")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(icon: "humidity.fill", color: .blue, title: "Влажность", value: "\(weather.humidity)%")
            StatCard(icon: "wind", color: .teal, title: "Ветер", value: "\(Int(weather.windSpeed.rounded())) м/с")
            StatCard(icon: "location.north.fill", color: .orange, title: "Направление", value: weather.windDirectionLabel,
                     iconRotation: Double(weather.windDirection))
            StatCard(icon: "cloud.rain.fill", color: .indigo, title: "Осадки", value: String(format: "%.1f мм", weather.precipitation))
        }
    }
}

// MARK: - Child perception card

struct ChildPerceptionCard: View {
    let perception: ChildWeatherPerception

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(spacing: 12) {
                Text(perception.moodEmoji)
                    .font(.system(size: 36))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(perception.profile.name)
                            .font(.headline)
                        Text("· \(perception.profile.ageLabel)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(perception.comfortLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(comfortColor)
                }

                Spacer()

                // Effective temperature bubble
                VStack(spacing: 2) {
                    Text("\(Int(perception.effectiveFeelsLike.rounded()))°")
                        .font(.title.weight(.semibold))
                    Text("для малыша")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Comfort bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: 6)
                    Capsule()
                        .fill(comfortColor.gradient)
                        .frame(width: geo.size.width * CGFloat(perception.comfortScore) / 100, height: 6)
                }
            }
            .frame(height: 6)

            // Summary sentence
            Text(perception.summary)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            // Age context note
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .padding(.top, 2)
                Text(perception.ageContextNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }

    private var comfortColor: Color {
        let c = perception.comfortColor
        return Color(red: c.0, green: c.1, blue: c.2)
    }
}

// MARK: - Stat card

struct StatCard: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    var iconRotation: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .rotationEffect(.degrees(iconRotation))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title2.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
