import SwiftUI

// MARK: - SectionCard

/// Карточка-секция: заголовок вторичным шрифтом, опциональный элемент справа
/// и произвольное содержимое на стеклянной подложке.
///
/// Заголовок принимается уже локализованной строкой (`L10n.text(...)`), а не
/// литералом: `Label(_ title: S, systemImage:)` со `String`-параметром ничего
/// не локализует, а литералы в этом проекте и так не переводятся — скрипт
/// собирает ключи только из вызовов `L10n`.
struct SectionCard<Content: View, Trailing: View>: View {
    let title: String
    let systemImage: String
    var cornerRadius: CGFloat = 16
    var spacing: CGFloat = 12

    @ViewBuilder let content: () -> Content
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        systemImage: String,
        cornerRadius: CGFloat = 16,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.systemImage = systemImage
        self.cornerRadius = cornerRadius
        self.spacing = spacing
        self.content = content
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                trailing()
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: cornerRadius)
    }
}

extension SectionCard where Trailing == EmptyView {
    init(
        title: String,
        systemImage: String,
        cornerRadius: CGFloat = 16,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            cornerRadius: cornerRadius,
            spacing: spacing,
            content: content,
            trailing: { EmptyView() }
        )
    }
}
