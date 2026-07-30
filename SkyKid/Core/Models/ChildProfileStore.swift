import Foundation

// SRP: хранилище профиля вынесено из доменной модели ChildProfile.
// Класс — singleton, используется только в основном таргете (не в виджете).

@Observable
final class ChildProfileStore: @unchecked Sendable {
    static let shared = ChildProfileStore()

    var profile: ChildProfile? {
        get { AppGroup.loadProfile() }
        set {
            if let newValue { AppGroup.saveProfile(newValue) }
            else { AppGroup.deleteProfile() }
        }
    }
}
