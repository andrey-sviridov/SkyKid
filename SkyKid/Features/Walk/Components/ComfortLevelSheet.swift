import SwiftUI

/// Короткий необязательный отзыв после прогулки.
struct ComfortLevelSheet: View {
    let garmentOptions: [GarmentItem]
    var onSubmit: (WalkCompletionFeedback) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var comfort: WalkComfortFeedback?
    @State private var clothingAdjustment: ClothingAdjustment?
    @State private var garmentID: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    question(
                        title: L10n.text("Как ребёнку было на прогулке?"),
                        values: WalkComfortFeedback.allCases.filter { $0 != .skipped },
                        selection: $comfort,
                        label: \.label
                    )

                    question(
                        title: L10n.text("Меняли одежду?"),
                        values: ClothingAdjustment.allCases,
                        selection: $clothingAdjustment,
                        label: \.label
                    )

                    if clothingAdjustment == .addedLayer || clothingAdjustment == .removedLayer {
                        garmentMenu
                    }
                }
                .padding(20)
            }
            .navigationTitle(L10n.text("Завершить прогулку"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { actions }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }

    private func question<Value: Identifiable & Equatable>(
        title: String,
        values: [Value],
        selection: Binding<Value?>,
        label: KeyPath<Value, String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            ForEach(values) { value in
                Button {
                    selection.wrappedValue = value
                } label: {
                    HStack {
                        Text(value[keyPath: label])
                        Spacer()
                        Image(systemName: selection.wrappedValue == value ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selection.wrappedValue == value ? .blue : .secondary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var garmentMenu: some View {
        Menu {
            Button(L10n.text("Не указывать")) { garmentID = nil }
            ForEach(garmentOptions) { item in
                Button(item.name) { garmentID = item.id }
            }
        } label: {
            HStack {
                Label(L10n.text("Какая вещь? (необязательно)"), systemImage: "hanger")
                Spacer()
                Text(selectedGarmentName)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityIdentifier("walk.feedback.garment")
    }

    private var selectedGarmentName: String {
        garmentOptions.first(where: { $0.id == garmentID })?.name ?? L10n.text("Не указана")
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button {
                submit(WalkCompletionFeedback(
                    comfort: comfort ?? .skipped,
                    clothingAdjustment: clothingAdjustment ?? .unknown,
                    garmentID: garmentID
                ))
            } label: {
                Text(L10n.text("Сохранить и завершить"))
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("walk.feedback.save")

            Button(L10n.text("Пропустить вопросы")) {
                submit(.skipped)
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier("walk.feedback.skip")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func submit(_ feedback: WalkCompletionFeedback) {
        onSubmit(feedback)
        dismiss()
    }
}
