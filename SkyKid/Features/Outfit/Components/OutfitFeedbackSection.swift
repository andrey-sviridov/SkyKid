import SwiftUI
import UIKit

// MARK: - OutfitFeedbackSection

struct OutfitFeedbackSection: View {
    let feedback: UserFeedback?
    let confirmationMessage: String?
    let onSelect: (UserFeedback) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                if let feedback {
                    confirmationBanner(feedback: feedback)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    buttons
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: feedback)
        }
    }

    // MARK: - Content

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("Оцените после 10–15 минут", systemImage: "hand.thumbsup")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Проверьте шею и верх спины, затем отметьте ощущение ребёнка.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    private var buttons: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        return layout {
            feedbackButton(
                label: "Холодно",
                icon: "thermometer.snowflake",
                color: .blue,
                feedback: .tooCold
            )
            feedbackButton(
                label: "Комфортно",
                icon: "checkmark.circle",
                color: .green,
                feedback: .comfortable
            )
            feedbackButton(
                label: "Жарко",
                icon: "thermometer.sun",
                color: .red,
                feedback: .tooWarm
            )
        }
    }

    private func feedbackButton(
        label: String,
        icon: String,
        color: Color,
        feedback: UserFeedback
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect(feedback)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color.opacity(0.30)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint("Сохранить оценку одежды после прогулки")
    }

    private func confirmationBanner(feedback: UserFeedback) -> some View {
        Label(
            confirmationMessage ?? "Наблюдение сохранено",
            systemImage: "brain.headset"
        )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(accent(for: feedback))
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(accent(for: feedback).opacity(0.30))
            )
    }

    private func accent(for feedback: UserFeedback) -> Color {
        switch feedback {
        case .tooCold:     return .blue
        case .comfortable: return .green
        case .tooWarm:     return .red
        }
    }
}
