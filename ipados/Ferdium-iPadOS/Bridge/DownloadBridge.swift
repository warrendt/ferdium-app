import Foundation
import WebKit

/// Handles service downloads via `WKDownloadDelegate`, writing files into the
/// app's Documents directory so they are visible in the Files app. Replaces the
/// Electron `electron-dl` integration (`src/electron/ipc-api/download.ts`).
final class DownloadBridge: NSObject, WKDownloadDelegate {
    static let shared = DownloadBridge()

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeName = suggestedFilename.isEmpty ? UUID().uuidString : suggestedFilename
        var destination = documents.appendingPathComponent(safeName)

        // Avoid clobbering an existing file by suffixing a counter.
        var counter = 1
        let base = destination.deletingPathExtension().lastPathComponent
        let ext = destination.pathExtension
        while FileManager.default.fileExists(atPath: destination.path) {
            let candidate = ext.isEmpty ? "\(base)-\(counter)" : "\(base)-\(counter).\(ext)"
            destination = documents.appendingPathComponent(candidate)
            counter += 1
        }

        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        AppModel.shared.hostBridge.dispatchToRenderer(event: "download-finished", payload: [:])
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        AppModel.shared.hostBridge.dispatchToRenderer(
            event: "download-failed",
            payload: ["error": error.localizedDescription]
        )
    }
}
