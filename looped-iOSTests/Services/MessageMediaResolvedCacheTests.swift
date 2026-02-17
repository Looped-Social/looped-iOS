import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
struct MessageMediaResolvedCacheTests {

    @Test
    func getValid_returnsOnlyUnexpiredEntries() async {
        let cache = MessageMediaResolvedCache(maxEntries: 10, expiryLeeway: 20)
        let now = Date()

        await cache.store([
            MessageMediaResolvedItem(
                key: "fresh",
                downloadUrl: "https://cdn/fresh",
                mimeType: "image/jpeg",
                expiresAt: now.addingTimeInterval(120)
            ),
            MessageMediaResolvedItem(
                key: "stale",
                downloadUrl: "https://cdn/stale",
                mimeType: "image/jpeg",
                expiresAt: now.addingTimeInterval(5)
            )
        ])

        let resolved = await cache.getValid(for: ["fresh", "stale", "missing"])

        #expect(resolved.keys.sorted() == ["fresh"])
        #expect(resolved["fresh"]?.downloadUrl == "https://cdn/fresh")
    }

    @Test
    func pruneIfNeeded_evictsLeastRecentlyUsedWhenOverCapacity() async {
        let cache = MessageMediaResolvedCache(maxEntries: 2, expiryLeeway: 0)
        let future = Date().addingTimeInterval(600)

        await cache.store([
            MessageMediaResolvedItem(key: "k1", downloadUrl: "https://cdn/1", mimeType: nil, expiresAt: future),
            MessageMediaResolvedItem(key: "k2", downloadUrl: "https://cdn/2", mimeType: nil, expiresAt: future)
        ])

        _ = await cache.getValid(for: ["k1"])
        try? await Task.sleep(nanoseconds: 20_000_000)

        await cache.store([
            MessageMediaResolvedItem(key: "k3", downloadUrl: "https://cdn/3", mimeType: nil, expiresAt: future)
        ])

        let resolved = await cache.getValid(for: ["k1", "k2", "k3"])

        #expect(resolved.keys.contains("k1"))
        #expect(resolved.keys.contains("k3"))
        #expect(resolved.keys.contains("k2") == false)
    }

    @Test
    func removeAll_clearsCache() async {
        let cache = MessageMediaResolvedCache(maxEntries: 4, expiryLeeway: 0)
        await cache.store([
            MessageMediaResolvedItem(key: "k1", downloadUrl: "https://cdn/1", mimeType: nil, expiresAt: Date().addingTimeInterval(120))
        ])

        await cache.removeAll()
        let resolved = await cache.getValid(for: ["k1"])

        #expect(resolved.isEmpty)
    }
}
