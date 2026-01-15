import Foundation

enum CacheHousekeeper {
    private static let lastRunKey = "looped.cache_housekeeper.last_run"

    static func configureCacheLimits(
        memoryBytes: Int = 30 * 1024 * 1024,
        diskBytes: Int = 150 * 1024 * 1024
    ) {
        URLCache.shared.memoryCapacity = memoryBytes
        URLCache.shared.diskCapacity = diskBytes
    }

    /// Runs lightweight cleanup at most once per 12 hours.
    static func runIfNeeded() {
        let now = Date()
        let lastRun = UserDefaults.standard.object(forKey: lastRunKey) as? Date ?? .distantPast
        guard now.timeIntervalSince(lastRun) > 12 * 60 * 60 else { return }
        UserDefaults.standard.set(now, forKey: lastRunKey)

        TemporaryMediaFile.cleanupOrphanedFiles(olderThan: 24 * 60 * 60)

        // Avoid long-lived on-disk media cache growth; keep "recent" media hot.
        let keepSince = now.addingTimeInterval(-7 * 24 * 60 * 60)
        URLCache.shared.removeCachedResponses(since: keepSince)
    }
}

