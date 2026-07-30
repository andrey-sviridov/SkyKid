import SwiftUI

struct GarmentIconPreviewSheet: View {
    let item: GarmentItem

    var body: some View {
        VStack(spacing: 18) {
            GarmentIconView(item: item, isSelected: true, accentColor: .blue, size: 150)
                .padding(.top, 18)

            VStack(spacing: 6) {
                Text(item.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(String(format: "%.2g TOG", item.tog))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if !item.features.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(item.features, id: \.self) { feature in
                        Text(feature)
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.10), in: Capsule())
                    }
                }
            }
        }
        .padding(24)
        .presentationDetents([.height(360), .medium])
    }
}
