import SwiftUI

struct ChildProfileSetupView: View {
    @Binding var profile: ChildProfile?
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var gender: ChildGender = .boy
    @State private var birthday = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
    @State private var nameError = false
    @FocusState private var nameFocused: Bool

    private var isEditing: Bool { profile != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if !isEditing {
                        welcomeHeader
                    }
                    formCard
                    previewCard
                    saveButton
                }
                .padding(20)
            }
            // Тап по ScrollView вне TextField скрывает клавиатуру
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
                name = p.name
                gender = p.gender
                birthday = p.birthday
            }
        }
    }

    // MARK: - Sections

    private var welcomeHeader: some View {
        VStack(spacing: 12) {
            Text("👶")
                .font(.system(size: 64))
            Text("Расскажите о малыше")
                .font(.title2.weight(.bold))
            Text("Чтобы SkyKid мог точнее объяснить, как ребёнок ощущает погоду")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var formCard: some View {
        VStack(spacing: 0) {

            // Имя — тап по всей ячейке фокусирует поле
            VStack(alignment: .leading, spacing: 6) {
                Label("Имя", systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Имя ребёнка", text: $name)
                    .font(.body)
                    .focused($nameFocused)
                    .submitLabel(.done)                          // Показывает «Готово» на клавиатуре
                    .onSubmit { nameFocused = false }            // Enter скрывает клавиатуру
                    .onChange(of: name) { _, _ in nameError = false }
                if nameError {
                    Text("Введите имя")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture { nameFocused = true }                 // Тап по всей строке = фокус

            Divider().padding(.leading, 16)

            // Пол
            VStack(alignment: .leading, spacing: 10) {
                Label("Пол", systemImage: "figure.child")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    ForEach(ChildGender.allCases, id: \.self) { g in
                        GenderButton(gender: g, isSelected: gender == g) {
                            nameFocused = false  // скрыть клавиатуру при выборе пола
                            gender = g
                        }
                    }
                }
            }
            .padding(16)

            Divider().padding(.leading, 16)

            // Дата рождения — compact избегает конфликта жестов со ScrollView
            HStack {
                Label("Дата рождения", systemImage: "birthday.cake.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                DatePicker(
                    "",
                    selection: $birthday,
                    in: maxBirthday...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .onChange(of: birthday) { _, _ in nameFocused = false }
            }
            .padding(16)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private var maxBirthday: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    private var previewCard: some View {
        let dummy = ChildProfile(name: name.isEmpty ? "Малыш" : name, gender: gender, birthday: birthday)
        return HStack(spacing: 16) {
            Text(gender.emoji)
                .font(.system(size: 40))
            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "Малыш" : name)
                    .font(.headline)
                Text(dummy.ageLabel + " · " + dummy.ageGroup.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Сохранить")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.blue, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Save

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            nameError = true
            return
        }
        nameFocused = false  // скрыть клавиатуру перед закрытием

        let p = ChildProfile(name: trimmed, gender: gender, birthday: birthday)
        ChildProfileStore.shared.profile = p
        profile = p

        // В режиме редактирования (sheet) нужно явно закрыть экран.
        // В режиме онбординга profile-изменение само переключает ContentView.
        if isEditing { dismiss() }
    }
}

// MARK: - GenderButton

struct GenderButton: View {
    let gender: ChildGender
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(gender.emoji)
                Text(gender.label)
                    .font(.body.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? (gender == .boy ? Color.blue : Color.pink).opacity(0.15)
                    : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? (gender == .boy ? Color.blue : Color.pink) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
