import Foundation
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

final class NotificationCacheStore {
    private let legacyStorageKey = "cachedNotifications"
    private let scopedStorageKeyPrefix = "cachedNotifications.user."
    private let storage: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let maxCached: Int
    private var activeUserId: String?

    init(storage: UserDefaults = .standard, maxCached: Int = 200) {
        self.storage = storage
        self.maxCached = maxCached
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        self.activeUserId = Self.currentAuthUserId()
        clearLegacyGlobalScope()
    }

    func load() -> [Notification] {
        guard let key = activeStorageKey else { return [] }
        guard let data = storage.data(forKey: key) else { return [] }
        do {
            return try decoder.decode([Notification].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ notifications: [Notification]) {
        guard let key = activeStorageKey else { return }
        let trimmed = Array(notifications.prefix(maxCached))
        guard let data = try? encoder.encode(trimmed) else { return }
        storage.set(data, forKey: key)
    }

    func clear() {
        guard let key = activeStorageKey else { return }
        storage.removeObject(forKey: key)
    }

    @discardableResult
    func syncActiveUserWithAuth() -> Bool {
        let newUserId = Self.currentAuthUserId()
        let didChange = newUserId != activeUserId
        activeUserId = newUserId
        clearLegacyGlobalScope()
        return didChange
    }

    private var activeStorageKey: String? {
        let trimmed = (activeUserId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return scopedStorageKeyPrefix + trimmed
    }

    private func clearLegacyGlobalScope() {
        storage.removeObject(forKey: legacyStorageKey)
    }

    private static func currentAuthUserId() -> String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }
}
