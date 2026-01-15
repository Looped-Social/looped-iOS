import Foundation

actor MessageMediaResolvedCache {
    private struct Entry {
        let item: MessageMediaResolvedItem
        var lastAccess: Date
    }

    private var entries: [String: Entry] = [:]
    private let maxEntries: Int
    private let expiryLeeway: TimeInterval

    init(maxEntries: Int = 400, expiryLeeway: TimeInterval = 20) {
        self.maxEntries = maxEntries
        self.expiryLeeway = expiryLeeway
    }

    func getValid(for keys: [String]) -> [String: MessageMediaResolvedItem] {
        guard !keys.isEmpty else { return [:] }
        let now = Date()
        var result: [String: MessageMediaResolvedItem] = [:]
        result.reserveCapacity(keys.count)

        for key in keys {
            guard var entry = entries[key] else { continue }
            if entry.item.expiresAt <= now.addingTimeInterval(expiryLeeway) {
                entries.removeValue(forKey: key)
                continue
            }
            entry.lastAccess = now
            entries[key] = entry
            result[key] = entry.item
        }

        pruneIfNeeded(now: now)
        return result
    }

    func store(_ items: [MessageMediaResolvedItem]) {
        guard !items.isEmpty else { return }
        let now = Date()
        for item in items where !item.downloadUrl.isEmpty {
            entries[item.key] = Entry(item: item, lastAccess: now)
        }
        pruneIfNeeded(now: now)
    }

    func removeAll() {
        entries.removeAll()
    }

    private func pruneIfNeeded(now: Date) {
        // Remove expired entries opportunistically.
        let cutoff = now.addingTimeInterval(expiryLeeway)
        entries = entries.filter { $0.value.item.expiresAt > cutoff }

        guard entries.count > maxEntries else { return }
        let overflow = entries.count - maxEntries
        guard overflow > 0 else { return }

        let sorted = entries.sorted { $0.value.lastAccess < $1.value.lastAccess }
        for (key, _) in sorted.prefix(overflow) {
            entries.removeValue(forKey: key)
        }
    }
}

