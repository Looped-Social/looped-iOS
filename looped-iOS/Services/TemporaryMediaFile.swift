import Foundation

enum TemporaryMediaFile {
    static let ownedPrefix = "looped-media-"
    private static let tempFileKeys: [URLResourceKey] = [
        .contentModificationDateKey,
        .isRegularFileKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey,
        .fileSizeKey
    ]

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
        cleanupTemporaryDirectory(olderThan: age, includeUnowned: false)
    }

    /// Cleans up files within the app's temp directory. Prefer using a non-zero `olderThan` to avoid deleting in-flight files.
    static func cleanupTemporaryDirectory(olderThan age: TimeInterval, includeUnowned: Bool) {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
        let cutoff = Date().addingTimeInterval(-age)

        let keys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return }

        var urlsToDelete: [URL] = []
        for case let url as URL in enumerator {
            if !includeUnowned, !isOwned(url) { continue }
            let values = try? url.resourceValues(forKeys: Set(keys))
            let modifiedAt = values?.contentModificationDate
            if let modifiedAt, modifiedAt > cutoff { continue }
            urlsToDelete.append(url)
            if values?.isDirectory == true {
                enumerator.skipDescendants()
            }
        }

        // Delete deeper paths first.
        urlsToDelete.sort { $0.path.count > $1.path.count }
        for url in urlsToDelete {
            try? fileManager.removeItem(at: url)
        }
    }

    /// Enforces a soft size cap for the app's temporary directory by deleting the oldest eligible files.
    /// - Parameters:
    ///   - maxBytes: Target maximum total bytes for tmp/.
    ///   - minimumAge: Only delete files older than this (safety window for in-flight uploads/transcodes).
    ///   - includeUnowned: If true, also considers non-`looped-media-*` files under tmp/.
    static func enforceTemporaryDirectoryBudget(
        maxBytes: Int64,
        minimumAge: TimeInterval,
        includeUnowned: Bool
    ) {
        guard maxBytes > 0 else { return }
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
        let cutoff = Date().addingTimeInterval(-minimumAge)

        struct Candidate {
            let url: URL
            let modifiedAt: Date
            let size: Int64
        }

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: tempFileKeys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return }

        var total: Int64 = 0
        var candidates: [Candidate] = []

        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: Set(tempFileKeys))
            guard values?.isRegularFile == true else { continue }

            let sizeInt = values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? values?.fileSize ?? 0
            let size = Int64(sizeInt)
            total += size

            if !includeUnowned, !isOwned(url) { continue }
            guard let modifiedAt = values?.contentModificationDate else { continue }
            guard modifiedAt <= cutoff else { continue }

            candidates.append(Candidate(url: url, modifiedAt: modifiedAt, size: size))
        }

        guard total > maxBytes else { return }
        guard !candidates.isEmpty else { return }

        // Oldest first.
        candidates.sort { $0.modifiedAt < $1.modifiedAt }
        for candidate in candidates {
            guard total > maxBytes else { break }
            try? fileManager.removeItem(at: candidate.url)
            total -= candidate.size
        }
    }
}
