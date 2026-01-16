import Foundation

struct StorageSnapshot: Equatable {
    let documentsBytes: Int64
    let cachesBytes: Int64
    let tmpBytes: Int64
    let urlCacheDiskBytes: Int
    let urlCacheMemoryBytes: Int
    let collectedAt: Date
}

enum StorageDiagnostics {
    static func snapshot() async -> StorageSnapshot {
        await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            let tmp = fileManager.temporaryDirectory

            return StorageSnapshot(
                documentsBytes: documents.map(directorySizeBytes(at:)) ?? 0,
                cachesBytes: caches.map(directorySizeBytes(at:)) ?? 0,
                tmpBytes: directorySizeBytes(at: tmp),
                urlCacheDiskBytes: URLCache.shared.currentDiskUsage,
                urlCacheMemoryBytes: URLCache.shared.currentMemoryUsage,
                collectedAt: Date()
            )
        }.value
    }

    static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private static func directorySizeBytes(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }
            guard values.isRegularFile == true else { continue }

            if let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize {
                total += Int64(size)
            }
        }

        return total
    }
}

