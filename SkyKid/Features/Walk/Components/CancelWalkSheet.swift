import SwiftUI

/// Свой bottom sheet подтверждения отмены прогулки без сохранения — замена
/// системного confirmationDialog.
struct CancelWalkSheet: View {
    var onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Отменить прогулку без сохранения?")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            VStack(spacing: 10) {
                Button {
                    onConfirm()
                    dismiss()
                } label: {
                    Text("Удалить прогулку")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Button("Отмена") { dismiss() }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }
}
