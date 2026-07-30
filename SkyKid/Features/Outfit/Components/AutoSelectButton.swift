import SwiftUI

struct AutoSelectButton: View {
    let tempLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Автоподбор одежды")
                        .font(.headline)
                    Text("Оптимально для \(tempLabel)")
                        .font(.caption)
                        .opacity(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .opacity(0.6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.32, blue: 0.96),
                             Color(red: 0.44, green: 0.14, blue: 0.86)],
                    startPoint: .leading, endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}
