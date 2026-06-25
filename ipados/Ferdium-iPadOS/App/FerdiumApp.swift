import SwiftUI

/// Entry point for the Ferdium iPadOS application.
///
/// Strategy A (see `ipados/README.md`): a thin native Swift shell that hosts the
/// existing React/MobX renderer in a single host `WKWebView` and renders every
/// messaging service inside its own isolated `WKWebView`. The native side supplies
/// the capabilities that Electron used to provide (notifications, downloads,
/// session isolation, deep links, local persistence).
@main
struct FerdiumApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Shared coordinator that owns the host bridge and the per-service WebViews.
    @StateObject private var appModel = AppModel.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .ignoresSafeArea()
                .onOpenURL { url in
                    // iOS URL scheme + Universal Links replacement for the
                    // Electron `ferdium:` deep-link handler.
                    appModel.handleDeepLink(url)
                }
        }
    }
}

/// Top-level observable owning the renderer host and service registry.
///
/// This is the iPadOS analogue of the Electron main process in `src/index.ts`.
final class AppModel: ObservableObject {
    static let shared = AppModel()

    let hostBridge = PlatformBridge()
    let serviceManager = ServiceWebViewManager()
    let notificationBridge = NotificationBridge()
    let localStore = LocalStore()

    private init() {
        hostBridge.serviceManager = serviceManager
        hostBridge.notificationBridge = notificationBridge
        hostBridge.localStore = localStore
        serviceManager.notificationBridge = notificationBridge
    }

    /// Routes a deep link (e.g. `ferdium://service/<id>`) into the renderer.
    func handleDeepLink(_ url: URL) {
        hostBridge.dispatchToRenderer(event: "deep-link", payload: ["url": url.absoluteString])
    }
}
