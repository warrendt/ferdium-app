import Foundation
import WebKit

/// Receives messages from a single service `WKWebView` and routes them to native
/// subsystems. This is the WebKit replacement for the `ipcRenderer.sendToHost`
/// channel that recipes use in the Electron preload (`src/webview/recipe.ts`).
///
/// It also acts as the navigation/UI/download delegate for the service surface.
final class ServiceMessageHandler: NSObject {
    let serviceId: String
    weak var manager: ServiceWebViewManager?

    init(serviceId: String, manager: ServiceWebViewManager) {
        self.serviceId = serviceId
        self.manager = manager
    }
}

// MARK: - WKScriptMessageHandler

extension ServiceMessageHandler: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        let payload = body["payload"] as? [String: Any] ?? [:]

        switch type {
        case "notification":
            // Recipe notification -> UNUserNotificationCenter.
            manager?.notificationBridge?.present(
                serviceId: serviceId,
                title: payload["title"] as? String ?? "",
                body: (payload["options"] as? [String: Any])?["body"] as? String,
                notificationId: payload["notificationId"] as? String
            )
        case "badge":
            manager?.reportUnread(
                serviceId: serviceId,
                direct: payload["direct"] as? Int ?? 0,
                indirect: payload["indirect"] as? Int ?? 0
            )
        case "dialog-title":
            AppModel.shared.hostBridge.dispatchToRenderer(
                event: "service-dialog-title",
                payload: ["serviceId": serviceId, "title": payload["title"] as Any]
            )
        default:
            break
        }
    }
}

// MARK: - WKNavigationDelegate / WKUIDelegate

extension ServiceMessageHandler: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        AppModel.shared.hostBridge.dispatchToRenderer(
            event: "service-did-navigate",
            payload: ["serviceId": serviceId, "url": webView.url?.absoluteString as Any]
        )
    }

    /// `window.open`/popups: load externally rather than spawning a window, the
    /// iPadOS counterpart of the Electron `setWindowOpenHandler` logic.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url, navigationAction.targetFrame == nil {
            UIApplication.shared.open(url)
        }
        return nil
    }

    /// Routes downloads to the download bridge (`WKDownloadDelegate`).
    func webView(
        _ webView: WKWebView,
        navigationResponse: WKNavigationResponse,
        didBecome download: WKDownload
    ) {
        download.delegate = DownloadBridge.shared
    }
}
