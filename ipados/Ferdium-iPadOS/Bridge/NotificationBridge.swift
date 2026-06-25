import Foundation
import UserNotifications

/// Bridges recipe/web notifications to `UNUserNotificationCenter`.
///
/// The verified Ferdium design intercepts `window.Notification` and
/// `ServiceWorkerRegistration.showNotification` inside each service (see
/// `src/webview/notifications.ts`). On iPadOS those intercepted payloads are
/// posted to native code and surfaced as real iOS notifications, which keeps
/// them working while the app is backgrounded under iOS rules.
final class NotificationBridge: NSObject, UNUserNotificationCenterDelegate {
    /// Maps a delivered notification's identifier to the service that raised it,
    /// so a tap can be routed back to the correct surface.
    private var serviceByNotificationId: [String: String] = [:]

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { _, error in
            if let error {
                NSLog("Ferdium: notification authorization failed: \(error)")
            }
        }
    }

    /// Presents a notification raised by a service recipe.
    func present(serviceId: String, title: String, body: String?, notificationId: String?) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let body { content.body = body }
        content.sound = .default
        content.userInfo = ["serviceId": serviceId, "notificationId": notificationId ?? ""]

        let identifier = notificationId ?? UUID().uuidString
        serviceByNotificationId[identifier] = serviceId

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Show banners even while the app is in the foreground (the renderer decides
    /// muting/DND, mirroring the desktop behaviour).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// On tap, activate the originating service and forward the click into the
    /// service surface so the recipe's `onclick` handler runs.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        if let serviceId = info["serviceId"] as? String {
            AppModel.shared.serviceManager.setActive(serviceId: serviceId)
            let notificationId = info["notificationId"] as? String ?? ""
            let js = "window.ferdiumRecipe && window.ferdiumRecipe.__onNotificationClick(\"\(notificationId)\");"
            AppModel.shared.serviceManager.webViews[serviceId]?
                .evaluateJavaScript(js, completionHandler: nil)
        }
        completionHandler()
    }
}
