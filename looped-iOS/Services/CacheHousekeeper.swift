import Foundation

enum CacheHousekeeper {
    private static let lastRunKey = "looped.cache_housekeeper.last_run"
    private static let lastBudgetCheckKey = "looped.cache_housekeeper.last_tmp_budget_check"
    private static let runLock = NSLock()
    private static var isRunning = false

    static let tmpBudgetBytes: Int64 = 300 * 1024 * 1024
    static let tmpBudgetMinimumAge: TimeInterval = 10 * 60
    static let tmpBudgetCheckInterval: TimeInterval = 30 * 60

    static func configureCacheLimits(
        memoryBytes: Int = 30 * 1024 * 1024,
        diskBytes: Int = 150 * 1024 * 1024
    ) {
        URLCache.shared.memoryCapacity = memoryBytes
        URLCache.shared.diskCapacity = diskBytes

        // If the app previously ran without a cap, the cache can grow very large; proactively trim.
        if URLCache.shared.currentDiskUsage > diskBytes * 2 {
            URLCache.shared.removeAllCachedResponses()
        }
    }

    /// Runs lightweight cleanup at most once per 12 hours.
    static func runIfNeeded() {
        runLock.lock()
        if isRunning {
            runLock.unlock()
            return
        }
        isRunning = true
        runLock.unlock()
        defer {
            runLock.lock()
            isRunning = false
            runLock.unlock()
        }

        // Always enforce tmp budget (lightweight, rate-limited) even if the heavier cleanup is skipped.
        enforceTmpBudgetIfNeeded()

        let now = Date()
        let lastRun = UserDefaults.standard.object(forKey: lastRunKey) as? Date ?? .distantPast
        guard now.timeIntervalSince(lastRun) > 12 * 60 * 60 else { return }
        UserDefaults.standard.set(now, forKey: lastRunKey)

        TemporaryMediaFile.cleanupOrphanedFiles(olderThan: 6 * 60 * 60)
        // Some iOS APIs (e.g. pickers/transcoders) can leave behind large temp files. Prune older temp files too.
        TemporaryMediaFile.cleanupTemporaryDirectory(olderThan: 24 * 60 * 60, includeUnowned: true)

        // Avoid long-lived on-disk media cache growth; keep "recent" media hot.
        let keepSince = now.addingTimeInterval(-3 * 24 * 60 * 60)
        URLCache.shared.removeCachedResponses(since: keepSince)
    }

    /// Enforces a soft cap on tmp/ more frequently than the heavier 12-hour run.
    static func enforceTmpBudgetIfNeeded() {
        let now = Date()
        let lastRun = UserDefaults.standard.object(forKey: lastBudgetCheckKey) as? Date ?? .distantPast
        guard now.timeIntervalSince(lastRun) > tmpBudgetCheckInterval else { return }
        UserDefaults.standard.set(now, forKey: lastBudgetCheckKey)

        TemporaryMediaFile.enforceTemporaryDirectoryBudget(
            maxBytes: tmpBudgetBytes,
            minimumAge: tmpBudgetMinimumAge,
            includeUnowned: true
        )
    }
}
