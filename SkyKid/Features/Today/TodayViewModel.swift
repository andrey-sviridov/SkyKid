import Foundation
import Observation

// MARK: - TodayViewModel

@MainActor
@Observable
final class TodayViewModel {
    enum ContentState: Equatable {
        case loading
        case unavailable(message: String)
        case stale
        case blocked(SafetyWarning)
        case ready
    }

    private(set) var state: ContentState = .loading

    func update(
        isLoading: Bool,
        error: String?,
        weather: NormalizedWeather?,
        weatherUpdatedAt: Date?,
        recommendation: OutfitRecommendation?,
        now: Date = .now
    ) {
        if isLoading, weather == nil {
            state = .loading
            return
        }
        guard weather != nil else {
            state = .unavailable(message: error ?? L10n.text("Нет данных"))
            return
        }
        guard RecommendationFreshnessPolicy(now: now).state(for: weatherUpdatedAt) == .fresh else {
            state = .stale
            return
        }
        if let warning = recommendation?.blockingWarning {
            state = .blocked(warning)
            return
        }
        guard recommendation != nil else {
            state = isLoading
                ? .loading
                : .unavailable(
                    message: error ?? L10n.text("Рекомендация временно недоступна")
                )
            return
        }
        state = .ready
    }
}
