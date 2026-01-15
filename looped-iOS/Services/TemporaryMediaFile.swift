import Foundation

enum TemporaryMediaFile {
    static let ownedPrefix = "looped-media-"

    static func makeURL(extension ext: String) -> URL {
        let cleaned = ext.trimmingCharacters(in: CharacterSet(charactersIn: ".").union(.whitespacesAndNewlines))
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(ownedPrefix + UUID().uuidString)
            .appendingPathExtension(cleaned.isEmpty ? "tmp" : cleaned)
    }

    static func isOwned(_ url: URL) -> Bool {
        url.deletingLastPathComponent() == FileManager.default.temporaryDirectory
            && url.lastPathComponent.hasPrefix(ownedPrefix)
    }

    static func deleteIfOwned(_ url: URL?) {
        guard let url, isOwned(url) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func cleanupOrphanedFiles(olderThan age: TimeInterval) {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
        let cutoff = Date().addingTimeInterval(-age)

        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in urls where isOwned(url) {
            let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            if let modifiedAt, modifiedAt > cutoff { continue }
            try? fileManager.removeItem(at: url)
        }
    }
}
