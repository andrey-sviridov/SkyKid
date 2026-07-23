import SwiftUI
import AppIntents

// MARK: - ProfileSummaryView

struct ProfileSummaryView: View {
    @Binding var profile: ChildProfile?
    @State private var showEdit = false
    @State private var notificationsOn = NotificationService.shared.isEnabled
    @AppStorage("colorScheme") private var colorSchemeRaw: String = "system"

    var body: some View {
        ScrollView {
            if let p = profile {
                VStack(spacing: 20) {
                    avatarHeader(p)
                    infoCards(p)
                    wardrobeCard
                    notificationsCard
                    walkScheduleCard
                    themeCard
                    AppLanguagePickerCard()
                    siriCard
                    editButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .skyKidBackground()
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showEdit) {
            ChildProfileSetupView(profile: $profile)
        }
    }

    // MARK: - Avatar header

    private func avatarHeader(_ p: ChildProfile) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: p.gender == .boy
                                ? [Color(red: 0.28, green: 0.42, blue: 0.96),
                                   Color(red: 0.12, green: 0.60, blue: 0.86)]
                                : [Color(red: 0.92, green: 0.32, blue: 0.60),
                                   Color(red: 0.72, green: 0.18, blue: 0.78)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .shadow(color: (p.gender == .boy ? Color.blue : Color.pink).opacity(0.4),
                            radius: 14, y: 5)
                Image(systemName: "figure.child")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text(p.name)
                    .font(.title2.weight(.bold))
                Text(p.ageLabel + " · " + p.ageGroup.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Info cards

    private func infoCards(_ p: ChildProfile) -> some View {
        let ageOffset = p.ageGroup.temperatureOffset
        let showHealth = !p.stableTraits.isEmpty
        let showTempPref = p.temperaturePreferenceOffset != 0

        return VStack(spacing: 1) {
            infoRow(icon: "birthday.cake.fill", color: .pink,
                    title: L10n.text("День рождения"),
                    value: p.birthday.formatted(
                        .dateTime
                            .day()
                            .month(.wide)
                            .year()
                            .locale(L10n.locale)
                    ),
                    isFirst: true, isLast: false)

            infoRow(icon: "figure.child", color: .orange,
                    title: L10n.text("Возрастная группа"),
                    value: p.ageGroup.description,
                    isFirst: false, isLast: false)

            infoRow(icon: "heart.text.square.fill", color: .pink,
                    title: L10n.text("Срок рождения"),
                    value: p.gestationalAgeWeeks < 40
                        ? L10n.format("%lld недель", p.gestationalAgeWeeks)
                        : L10n.text("Доношенный"),
                    isFirst: false, isLast: false)

            infoRow(icon: "thermometer.medium", color: .blue,
                    title: L10n.text("Возрастная поправка"),
                    value: ageOffset == 0
                        ? L10n.text("Как у взрослого")
                        : L10n.format(
                            "%lld° (ощущает холоднее)",
                            Int(ageOffset)
                        ),
                    isFirst: false, isLast: !showTempPref && !showHealth)

            if showTempPref {
                let off = p.temperaturePreferenceOffset
                let sign = off > 0 ? "+" : ""
                infoRow(icon: "slider.horizontal.3", color: .purple,
                        title: L10n.text("Склонность"),
                        value: off < -1
                            ? L10n.format("Мёрзнет (%@%lld°)", sign, Int(off))
                            : off > 1
                                ? L10n.format("Жаркий (%@%lld°)", sign, Int(off))
                                : L10n.text("Нейтрально"),
                        isFirst: false, isLast: !showHealth)
            }

            if showHealth {
                infoRow(icon: "cross.case.fill", color: .red,
                        title: L10n.text("Особенности здоровья"),
                        value: p.stableTraits.map(\.label).sorted().joined(separator: ", "),
                        isFirst: false, isLast: true)
            }
        }
    }

    private func infoRow(icon: String, color: Color, title: String, value: String,
                         isFirst: Bool, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(color.opacity(0.13))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.regularMaterial)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius:     isFirst ? 18 : 5,
            bottomLeadingRadius:  isLast  ? 18 : 5,
            bottomTrailingRadius: isLast  ? 18 : 5,
            topTrailingRadius:    isFirst ? 18 : 5
        ))
        .padding(.vertical, 0.5)
    }

    // MARK: - Walk schedule card

    @State private var showWalkSchedule = false

    private var walkScheduleCard: some View {
        Button { showWalkSchedule = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.teal.opacity(0.13))
                        .frame(width: 36, height: 36)
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.teal)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Расписание прогулок")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(walkScheduleSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showWalkSchedule) {
            WalkScheduleView()
        }
    }

    private var walkScheduleSummary: String {
        let entries = NotificationService.shared.loadWalkSchedule().filter(\.isEnabled)
        if entries.isEmpty { return L10n.text("Нет напоминаний") }
        let times = entries.prefix(3).map(\.timeString).joined(separator: ", ")
        return L10n.format("Напоминания: %@", times)
    }

    // MARK: - Wardrobe card

    private var wardrobeCard: some View {
        NavigationLink {
            MyWardrobeView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.indigo.opacity(0.13))
                        .frame(width: 36, height: 36)
                    Image(systemName: "hanger")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.indigo)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Мой гардероб")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(wardrobeSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var wardrobeSummary: String {
        let total = GarmentCatalog.all.count - 1  // без подгузника
        let owned = GarmentCatalog.all.filter {
            $0.id != "diaper" && UserWardrobeStore.shared.isOwned($0.id)
        }.count
        return owned == total
            ? L10n.text("Все предметы каталога в наличии")
            : L10n.format(
                "В наличии %lld из %lld предметов",
                owned,
                total
            )
    }

    // MARK: - Notifications card

    private var notificationsCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.orange.opacity(0.13))
                    .frame(width: 36, height: 36)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Уведомления")
                    .font(.body)
                Text("Обновление погоды · дождевик · осторожное окно прогулки")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $notificationsOn)
                .labelsHidden()
                .tint(.orange)
                .onChange(of: notificationsOn) { _, on in
                    Task {
                        let actual = await NotificationService.shared.setEnabled(on)
                        if actual != notificationsOn { notificationsOn = actual }
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Theme card

    private var themeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Тема оформления", systemImage: "paintpalette.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HStack(spacing: 10) {
                themeOption(
                    label: L10n.text("Авто"),
                    icon: "circle.lefthalf.filled",
                    tag: "system"
                )
                themeOption(
                    label: L10n.text("Светлая"),
                    icon: "sun.max.fill",
                    tag: "light"
                )
                themeOption(
                    label: L10n.text("Тёмная"),
                    icon: "moon.fill",
                    tag: "dark"
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    private func themeOption(label: String, icon: String, tag: String) -> some View {
        let selected = colorSchemeRaw == tag
        return Button {
            withAnimation(.spring(response: 0.3)) { colorSchemeRaw = tag }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selected ? Color.blue.opacity(0.14) : Color.primary.opacity(0.07))
                        .frame(height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(selected ? .blue : .secondary)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(selected ? Color.blue : Color.clear, lineWidth: 1.5)
                )
                Text(label)
                    .font(.caption)
                    .foregroundStyle(selected ? .blue : .secondary)
                    .fontWeight(selected ? .semibold : .regular)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Siri card

    private var siriCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Спросить Siri", systemImage: "mic.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Добавьте шорткат «Что надеть» в приложение Shortcuts и назовите его любой фразой — Siri будет вызывать рекомендацию без открытия SkyKid.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if #available(iOS 17, *) {
                ShortcutsLink()
                    .shortcutsLinkStyle(.automaticOutline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button {
                    if let url = URL(string: "shortcuts://") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Открыть Shortcuts", systemImage: "arrow.up.forward.app")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Edit button

    private var editButton: some View {
        Button { showEdit = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "pencil")
                    .font(.body.weight(.medium))
                Text("Изменить данные ребёнка")
                    .font(.body.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WalkScheduleView

struct WalkScheduleView: View {
    @State private var entries: [WalkScheduleEntry] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Приложение напомнит обновить погоду и проверить самочувствие ребёнка. Сохранённый комплект не будет выдаваться за актуальный.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                Section("Напоминания") {
                    ForEach($entries) { $entry in
                        HStack {
                            Toggle(isOn: $entry.isEnabled) {
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: {
                                            Calendar.current.date(
                                                from: DateComponents(hour: entry.hour, minute: entry.minute)
                                            ) ?? .now
                                        },
                                        set: { date in
                                            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                                            entry.hour = c.hour ?? entry.hour
                                            entry.minute = c.minute ?? entry.minute
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .disabled(!entry.isEnabled)
                                .opacity(entry.isEnabled ? 1 : 0.4)
                            }
                            .tint(.teal)
                        }
                    }
                    .onDelete { offsets in entries.remove(atOffsets: offsets) }

                    if entries.count < 4 {
                        Button {
                            withAnimation { entries.append(WalkScheduleEntry(hour: 10, minute: 0)) }
                        } label: {
                            Label("Добавить время", systemImage: "plus.circle.fill")
                                .foregroundStyle(.teal)
                        }
                    }
                }
            }
            .navigationTitle("Расписание прогулок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { entries = NotificationService.shared.loadWalkSchedule() }
        }
    }

    private func save() {
        NotificationService.shared.saveWalkSchedule(entries)
        Task { await NotificationService.shared.syncWalkSchedule(entries) }
        dismiss()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("👤 Профиль") {
    NavigationStack {
        ProfileSummaryView(profile: .constant(.mock))
    }
}
#endif
