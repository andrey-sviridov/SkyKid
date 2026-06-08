import SwiftUI

struct ChildProfileSetupView: View {
    @Binding var profile: ChildProfile?
    @Environment(\.dismiss) private var dismiss

    // Basic
    @State private var name     = ""
    @State private var gender: ChildGender = .boy
    @State private var birthday = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
    // Behaviour
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var walkType: WalkType = .regular
    // Preferences
    @State private var tempOffset: Double = 0
    @State private var healthFeatures: Set<HealthFeature> = []

    @State private var nameError = false
    @FocusState private var nameFocused: Bool

    private var isEditing: Bool { profile != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !isEditing { welcomeHeader }
                    formCard
                    behaviourCard
                    preferencesCard
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
                activityLevel  = p.activityLevel
                walkType       = p.walkType
                tempOffset     = p.temperaturePreferenceOffset
                healthFeatures = p.healthFeatures
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
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Behaviour card (активность + тип прогулки)

    private var behaviourCard: some View {
        VStack(spacing: 0) {
            // Активность
            VStack(alignment: .leading, spacing: 10) {
                Label("Активность на прогулке", systemImage: "figure.run")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(ActivityLevel.allCases) { level in
                        ActivityButton(level: level, isSelected: activityLevel == level) {
                            withAnimation(.spring(response: 0.28)) { activityLevel = level }
                        }
                    }
                }
            }
            .padding(16)

            Divider().padding(.leading, 16)

            // Тип прогулки
            VStack(alignment: .leading, spacing: 10) {
                Label("Тип прогулки", systemImage: "map")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(WalkType.allCases) { type in
                        WalkTypeButton(type: type, isSelected: walkType == type) {
                            withAnimation(.spring(response: 0.28)) { walkType = type }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
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
                    ForEach(Array(HealthFeature.allCases.enumerated()), id: \.element.id) { idx, feature in
                        let isLast = idx == HealthFeature.allCases.count - 1
                        HealthFeatureRow(
                            feature: feature,
                            isSelected: healthFeatures.contains(feature),
                            isLast: isLast
                        ) {
                            withAnimation(.spring(response: 0.28)) {
                                if healthFeatures.contains(feature) {
                                    healthFeatures.remove(feature)
                                } else {
                                    healthFeatures.insert(feature)
                                }
                            }
                        }
                    }
                }
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
                    .fill(gender == .boy ? Color.blue.opacity(0.12) : Color.pink.opacity(0.12))
                    .frame(width: 52, height: 52)
                Text(gender.emoji).font(.system(size: 28))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "Малыш" : name).font(.headline)
                Text(dummy.ageLabel + " · " + dummy.ageGroup.description)
                    .font(.subheadline).foregroundStyle(.secondary)
                if !healthFeatures.isEmpty || tempOffset != 0 {
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
                        startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .shadow(color: Color(red: 0.28, green: 0.42, blue: 0.96).opacity(0.35), radius: 12, y: 4)
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
        if tempOffset == 0 { return "Нейтрально" }
        let sign = tempOffset > 0 ? "+" : ""
        return "\(sign)\(Int(tempOffset * 2) % 2 == 0 ? String(Int(tempOffset)) : String(format: "%.1f", tempOffset))°"
    }

    private var previewHint: String {
        var parts: [String] = []
        if tempOffset != 0 {
            parts.append(tempOffset < 0 ? "мёрзнет" : "жаркий")
        }
        if !healthFeatures.isEmpty {
            parts.append("\(healthFeatures.count) особ.")
        }
        return parts.joined(separator: " · ")
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { withAnimation { nameError = true }; return }
        nameFocused = false
        var p = ChildProfile(name: trimmed, gender: gender, birthday: birthday)
        p.activityLevel               = activityLevel
        p.walkType                    = walkType
        p.temperaturePreferenceOffset = tempOffset
        p.healthFeatures              = healthFeatures
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
                Text(gender.label).font(.body.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 22).padding(.vertical, 11)
            .background(isSelected ? accent.opacity(0.14) : Color(.tertiarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? accent : Color.clear, lineWidth: 1.5))
            .foregroundStyle(isSelected ? accent : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ActivityButton

struct ActivityButton: View {
    let level: ActivityLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: level.icon)
                    .font(.system(size: 18, weight: .medium))
                Text(level.rawValue)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.13) : Color(.tertiarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 1.5))
            .foregroundStyle(isSelected ? .blue : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WalkTypeButton

struct WalkTypeButton: View {
    let type: WalkType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(type.label)
                        .font(.caption.weight(isSelected ? .semibold : .regular))
                    Text(type.detail)
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(isSelected ? Color.teal.opacity(0.13) : Color(.tertiarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Color.teal : Color.clear, lineWidth: 1.5))
            .foregroundStyle(isSelected ? .teal : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - HealthFeatureRow

struct HealthFeatureRow: View {
    let feature: HealthFeature
    let isSelected: Bool
    let isLast: Bool
    let action: () -> Void

    private var accent: Color {
        switch feature {
        case .frequentIllness: return .red
        case .coldSensitive:   return .blue
        case .premature:       return .pink
        case .heatSensitive:   return .orange
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? accent.opacity(0.15) : Color(.tertiarySystemBackground))
                        .frame(width: 34, height: 34)
                    Image(systemName: feature.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isSelected ? accent : .secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.label)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(.primary)
                    Text(feature.description)
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? accent : Color(.tertiarySystemFill))
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if !isLast {
            Divider().padding(.leading, 46)
        }
    }
}
