import Foundation

final class NotificationCacheStore {
    private let storageKey = "cachedNotifications"
    private let storage: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let maxCached: Int

    init(storage: UserDefaults = .standard, maxCached: Int = 200) {
        self.storage = storage
        self.maxCached = maxCached
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load() -> [Notification] {
        guard let data = storage.data(forKey: storageKey) else { return [] }
        do {
            return try decoder.decode([Notification].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ notifications: [Notification]) {
        let trimmed = Array(notifications.prefix(maxCached))
        guard let data = try? encoder.encode(trimmed) else { return }
        storage.set(data, forKey: storageKey)
    }

    func clear() {
        storage.removeObject(forKey: storageKey)
    }
}

