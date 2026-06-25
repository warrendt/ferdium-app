import UIKit
import UserNotifications

/// Application delegate handling launch, notification permission and URL routing.
///
/// Replaces the desktop-only pieces of the Electron main process: there is no
/// tray, TouchBar, global shortcut or auto-updater on iPadOS (the App Store owns
/// updates), so only notification + lifecycle wiring remains here.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // The notification bridge becomes the UNUserNotificationCenter delegate so
        // taps on a banner can be forwarded back into the originating service.
        UNUserNotificationCenter.current().delegate = AppModel.shared.notificationBridge
        AppModel.shared.notificationBridge.requestAuthorization()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
    }
}
