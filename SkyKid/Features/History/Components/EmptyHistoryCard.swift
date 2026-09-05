import SwiftUI

struct EmptyHistoryCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 48, weight: .thin))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)

            VStack(spacing: 6) {
                Text("Нет записей о прогулках")
                    .font(.headline)
                Text("Нажмите +, чтобы записать первую прогулку.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }
}
