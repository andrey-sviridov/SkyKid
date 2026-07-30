import SwiftUI

struct PermissionView: View {
    let onAllow: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 72))
                .symbolRenderingMode(.multicolor)
            Text("Нужен доступ к местоположению")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Чтобы показать актуальную погоду рядом с вами")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Разрешить", action: onAllow)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
    }
}
