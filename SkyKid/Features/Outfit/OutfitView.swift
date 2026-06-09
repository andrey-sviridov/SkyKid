import SwiftUI

// MARK: - OutfitView

struct OutfitView: View {
    let weather: WeatherData
    var profile: ChildProfile?

    @State private var feedbackSent: UserFeedback? = nil

    // MARK: Engine integration

    private var outfit: LayeredOutfit? {
        guard let profile else { return nil }
        let bias = BiasStore.shared.currentBias(for: profile, feelsLike: weather.apparentTemperature)
        return ClothingRecommendationEngine.recommend(weather: weather, profile: profile, learnedBias: bias)
    }

    private var effectiveTemp: Double {
        outfit?.effectiveTemp ?? weather.apparentTemperature
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            backgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.9), value: gradientKey)

            if let profile, profile.strollerType.isSafetyAlarm,
               profile.ageGroup == .infant || profile.ageGroup == .baby {
                // Source: Алгоритм одевания младенца, стр. 5-6
                // Накрытая коляска → парниковый эффект + ребризинг CO₂ → риск СВСМ.
                // Алерт только для детей до 12 мес — СВСМ-риск специфичен для этого возраста.
                strollerSafetyAlertView(profile: profile)
            } else if let profile, let outfit {
                ScrollView {
                    VStack(spacing: 14) {
                        heroCard(outfit: outfit, profile: profile)
                        perceptionNote(profile: profile, outfit: outfit)
                        conditionsBadges
                        layersSection(outfit: outfit)
                        feedbackSection(profile: profile)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
            } else {
                ContentUnavailableView(
                    "Создайте профиль ребёнка",
                    systemImage: "person.badge.plus",
                    description: Text("Профиль поможет рассчитать одежду точнее")
                )
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(profile.map { "Одеваем \($0.name(.accusative))" } ?? "Что надеть")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Stroller safety alert

    private func strollerSafetyAlertView(profile: ChildProfile) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse)
                        .padding(.top, 32)
                    Text("ОПАСНО")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(.white)
                    Text("Накрытая коляска опасна для жизни")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 14) {
                    strollerAlertRow(icon: "thermometer.sun.fill",
                                     text: "Температура внутри накрытой коляски достигает критического уровня за 30 минут")
                    strollerAlertRow(icon: "lungs.fill",
                                     text: "Плотная накидка блокирует воздух — накапливается CO₂, угнетается дыхание")
                    strollerAlertRow(icon: "heart.slash.fill",
                                     text: "Прямой риск синдрома внезапной смерти младенца (СВСМ)")
                }
                .padding(18)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.red.opacity(0.4), lineWidth: 1))

                Text("Снимите накидку прямо сейчас. Для защиты от солнца используйте только сетчатый тент с вентиляцией.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
    }

    private func strollerAlertRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.red)
                .frame(width: 26)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Background gradient

    // Round to nearest 4°C to avoid re-triggering gradient on every decimal change
    private var gradientKey: Int { Int((effectiveTemp / 4).rounded()) }

    private var backgroundGradient: LinearGradient {
        let (c1, c2): (Color, Color)
        switch effectiveTemp {
        case ..<(-10):
            c1 = Color(red: 0.05, green: 0.05, blue: 0.22)
            c2 = Color(red: 0.10, green: 0.16, blue: 0.36)
        case -10..<0:
            c1 = Color(red: 0.04, green: 0.12, blue: 0.32)
            c2 = Color(red: 0.08, green: 0.28, blue: 0.52)
        case 0..<8:
            c1 = Color(red: 0.06, green: 0.24, blue: 0.48)
            c2 = Color(red: 0.10, green: 0.46, blue: 0.64)
        case 8..<16:
            c1 = Color(red: 0.00, green: 0.36, blue: 0.52)
            c2 = Color(red: 0.04, green: 0.54, blue: 0.44)
        case 16..<22:
            c1 = Color(red: 0.54, green: 0.34, blue: 0.06)
            c2 = Color(red: 0.82, green: 0.56, blue: 0.16)
        default:
            c1 = Color(red: 0.66, green: 0.20, blue: 0.04)
            c2 = Color(red: 0.96, green: 0.46, blue: 0.14)
        }
        return LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Hero card

    private func heroCard(outfit: LayeredOutfit, profile: ChildProfile) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: weather.conditionIcon)
                    .font(.system(size: 56))
                    .symbolRenderingMode(.multicolor)
                    .symbolEffect(.bounce, value: weather.weatherCode)
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 5)

                Spacer()

                VStack(spacing: 1) {
                    Text("\(Int(outfit.effectiveTemp.rounded()))°")
                        .font(.system(size: 54, weight: .thin, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: outfit.effectiveTemp)
                    Text("для \(profile.ageLabel)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(outfitTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("На улице \(Int(weather.temperature.rounded()))° · ощущается \(Int(weather.apparentTemperature.rounded()))°")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.70))
                    let delta = Int((outfit.effectiveTemp - weather.apparentTemperature).rounded())
                    if delta != 0 {
                        Text("С учётом профиля: \(delta > 0 ? "+" : "")\(delta)°")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.50))
                    }
                }
                Spacer()
                Image(systemName: outfitIcon)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
                    .symbolRenderingMode(.hierarchical)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.18), lineWidth: 1))
    }

    // MARK: - Perception note

    private func perceptionNote(profile: ChildProfile, outfit: LayeredOutfit) -> some View {
        // Используем effectiveTemp из рекомендации — одна формула с расчётом одежды
        let p = ChildWeatherPerception(profile: profile, weather: weather, effectiveTemp: outfit.effectiveTemp)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: p.moodSystemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(red: p.moodColor.0, green: p.moodColor.1, blue: p.moodColor.2))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(p.summary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                Text(p.ageContextNote)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Condition badges

    @ViewBuilder
    private var conditionsBadges: some View {
        let hasWind = weather.windSpeed > 7
        let hasSnow = (71...77).contains(weather.weatherCode)
        let hasRain = !hasSnow && ((51...82).contains(weather.weatherCode) || weather.precipitation > 0.1)

        if hasWind || hasRain || hasSnow {
            HStack(spacing: 8) {
                if hasWind {
                    conditionChip(icon: "wind", label: "\(Int(weather.windSpeed.rounded())) м/с", color: .cyan)
                }
                if hasSnow {
                    conditionChip(icon: "snowflake", label: "Снег", color: .blue)
                } else if hasRain {
                    conditionChip(icon: "cloud.rain.fill", label: "Дождь", color: .indigo)
                }
                Spacer()
            }
        }
    }

    private func conditionChip(icon: String, label: String, color: Color) -> some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Layers section

    @ViewBuilder
    private func layersSection(outfit: LayeredOutfit) -> some View {
        let layers = outfit.allLayers
        if layers.isEmpty {
            Text("Лёгкое и удобное — больше ничего не нужно")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Label("Что надеть", systemImage: "hanger")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.65))
                    Spacer()
                    Text("\(layers.count) \(itemsWord(layers.count))")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(Array(layers.enumerated()), id: \.element.id) { idx, layer in
                        layerRow(layer: layer, index: idx, isLast: idx == layers.count - 1)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal:   .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: layers.map(\.name))
            }
        }
    }

    private func layerRow(layer: LayeredOutfit.Layer, index: Int, isLast: Bool) -> some View {
        let isFirst = index == 0
        let radius: (CGFloat, CGFloat) = (isFirst ? 18 : 6, isLast ? 18 : 6)

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(rowAccent(index).opacity(0.22))
                    .frame(width: 44, height: 44)
                Image(systemName: layer.systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(rowAccent(index))
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(layer.name)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text(layer.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "checkmark")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.regularMaterial)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius:     radius.0,
                bottomLeadingRadius:  radius.1,
                bottomTrailingRadius: radius.1,
                topTrailingRadius:    radius.0
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius:     radius.0,
                bottomLeadingRadius:  radius.1,
                bottomTrailingRadius: radius.1,
                topTrailingRadius:    radius.0
            )
            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.vertical, 0.5)
    }

    // MARK: - Feedback section

    private func feedbackSection(profile: ChildProfile) -> some View {
        VStack(spacing: 0) {
            HStack {
                Label("Оцените одежду", systemImage: "hand.thumbsup")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)

            ZStack {
                if let sent = feedbackSent {
                    confirmationBanner(feedback: sent)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
                } else {
                    feedbackButtons(profile: profile)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: feedbackSent == nil)
        }
    }

    private func feedbackButtons(profile: ChildProfile) -> some View {
        HStack(spacing: 8) {
            feedbackButton(label: "Холодно", icon: "thermometer.snowflake", color: .blue) {
                BiasStore.shared.record(.tooCold, for: profile, feelsLike: weather.apparentTemperature)
                triggerFeedback(.tooCold)
            }
            feedbackButton(label: "Комфортно", icon: "checkmark.circle", color: .green) {
                triggerFeedback(.comfortable)
            }
            feedbackButton(label: "Жарко", icon: "thermometer.sun", color: .red) {
                BiasStore.shared.record(.tooWarm, for: profile, feelsLike: weather.apparentTemperature)
                triggerFeedback(.tooWarm)
            }
        }
    }

    private func feedbackButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func confirmationBanner(feedback: UserFeedback) -> some View {
        Label("Учту на следующей прогулке", systemImage: "brain.headset")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(feedbackAccent(feedback))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(feedbackAccent(feedback).opacity(0.30), lineWidth: 1)
            )
    }

    private func triggerFeedback(_ feedback: UserFeedback) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            feedbackSent = feedback
        }
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                feedbackSent = nil
            }
        }
    }

    private func feedbackAccent(_ feedback: UserFeedback) -> Color {
        switch feedback {
        case .tooCold:     return .blue
        case .comfortable: return .green
        case .tooWarm:     return .red
        }
    }

    // MARK: - Helpers

    private var outfitIcon: String {
        switch effectiveTemp {
        case ..<(-10): return "thermometer.snowflake.circle.fill"
        case -10..<0:  return "snowflake"
        case 0..<10:   return "cloud.snow.fill"
        case 10..<18:  return "cloud.sun.fill"
        default:       return "sun.max.fill"
        }
    }

    private var outfitTitle: String {
        switch effectiveTemp {
        case ..<0:    return "Одеваемся тепло!"
        case 0..<10:  return "Не забудьте куртку"
        case 10..<18: return "Лёгкий слой"
        default:      return "Легко и комфортно"
        }
    }

    private func rowAccent(_ index: Int) -> Color {
        let palette: [Color] = [.blue, .teal, .green, .orange, .purple, .pink, .indigo, .cyan]
        return palette[index % palette.count]
    }

    private func itemsWord(_ n: Int) -> String {
        let mod10 = n % 10, mod100 = n % 100
        if mod100 >= 11 && mod100 <= 19 { return "вещей" }
        switch mod10 {
        case 1: return "вещь"
        case 2, 3, 4: return "вещи"
        default: return "вещей"
        }
    }
}
