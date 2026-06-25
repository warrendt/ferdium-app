import SwiftUI
import WebKit

/// SwiftUI wrapper that hosts the React renderer in a single `WKWebView`.
///
/// The renderer bundle is the esbuild output (`build/index.html` and assets from
/// `src/`), copied into the app bundle at build time (see `ipados/README.md`).
/// This is the iPadOS analogue of the Electron `BrowserWindow` that loads
/// `file://.../index.html` in `src/index.ts`.
struct HostWebView: UIViewRepresentable {
    let bridge: PlatformBridge

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // The host renderer shares the default data store; per-service isolation
        // is handled separately in `ServiceWebViewManager`.
        let controller = WKUserContentController()

        // Register the message handler that the renderer uses to reach native
        // code. JS calls `window.webkit.messageHandlers.ferdium.postMessage(...)`.
        controller.add(bridge, name: PlatformBridge.handlerName)

        // Inject the bridge shim that exposes `window.ferdiumNative` to the
        // renderer at document start, before any app code runs.
        if let shim = BridgeScripts.hostShim() {
            controller.addUserScript(
                WKUserScript(source: shim, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            )
        }

        configuration.userContentController = controller
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = false
        webView.isInspectable = true
        bridge.hostWebView = webView

        loadRenderer(into: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    /// Loads the bundled renderer entry point.
    private func loadRenderer(into webView: WKWebView) {
        guard let indexURL = Bundle.main.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "renderer"
        ) else {
            assertionFailure("Renderer bundle missing: run `pnpm build` and copy ./build into ipados resources")
            return
        }
        let readAccess = indexURL.deletingLastPathComponent()
        webView.loadFileURL(indexURL, allowingReadAccessTo: readAccess)
    }
}
