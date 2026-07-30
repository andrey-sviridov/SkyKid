import SwiftUI

struct WeatherControlsCard: View {
    @Bindable var model: WardrobeModel

    var body: some View {
        VStack(spacing: 16) {

            HStack(spacing: 14) {
                Image(systemName: model.weatherIcon)
                    .font(.system(size: 46))
                    .symbolRenderingMode(.multicolor)
                    .frame(width: 58)
                    .animation(.spring(response: 0.4), value: model.weatherIcon)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(model.temperature.rounded()))°C")
                        .font(.system(size: 50, weight: .thin, design: .rounded))
                        .foregroundStyle(model.tempColor)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.25), value: model.temperature)
                    Text("Температура на улице")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(spacing: 5) {
                Slider(value: $model.temperature, in: -25...35, step: 1)
                    .tint(model.tempColor)
                    .transaction { t in t.animation = nil }
                HStack {
                    Text("−25°")
                    Spacer()
                    Text("0°")
                    Spacer()
                    Text("+35°")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.child")
                        .foregroundStyle(.secondary)
                    Text("Возраст / активность")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Picker("Возраст", selection: $model.ageGroup) {
                    ForEach(WardrobeAgeGroup.allCases) { g in Text(g.displayName).tag(g) }
                }
                .pickerStyle(.segmented)

                Text(model.ageGroup.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.2), value: model.ageGroup)
            }
        }
        .skyKidCard()
    }
}
