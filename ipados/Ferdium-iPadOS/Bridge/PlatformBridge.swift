import Foundation
import WebKit

/// Native side of the renderer ⇄ shell contract.
///
/// The host renderer reaches native code through a single message handler
/// (`window.webkit.messageHandlers.ferdium`). Native code calls back into the
/// renderer by evaluating a dispatch into `window.ferdiumNative.__receive(...)`.
/// This is the WebKit replacement for the Electron `ipc-api` modules under
/// `src/electron/ipc-api`.
final class PlatformBridge: NSObject, ObservableObject {
    /// Name shared by the host and every service content controller.
    static let handlerName = "ferdium"

    weak var hostWebView: WKWebView?
    weak var serviceManager: ServiceWebViewManager?
    weak var notificationBridge: NotificationBridge?
    var localStore: LocalStore?

    /// Sends an event to the renderer's bridge listener.
    func dispatchToRenderer(event: String, payload: [String: Any]) {
        guard let hostWebView else { return }
        let envelope: [String: Any] = ["event": event, "payload": payload]
        guard let data = try? JSONSerialization.data(withJSONObject: envelope),
              let json = String(data: data, encoding: .utf8) else { return }
        let js = "window.ferdiumNative && window.ferdiumNative.__receive(\(json));"
        DispatchQueue.main.async {
            hostWebView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}

// MARK: - WKScriptMessageHandler (renderer -> native)

extension PlatformBridge: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let command = body["command"] as? String else { return }
        let payload = body["payload"] as? [String: Any] ?? [:]
        let requestId = body["requestId"] as? String

        switch command {
        case "service.create":
            serviceManager?.webView(for: ServiceDescriptor(json: payload))
        case "service.activate":
            serviceManager?.setActive(serviceId: payload["serviceId"] as? String)
        case "service.remove":
            if let id = payload["serviceId"] as? String {
                serviceManager?.remove(serviceId: id)
            }
        case "local.get":
            let value = localStore?.get(key: payload["key"] as? String ?? "")
            reply(requestId: requestId, payload: ["value": value as Any])
        case "local.set":
            localStore?.set(key: payload["key"] as? String ?? "", value: payload["value"])
            reply(requestId: requestId, payload: [:])
        case "notification.requestPermission":
            notificationBridge?.requestAuthorization()
        default:
            break
        }
    }

    /// Resolves a renderer promise keyed by `requestId`.
    private func reply(requestId: String?, payload: [String: Any]) {
        guard let requestId else { return }
        dispatchToRenderer(event: "reply:\(requestId)", payload: payload)
    }
}
