import Foundation
import LinkPresentation

enum LinkPreviewMetadataError: Error {
    case missingMetadata
    case recentFailure
}

actor LinkPreviewMetadataStore {
    static let shared = LinkPreviewMetadataStore()

    private let cache = NSCache<NSURL, LPLinkMetadata>()
    private var inFlight: [URL: Task<LPLinkMetadata, Error>] = [:]
    private var recentFailures: [URL: Date] = [:]
    private let failureRetryInterval: TimeInterval = 120

    func metadata(for url: URL) async throws -> LPLinkMetadata {
        let normalizedURL = normalize(url)

        if let cached = cache.object(forKey: normalizedURL as NSURL) {
            return cached
        }

        if let failedAt = recentFailures[normalizedURL],
           Date().timeIntervalSince(failedAt) < failureRetryInterval {
            throw LinkPreviewMetadataError.recentFailure
        }

        if let task = inFlight[normalizedURL] {
            return try await task.value
        }

        let task = Task<LPLinkMetadata, Error> {
            try await Self.fetchMetadata(for: normalizedURL)
        }
        inFlight[normalizedURL] = task
        defer { inFlight[normalizedURL] = nil }

        do {
            let metadata = try await task.value
            cache.setObject(metadata, forKey: normalizedURL as NSURL)
            recentFailures[normalizedURL] = nil
            return metadata
        } catch {
            recentFailures[normalizedURL] = Date()
            throw error
        }
    }

    private func normalize(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.fragment = nil
        return components.url ?? url
    }

    private static func fetchMetadata(for url: URL) async throws -> LPLinkMetadata {
        let provider = LPMetadataProvider()
        provider.timeout = 12

        return try await withCheckedThrowingContinuation { continuation in
            provider.startFetchingMetadata(for: url) { metadata, error in
                if let metadata {
                    continuation.resume(returning: metadata)
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(throwing: LinkPreviewMetadataError.missingMetadata)
            }
        }
    }
}
