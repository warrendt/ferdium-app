import SwiftUI

/// Root layout for the app.
///
/// The host `WKWebView` (the React renderer: sidebar, settings, workspaces) is
/// always present. The currently active service's `WKWebView` is overlaid in the
/// content area, mirroring how the Electron renderer swaps `<webview>` elements.
/// The host renderer remains responsible for chrome/navigation; native code only
/// positions and isolates the service surfaces.
struct RootView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ZStack {
            // The React UI shell, loaded from the bundled esbuild output.
            HostWebView(bridge: appModel.hostBridge)
                .ignoresSafeArea()

            // The active service surface, positioned by the renderer via the
            // bridge. Hidden until a service is activated.
            ServiceContainerView(manager: appModel.serviceManager)
                .ignoresSafeArea()
        }
    }
}
