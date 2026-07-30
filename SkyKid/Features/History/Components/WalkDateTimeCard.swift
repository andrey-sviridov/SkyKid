import SwiftUI

struct WalkDateTimeCard: View {
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Дата и время прогулки", systemImage: "calendar.clock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Если записываете позже — выберите фактическое время.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            DatePicker(
                "",
                selection: $date,
                in: ...Date.now,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }
}
