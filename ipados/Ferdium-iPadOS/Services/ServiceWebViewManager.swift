import Foundation
import WebKit

/// Owns one `WKWebView` per active service, providing the session isolation that
/// Electron achieved with `<webview partition="...">` in `ServiceWebview.tsx`.
///
/// Each distinct `partition` string maps to its own `WKWebsiteDataStore`, so
/// cookies, localStorage and caches never leak between services (and the
/// `persist:sandbox-*` partitions used by the sandbox feature are honoured too).
final class ServiceWebViewManager: NSObject, ObservableObject {
    weak var notificationBridge: NotificationBridge?

    /// Active service surfaces keyed by service id.
    @Published private(set) var webViews: [String: WKWebView] = [:]

    /// The id of the service currently shown on top.
    @Published var activeServiceId: String?

    /// Persistent data stores keyed by partition string. iPadOS only supports a
    /// single default persistent store, so named partitions use *non-persistent*
    /// stores that we keep alive for the app's lifetime to emulate Electron's
    /// `persist:` partitions. The shared `persist:general-session` reuses the
    /// system default store.
    private var dataStores: [String: WKWebsiteDataStore] = [:]

    /// Creates (or reuses) the isolated `WKWebView` for a service.
    ///
    /// - Parameters:
    ///   - service: descriptor mirroring the fields read by `ServiceWebview.tsx`.
    @discardableResult
    func webView(for service: ServiceDescriptor) -> WKWebView {
        if let existing = webViews[service.id] {
            return existing
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore(for: service.partition)
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        if let userAgent = service.userAgent, !userAgent.isEmpty {
            configuration.applicationNameForUserAgent = userAgent
        }

        let controller = WKUserContentController()
        // Recipe events (unread counts, notifications, dialog titles) flow back to
        // native through this handler, replacing Electron's `ipcRenderer.sendToHost`.
        let handler = ServiceMessageHandler(serviceId: service.id, manager: self)
        controller.add(handler, name: PlatformBridge.handlerName)

        // Inject the recipe bridge (notification monkey-patch + unread scraping
        // glue) at document start, the WebKit equivalent of the Electron
        // `preload` script `recipe.js`.
        if let recipeBridge = BridgeScripts.recipeBridge(serviceId: service.id) {
            controller.addUserScript(
                WKUserScript(source: recipeBridge, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            )
        }
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = service.userAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = handler
        webView.uiDelegate = handler

        if let url = URL(string: service.url) {
            webView.load(URLRequest(url: url))
        }

        webViews[service.id] = webView
        return webView
    }

    /// Removes a service surface and tears down its observers. The data store is
    /// retained so a re-added service keeps its session.
    func remove(serviceId: String) {
        webViews[serviceId]?.stopLoading()
        webViews[serviceId] = nil
        if activeServiceId == serviceId {
            activeServiceId = nil
        }
    }

    func setActive(serviceId: String?) {
        activeServiceId = serviceId
    }

    /// Forwards an unread/badge update from a service to the host renderer so the
    /// existing `ServicesStore` badge logic stays the source of truth.
    func reportUnread(serviceId: String, direct: Int, indirect: Int) {
        AppModel.shared.hostBridge.dispatchToRenderer(
            event: "service-unread",
            payload: ["serviceId": serviceId, "direct": direct, "indirect": indirect]
        )
    }

    private func dataStore(for partition: String?) -> WKWebsiteDataStore {
        guard let partition, partition != "persist:general-session" else {
            return .default()
        }
        if let store = dataStores[partition] {
            return store
        }
        // Named partitions map to dedicated non-persistent stores held for the
        // app's lifetime, giving each service/sandbox an isolated cookie jar.
        let store = WKWebsiteDataStore.nonPersistent()
        dataStores[partition] = store
        return store
    }
}

/// Plain descriptor passed from the renderer when it asks native code to create
/// a service surface. Mirrors the relevant fields of `models/Service`.
struct ServiceDescriptor {
    let id: String
    let url: String
    let partition: String?
    let userAgent: String?

    init(json: [String: Any]) {
        id = json["id"] as? String ?? UUID().uuidString
        url = json["url"] as? String ?? "about:blank"
        partition = json["partition"] as? String
        userAgent = json["userAgent"] as? String
    }
}
