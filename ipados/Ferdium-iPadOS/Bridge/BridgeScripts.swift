import Foundation

/// Loads the JavaScript bridge shims that are injected into the host and service
/// `WKWebView`s. Keeping the JS in resource files (rather than Swift string
/// literals) lets the same code be unit-tested and shared with the renderer build.
enum BridgeScripts {
    /// Host shim exposing `window.ferdiumNative` to the React renderer.
    static func hostShim() -> String? {
        load("platform-bridge")
    }

    /// Per-service recipe bridge: notification monkey-patch + unread scraping glue.
    /// The `serviceId` is interpolated so messages are attributed correctly.
    static func recipeBridge(serviceId: String) -> String? {
        guard let template = load("recipe-bridge") else { return nil }
        return template.replacingOccurrences(of: "__SERVICE_ID__", with: serviceId)
    }

    private static func load(_ name: String) -> String? {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "js",
            subdirectory: "bridge"
        ), let source = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing bridge script: \(name).js")
            return nil
        }
        return source
    }
}
