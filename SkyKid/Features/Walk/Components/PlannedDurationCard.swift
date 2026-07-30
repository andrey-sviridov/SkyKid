import SwiftUI

struct PlannedDurationCard: View {
    @Binding var minutes: Int?
    private let options: [Int?] = [nil, 30, 60, 90, 120]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Планируемая длительность", systemImage: "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                        let selected = minutes == opt
                        Button { minutes = opt } label: {
                            Text(label(opt))
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .foregroundStyle(selected ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selected ? Color.blue : Color.primary.opacity(0.08), in: Capsule())
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

    private func label(_ opt: Int?) -> String {
        guard let opt else { return L10n.text("Без цели") }
        return opt >= 60
            ? L10n.format("%lld ч %lld мин", opt / 60, opt % 60).replacingOccurrences(of: " 0 мин", with: "")
            : L10n.format("%lld мин", opt)
    }
}
