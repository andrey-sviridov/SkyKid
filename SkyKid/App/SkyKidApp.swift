import SwiftUI
import UserNotifications

@main
struct SkyKidApp: App {

    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}

struct AppRootView: View {
    @State private var isLaunchOverlayVisible = true
    @State private var hasReachedMinimumDisplayTime = false
    @State private var isStartupContentReady = false

    var body: some View {
        ZStack {
            ContentView(onStartupReady: handleStartupReady)

            if isLaunchOverlayVisible {
                AppLaunchOverlayView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(900))
            hasReachedMinimumDisplayTime = true
            dismissLaunchOverlayIfPossible()
        }
        .task {
            try? await Task.sleep(for: .seconds(8))
            guard isLaunchOverlayVisible else { return }
            dismissLaunchOverlay()
        }
    }

    @MainActor
    private func handleStartupReady() {
        guard !isStartupContentReady else { return }
        isStartupContentReady = true
        dismissLaunchOverlayIfPossible()
    }

    @MainActor
    private func dismissLaunchOverlayIfPossible() {
        guard hasReachedMinimumDisplayTime, isStartupContentReady else { return }
        dismissLaunchOverlay()
    }

    @MainActor
    private func dismissLaunchOverlay() {
        guard isLaunchOverlayVisible else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            isLaunchOverlayVisible = false
        }
    }
}

private struct AppLaunchOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isContentVisible = false

    private let branding = AppBranding.current

    var body: some View {
        ZStack {
            SkyKidTheme.background(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(branding.launchIconAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 116, height: 116)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.12), radius: 20, y: 10)

                Text(branding.displayName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(colorScheme == .dark ? .white : Color(red: 0.10, green: 0.18, blue: 0.32))
            }
            .opacity(isContentVisible ? 1 : 0)
            .scaleEffect(isContentVisible ? 1 : 0.94)
            .offset(y: isContentVisible ? 0 : 8)
        }
        .task {
            withAnimation(.easeOut(duration: 0.45)) {
                isContentVisible = true
            }
        }
        .accessibilityHidden(true)
    }
}

private struct AppBranding {
    let displayName: String
    let launchIconAssetName: String

    static let current = AppBranding(
        displayName: "SKY KID",
        launchIconAssetName: "launch_brand_icon"
    )
}

// Разрешает показ уведомлений баннером даже когда приложение открыто
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound, .badge])
    }
}
