import SwiftUI

struct DurationPickerCard: View {
    @Binding var durationMinutes: Int
    private let options = [15, 30, 45, 60, 90, 120]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Длительность прогулки", systemImage: "clock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(options, id: \.self) { mins in
                        let selected = durationMinutes == mins
                        Button { durationMinutes = mins } label: {
                            Text(durationLabel(mins))
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .foregroundStyle(selected ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    selected
                                        ? Color.blue
                                        : Color.primary.opacity(0.08),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.25), value: selected)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    private func durationLabel(_ mins: Int) -> String {
        WalkDurationFormatter.string(minutes: mins)
    }
}
