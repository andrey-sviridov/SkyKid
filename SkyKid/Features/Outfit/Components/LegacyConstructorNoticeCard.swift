import SwiftUI

// MARK: - LegacyConstructorNoticeCard

struct LegacyConstructorNoticeCard: View {
    var body: some View {
        Label {
            Text("Это экспериментальный ручной конструктор. Для прогноза и правил безопасности используйте вкладку «Одежда».")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "wrench.and.screwdriver.fill")
        }
        .font(.caption)
        .foregroundStyle(.orange)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.orange.opacity(0.35)))
    }
}
