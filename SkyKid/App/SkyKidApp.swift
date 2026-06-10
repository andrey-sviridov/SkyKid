import SwiftUI
import UIKit

@main
struct SkyKidApp: App {

    init() {
        // Явно разрешаем автогашение экрана — ни одна часть приложения не должна его блокировать.
        UIApplication.shared.isIdleTimerDisabled = false
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
