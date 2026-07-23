import SwiftUI
import WidgetKit

// MARK: - App Language Picker Card

struct AppLanguagePickerCard: View {
    @AppStorage(
        AppLanguagePreferences.storageKey,
        store: AppGroup.defaults
    )
    private var selectedLanguageRawValue = AppLanguage.system.rawValue

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguageRawValue) ?? .system
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                languageIcon
                languageDescription
                Spacer(minLength: 0)
            }

            languageMenu
        }
        .padding(16)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
        )
        .onChange(of: selectedLanguageRawValue) { _, _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

// MARK: - Components

private extension AppLanguagePickerCard {
    var languageIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.blue.opacity(0.13))
                .frame(width: 36, height: 36)

            Image(systemName: "globe")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.blue)
        }
    }

    var languageDescription: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Язык приложения")
                .font(.body)

            Text("Изменения применяются сразу")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    var languageMenu: some View {
        Menu {
            Picker(
                "Язык приложения",
                selection: $selectedLanguageRawValue
            ) {
                ForEach(AppLanguage.allCases) { language in
                    Text(verbatim: language.displayName)
                        .tag(language.rawValue)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(verbatim: selectedLanguage.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .accessibilityLabel(L10n.text("Язык приложения"))
        .accessibilityValue(selectedLanguage.displayName)
    }
}
