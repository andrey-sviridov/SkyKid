import SwiftUI

// Получает только value types — view identity стабильна независимо от модели

struct RiskMeterCard: View {
    let riskLevel: ThermalRisk
    let meterProgress: Double
    let currentHeat: Double
    let requiredHeat: Double
    let deviation: Double
    let riskLabel: String
    let riskDetail: String

    var body: some View {
        VStack(spacing: 14) {

            HStack(spacing: 12) {
                Image(systemName: riskLevel.symbol)
                    .font(.title)
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(riskLevel.color)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(riskLabel)
                        .font(.headline)
                        .foregroundStyle(riskLevel.color)
                    Text(riskDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .animation(.easeInOut(duration: 0.2), value: riskLevel)

            RiskMeterBar(progress: meterProgress)

            Divider()

            HStack(spacing: 0) {
                heatStat(
                    value: currentHeat,
                    label: L10n.text("Текущее\nтепло"),
                    color: riskLevel.color
                )
                Divider().frame(height: 46)
                heatStat(
                    value: requiredHeat,
                    label: L10n.text("Нужно\nтепла"),
                    color: .primary
                )
                Divider().frame(height: 46)
                heatStat(
                    value: deviation,
                    label: L10n.text("Разница"),
                    color: riskLevel.color,
                    sign: true
                )
            }
        }
        .skyKidCard()
    }

    @ViewBuilder
    private func heatStat(value: Double, label: String, color: Color, sign: Bool = false) -> some View {
        VStack(spacing: 3) {
            let prefix = sign && value > 0 ? "+" : ""
            Text("\(prefix)\(value, specifier: "%.1f")")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(color)
                .contentTransition(.numericText(countsDown: value < 0))
                .animation(.spring(response: 0.28), value: value)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
