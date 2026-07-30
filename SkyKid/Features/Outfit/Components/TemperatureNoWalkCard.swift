import SwiftUI

struct TemperatureNoWalkCard: View {
    let isHot: Bool
    let temperature: Double

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: isHot ? "thermometer.sun.fill" : "snowflake.circle.fill")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundStyle(isHot ? .red : .blue)
                    .symbolEffect(.pulse)

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        isHot
                            ? L10n.text("Слишком жарко для прогулки")
                            : L10n.text("Слишком холодно для прогулки")
                    )
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(
                        isHot
                            ? L10n.format(
                                "При %lld° прогулка опасна для ребёнка.",
                                Int(temperature.rounded())
                            )
                            : L10n.format(
                                "При %lld° высок риск переохлаждения.",
                                Int(temperature.rounded())
                            )
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Text(
                isHot
                    ? L10n.text(
                        "Перенесите выход на более прохладное время. Для младенца — тень и обычные кормления чаще."
                    )
                    : L10n.text(
                        "Прогулку лучше перенести. Одежда не отменяет риск от экстремального холода."
                    )
            )
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background((isHot ? Color.red : Color.blue).opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder((isHot ? Color.red : Color.blue).opacity(0.25), lineWidth: 1))
    }
}
