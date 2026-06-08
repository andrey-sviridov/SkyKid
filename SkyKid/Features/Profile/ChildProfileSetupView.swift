import SwiftUI

struct ChildProfileSetupView: View {
    @Binding var profile: ChildProfile?
    @Environment(\.dismiss) private var dismiss

    @State private var name     = ""
    @State private var gender: ChildGender = .boy
    @State private var birthday = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
    @State private var nameError  = false
    @FocusState private var nameFocused: Bool

    private var isEditing: Bool { profile != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if !isEditing { welcomeHeader }
                    formCard
                    previewCard
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "Данные ребёнка" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Готово") { save() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear {
            if let p = profile {
                name = p.name; gender = p.gender; birthday = p.birthday
            }
        }
    }

    // MARK: - Welcome header

    private var welcomeHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.28, green: 0.42, blue: 0.96),
                                     Color(red: 0.55, green: 0.28, blue: 0.92)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: Color(red: 0.28, green: 0.42, blue: 0.96).opacity(0.4),
                            radius: 16, y: 6)
                Text("👶")
                    .font(.system(size: 46))
            }

            VStack(spacing: 8) {
                Text("Расскажите о малыше")
                    .font(.title2.weight(.bold))
                Text("Чтобы SkyKid мог точнее объяснить,\nкак ребёнок ощущает погоду")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Form card

    private var formCard: some View {
        VStack(spacing: 0) {

            // Имя
            VStack(alignment: .leading, spacing: 6) {
                Label("Имя", systemImage: "person.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("Имя ребёнка", text: $name)
                    .font(.body)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { nameFocused = false }
                    .onChange(of: name) { _, _ in nameError = false }
                if nameError {
                    Label("Введите имя", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture { nameFocused = true }

            Divider().padding(.leading, 16)

            // Пол
            VStack(alignment: .leading, spacing: 10) {
                Label("Пол", systemImage: "figure.child")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    ForEach(ChildGender.allCases, id: \.self) { g in
                        GenderButton(gender: g, isSelected: gender == g) {
                            nameFocused = false
                            withAnimation(.spring(response: 0.28)) { gender = g }
                        }
                    }
                }
            }
            .padding(16)

            Divider().padding(.leading, 16)

            // Дата рождения
            HStack {
                Label("Дата рождения", systemImage: "birthday.cake.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                DatePicker("", selection: $birthday, in: maxBirthday...Date(),
                           displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .onChange(of: birthday) { _, _ in nameFocused = false }
            }
            .padding(16)
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Preview card

    private var previewCard: some View {
        let dummy = ChildProfile(name: name.isEmpty ? "Малыш" : name,
                                 gender: gender, birthday: birthday)
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(gender == .boy
                          ? Color.blue.opacity(0.12)
                          : Color.pink.opacity(0.12))
                    .frame(width: 52, height: 52)
                Text(gender.emoji)
                    .font(.system(size: 28))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "Малыш" : name)
                    .font(.headline)
                Text(dummy.ageLabel + " · " + dummy.ageGroup.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .opacity(name.isEmpty ? 0 : 1)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
        .animation(.spring(response: 0.3), value: name.isEmpty)
    }

    // MARK: - Save button

    private var saveButton: some View {
        Button(action: save) {
            Text(isEditing ? "Сохранить изменения" : "Начать")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.28, green: 0.42, blue: 0.96),
                                 Color(red: 0.55, green: 0.28, blue: 0.92)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .shadow(color: Color(red: 0.28, green: 0.42, blue: 0.96).opacity(0.35), radius: 12, y: 4)
    }

    // MARK: - Helpers

    private var maxBirthday: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { withAnimation { nameError = true }; return }
        nameFocused = false
        let p = ChildProfile(name: trimmed, gender: gender, birthday: birthday)
        ChildProfileStore.shared.profile = p
        profile = p
        if isEditing { dismiss() }
    }
}

// MARK: - GenderButton

struct GenderButton: View {
    let gender: ChildGender
    let isSelected: Bool
    let action: () -> Void

    private var accent: Color { gender == .boy ? .blue : .pink }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(gender.emoji)
                Text(gender.label)
                    .font(.body.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(
                isSelected ? accent.opacity(0.14) : Color(.tertiarySystemBackground),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? accent : Color.clear, lineWidth: 1.5)
            )
            .foregroundStyle(isSelected ? accent : .primary)
        }
        .buttonStyle(.plain)
    }
}
