import Foundation

enum LoopedEnvironment {
    static let defaultAPIBaseURL = URL(string: "https://api.mylooped.app")!

    static func apiBaseURL(override: String? = nil) -> URL {
        let rawValue = override ?? (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)
        let trimmed = (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultAPIBaseURL }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        if let url = URL(string: "https://\(trimmed)"), url.scheme != nil {
            return url
        }

        #if DEBUG
        print("Invalid API_BASE_URL='\(trimmed)'; falling back to \(defaultAPIBaseURL.absoluteString).")
        #endif

        return defaultAPIBaseURL
    }
}

