import SwiftUI
import WebKit

/// Displays the active service's `WKWebView`, swapping surfaces as the renderer
/// changes `activeServiceId`. Inactive services stay alive (warm) but hidden,
/// matching the Electron behaviour where background `<webview>`s keep running.
struct ServiceContainerView: UIViewRepresentable {
    @ObservedObject var manager: ServiceWebViewManager

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        // Ensure every known service has a child view, toggling visibility so
        // only the active one is shown.
        for (id, webView) in manager.webViews {
            if webView.superview !== container {
                webView.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(webView)
                NSLayoutConstraint.activate([
                    webView.topAnchor.constraint(equalTo: container.topAnchor),
                    webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                ])
            }
            webView.isHidden = (id != manager.activeServiceId)
        }

        // Remove orphaned subviews for services that were torn down.
        for subview in container.subviews {
            guard let webView = subview as? WKWebView else { continue }
            let stillTracked = manager.webViews.values.contains(webView)
            if !stillTracked {
                webView.removeFromSuperview()
            }
        }

        // When no service is active, let the host renderer show through.
        container.isHidden = manager.activeServiceId == nil
    }
}
