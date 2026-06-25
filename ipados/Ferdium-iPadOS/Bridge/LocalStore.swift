import Foundation

/// Minimal on-device persistence that replaces the embedded AdonisJS server
/// (`src/internal-server`) used by the desktop `LocalApi`.
///
/// iPadOS forbids a Node runtime, so the local-first data the renderer expects is
/// served from native storage instead. This implementation is a JSON-backed
/// key/value store; the renderer's `LocalApi` contract (services, workspaces,
/// settings) is mapped onto namespaced keys. It can later be swapped for Core
/// Data / GRDB-backed SQLite without changing the bridge contract.
final class LocalStore {
    private let queue = DispatchQueue(label: "org.ferdium.localstore")
    private var cache: [String: Any] = [:]
    private let fileURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Ferdium", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("local-store.json")
        load()
    }

    func get(key: String) -> Any? {
        queue.sync { cache[key] }
    }

    func set(key: String, value: Any?) {
        queue.sync {
            if let value {
                cache[key] = value
            } else {
                cache.removeValue(forKey: key)
            }
            persist()
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        cache = json
    }

    private func persist() {
        guard let data = try? JSONSerialization.data(withJSONObject: cache, options: [.prettyPrinted]) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
