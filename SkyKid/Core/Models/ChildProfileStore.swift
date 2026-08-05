import Foundation

// SRP: хранилище профиля вынесено из доменной модели ChildProfile.
// Класс — singleton, используется только в основном таргете (не в виджете).

@Observable
final class ChildProfileStore: @unchecked Sendable {
    static let shared = ChildProfileStore()

    var profile: ChildProfile? {
        get { AppGroup.loadProfile() }
        set {
            if let newValue {
                AppGroup.saveProfile(newValue)
                // ChildProfileStore не @MainActor (см. класс-комментарий),
                // а SupabaseSyncService — @MainActor: явный хоп вместо
                // конструкторской инъекции, иначе `.shared` как default
                // параметра не проходит проверку изоляции Swift 6.
                Task { @MainActor in
                    await SupabaseSyncService.shared.pushProfile(newValue)
                }
            } else {
                AppGroup.deleteProfile()
            }
        }
    }
}
