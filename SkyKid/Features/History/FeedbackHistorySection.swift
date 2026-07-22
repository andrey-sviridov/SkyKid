import SwiftUI

// MARK: - FeedbackHistorySection

struct FeedbackHistorySection: View {
    let items: [FeedbackHistoryItem]

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ForEach(visibleItems) { item in
                feedbackRow(item)
            }

            if items.count > collapsedLimit {
                Button(isExpanded ? "Свернуть" : "Показать все отзывы") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
                .font(.caption.weight(.semibold))
                .frame(minHeight: 44)
                .accessibilityValue(isExpanded ? "Развёрнуто" : "Свёрнуто")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
        )
        .accessibilityIdentifier("history.feedback")
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("Отзывы об одежде", systemImage: "brain.head.profile")
                .font(.subheadline.weight(.semibold))
            Text("SkyKid учитывает повторяющиеся наблюдения, но не меняет рекомендацию после одного отзыва.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Rows

    private func feedbackRow(_ item: FeedbackHistoryItem) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: systemImage(for: item.feedback))
                .foregroundStyle(tint(for: item.feedback))
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                    Spacer(minLength: 8)
                    Text(item.recordedAt, format: .dateTime.day().month(.abbreviated).hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(item.context)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.source)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - State

    private let collapsedLimit = 3

    private var visibleItems: [FeedbackHistoryItem] {
        isExpanded ? items : Array(items.prefix(collapsedLimit))
    }

    private func systemImage(for feedback: UserFeedback) -> String {
        switch feedback {
        case .tooCold:     return "thermometer.snowflake"
        case .comfortable: return "checkmark.circle.fill"
        case .tooWarm:     return "thermometer.sun.fill"
        }
    }

    private func tint(for feedback: UserFeedback) -> Color {
        switch feedback {
        case .tooCold:     return .blue
        case .comfortable: return .green
        case .tooWarm:     return .red
        }
    }
}
