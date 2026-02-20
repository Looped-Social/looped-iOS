import Foundation

extension URL {
    private static let allowedRemoteSchemes: Set<String> = ["http", "https"]

    /// Resolves a string into a URL suitable for loading remote media.
    ///
    /// Supports:
    /// - Absolute URLs (https://...)
    /// - Host/path without scheme (cdn.example.com/image.png)
    /// - Paths relative to `API_BASE_URL` (/media/image.png, media/image.png, image.png)
    static func loopedMediaURL(from rawValue: String?) -> URL? {
        let trimmed = (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let absolute = URL(string: trimmed),
           let scheme = absolute.scheme?.lowercased(),
           allowedRemoteSchemes.contains(scheme) {
            return absolute
        }

        if trimmed.hasPrefix("//") {
            return URL(string: "https:\(trimmed)")
        }

        if trimmed.hasPrefix("www.") {
            return URL(string: "https://\(trimmed)")
        }

        let firstComponent = trimmed.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? trimmed
        if firstComponent.contains("."), !trimmed.hasPrefix("/") {
            let lowercased = firstComponent.lowercased()
            let looksLikeFilename = [".png", ".jpg", ".jpeg", ".webp", ".gif", ".heic"].contains { lowercased.hasSuffix($0) }
            if !looksLikeFilename {
                return URL(string: "https://\(trimmed)")
            }
        }

        guard let relative = URL(string: trimmed, relativeTo: LoopedEnvironment.apiBaseURL()) else {
            return nil
        }
        guard let scheme = relative.scheme?.lowercased(), allowedRemoteSchemes.contains(scheme) else {
            return nil
        }
        return relative
    }
}
