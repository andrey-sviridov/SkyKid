import SwiftUI

struct ChildProfileSetupView: View {
    @Binding var profile: ChildProfile?
    @Environment(\.dismiss) private var dismiss
    @Environment(ChildProfileStore.self) private var childProfileStore

    // Basic
    @State private var name     = ""
    @State private var gender: ChildGender = .boy
    @State private var birthday = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
    // Preferences
    @State private var tempOffset: Double = 0
    @State private var stableTraits: Set<StableThermalTrait> = []
    // Persistent birth data
    @State private var bornEarly = false
    @State private var gestationalAgeWeeks = 36

    @State private var nameError = false
    @FocusState private var nameFocused: Bool

    private var isEditing: Bool { profile != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !isEditing { welcomeHeader }
                    formCard
                    if isInfantOrBaby {
                        togCard
                    }
                    preferencesCard
                    previewCard
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.immediately)
            .skyKidBackground()
            .navigationTitle(isEditing ? L10n.text("Данные ребёнка") : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Готово") { save() }.fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear {
            if let p = profile {
                name           = p.name
                gender         = p.gender
                birthday       = p.birthday
                tempOffset     = p.temperaturePreferenceOffset
                stableTraits   = p.stableTraits
                bornEarly      = p.gestationalAgeWeeks < 40
                if bornEarly { gestationalAgeWeeks = p.gestationalAgeWeeks }
            }
        }
    }

    // MARK: - Welcome header

    private var welcomeHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.28, green: 0.42, blue: 0.96),
                                 Color(red: 0.55, green: 0.28, blue: 0.92)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 96, height: 96)
                    .shadow(color: Color(red: 0.28, green: 0.42, blue: 0.96).opacity(0.4),
                            radius: 16, y: 6)
                Text("👶").font(.system(size: 46))
            }
            VStack(spacing: 8) {
                Text("Расскажите о малыше")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Text("Чтобы SkyKid мог точнее объяснить,\nкак ребёнок ощущает погоду")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Basic info card

    private var formCard: some View {
        VStack(spacing: 0) {
            // Имя
            VStack(alignment: .leading, spacing: 6) {
                Label("Имя", systemImage: "person.fill")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                TextField("Имя ребёнка", text: $name)
                    .font(.body)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { nameFocused = false }
                    .onChange(of: name) { _, _ in nameError = false }
                if nameError {
                    Label("Введите имя", systemImage: "exclamationmark.circle.fill")
                        .font(.caption).foregroundStyle(.red)
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
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
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
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                DatePicker("", selection: $birthday, in: maxBirthday...Date(),
                           displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .onChange(of: birthday) { _, _ in nameFocused = false }
            }
            .padding(16)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Preferences card (температура + здоровье)

    private var preferencesCard: some View {
        VStack(spacing: 0) {
            // Слайдер склонности к температуре
            VStack(alignment: .leading, spacing: 12) {
                Label("Склонность к температуре", systemImage: "thermometer.medium")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    Slider(value: $tempOffset, in: -3...3, step: 0.5)
                        .tint(sliderTint)
                    HStack {
                        Text("Мёрзнет")
                            .font(.caption2).foregroundStyle(.blue)
                        Spacer()
                        Text(tempOffsetLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tempOffsetColor)
                        Spacer()
                        Text("Жаркий")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                }
            }
            .padding(16)

            Divider().padding(.leading, 16)

            // Особенности здоровья
            VStack(alignment: .leading, spacing: 12) {
                Label("Особенности здоровья", systemImage: "cross.case.fill")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    ForEach(Array(StableThermalTrait.allCases.enumerated()), id: \.element.id) { idx, trait in
                        let isLast = idx == StableThermalTrait.allCases.count - 1
                        StableThermalTraitRow(
                            trait: trait,
                            isSelected: stableTraits.contains(trait),
                            isLast: isLast
                        ) {
                            withAnimation(.spring(response: 0.28)) {
                                if stableTraits.contains(trait) {
                                    stableTraits.remove(trait)
                                } else {
                                    stableTraits.insert(trait)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Preview card

    private var previewCard: some View {
        let placeholderName = L10n.text("Малыш")
        let dummy = ChildProfile(name: name.isEmpty ? placeholderName : name,
                                 gender: gender, birthday: birthday)
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(gender == .boy ? Color.blue.opacity(0.12) : Color.pink.opacity(0.12))
                    .frame(width: 52, height: 52)
                Text(gender.emoji).font(.system(size: 28))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? placeholderName : name).font(.headline)
                Text(dummy.ageLabel + " · " + dummy.ageGroup.description)
                    .font(.subheadline).foregroundStyle(.secondary)
                if !stableTraits.isEmpty || tempOffset != 0 {
                    Text(previewHint)
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.title2).foregroundStyle(.green)
                .opacity(name.isEmpty ? 0 : 1)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
        .animation(.spring(response: 0.3), value: name.isEmpty)
    }

    // MARK: - Save button

    private var saveButton: some View {
        Button(action: save) {
            Text(
                isEditing
                    ? L10n.text("Сохранить изменения")
                    : L10n.text("Начать")
            )
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.28, green: 0.42, blue: 0.96),
                                 Color(red: 0.55, green: 0.28, blue: 0.92)],
                        startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .shadow(color: Color(red: 0.28, green: 0.42, blue: 0.96).opacity(0.35), radius: 12, y: 4)
    }

    // MARK: - Birth data

    private var isInfantOrBaby: Bool {
        let months = Calendar.current.dateComponents([.month], from: birthday, to: Date()).month ?? 0
        return months < 36
    }

    // MARK: - Gestational age card

    private var togCard: some View {
        VStack(spacing: 0) {
            // Недоношенность
            VStack(alignment: .leading, spacing: 10) {
                Label("Недоношенность", systemImage: "heart.text.square.fill")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)

                Toggle("Родился раньше срока", isOn: $bornEarly.animation(.spring(response: 0.28)))
                    .font(.subheadline)
                    .tint(.pink)

                if bornEarly {
                    Stepper(value: $gestationalAgeWeeks, in: 28...39) {
                        HStack(spacing: 6) {
                            Text("Срок гестации:")
                                .font(.subheadline)
                            Text("\(gestationalAgeWeeks) нед.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.pink)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)

        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Helpers

    private var sliderTint: Color {
        if tempOffset < 0 { return .blue }
        if tempOffset > 0 { return .orange }
        return .green
    }

    private var tempOffsetColor: Color {
        if tempOffset == 0 { return Color.secondary }
        return tempOffset < 0 ? .blue : .orange
    }

    private var maxBirthday: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    private var tempOffsetLabel: String {
        if tempOffset == 0 { return L10n.text("Нейтрально") }
        let sign = tempOffset > 0 ? "+" : ""
        return "\(sign)\(Int(tempOffset * 2) % 2 == 0 ? String(Int(tempOffset)) : String(format: "%.1f", tempOffset))°"
    }

    private var previewHint: String {
        var parts: [String] = []
        if tempOffset != 0 {
            parts.append(
                tempOffset < 0
                    ? L10n.text("мёрзнет")
                    : L10n.text("жаркий")
            )
        }
        if !stableTraits.isEmpty {
            parts.append(L10n.format("%lld особ.", stableTraits.count))
        }
        return parts.joined(separator: " · ")
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { withAnimation { nameError = true }; return }
        nameFocused = false
        var p = ChildProfile(name: trimmed, gender: gender, birthday: birthday)
        p.temperaturePreferenceOffset = tempOffset
        p.stableTraits                = stableTraits
        p.gestationalAgeWeeks         = bornEarly ? gestationalAgeWeeks : 40
        childProfileStore.profile = p
        profile = p
        if isEditing { dismiss() }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("📝 Онбординг") {
    ChildProfileSetupView(profile: .constant(nil))
        .environment(ChildProfileStore.shared)
}

#Preview("✏️ Редактирование") {
    ChildProfileSetupView(profile: .constant(.mock))
        .environment(ChildProfileStore.shared)
}
#endif
