import Foundation

// MARK: - Outfit feedback

enum UserFeedback: Codable, Equatable, Sendable {
    case tooCold
    case comfortable
    case tooWarm
}
