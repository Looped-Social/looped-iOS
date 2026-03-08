import Foundation

struct SharedPostPrefill: Codable, Equatable {
    let composedText: String
    let createdAt: Date
}

enum SharedPostPrefillStore {
    static let pendingPayloadDefaultsKey = "com.mylooped.looped.share.pending_post_prefill_v1"
    private static let maxPayloadAge: TimeInterval = 60 * 60 * 12
    private static let knownAppGroupSuiteNames: [String] = [
        "group.com.mylooped.looped",
        "group.com.mylooped.looped.staging"
    ]

    static func loadComposedText() -> String? {
        for defaults in sharedDefaultsCandidates() {
            guard let data = defaults.data(forKey: pendingPayloadDefaultsKey) else { continue }

            guard let payload = try? JSONDecoder().decode(SharedPostPrefill.self, from: data) else {
                defaults.removeObject(forKey: pendingPayloadDefaultsKey)
                continue
            }
            guard Date().timeIntervalSince(payload.createdAt) <= maxPayloadAge else {
                defaults.removeObject(forKey: pendingPayloadDefaultsKey)
                continue
            }

            let trimmed = payload.composedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                defaults.removeObject(forKey: pendingPayloadDefaultsKey)
                continue
            }
            return payload.composedText
        }
        return nil
    }

    static func consumeComposedText() -> String? {
        let text = loadComposedText()
        if text != nil {
            clearPending()
        }
        return text
    }

    static func clearPending() {
        for defaults in sharedDefaultsCandidates() {
            defaults.removeObject(forKey: pendingPayloadDefaultsKey)
        }
    }

    private static func sharedDefaultsCandidates() -> [UserDefaults] {
        var suiteNames: [String] = []
        if let derived = appGroupSuiteName() {
            suiteNames.append(derived)
        }
        for known in knownAppGroupSuiteNames where !suiteNames.contains(known) {
            suiteNames.append(known)
        }

        var results: [UserDefaults] = []
        for suiteName in suiteNames {
            guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) != nil else {
                continue
            }
            if let defaults = UserDefaults(suiteName: suiteName) {
                results.append(defaults)
            }
        }

        // Final fallback for in-process debugging scenarios.
        results.append(.standard)
        return results
    }

    private static func appGroupSuiteName() -> String? {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return nil }
        let normalized = normalizeBundleIdentifier(bundleIdentifier)
        guard !normalized.isEmpty else { return nil }
        return "group.\(normalized)"
    }

    private static func normalizeBundleIdentifier(_ bundleIdentifier: String) -> String {
        if bundleIdentifier.hasSuffix(".widgets") {
            return String(bundleIdentifier.dropLast(".widgets".count))
        }
        if bundleIdentifier.hasSuffix(".share-extenstion") {
            return String(bundleIdentifier.dropLast(".share-extenstion".count))
        }
        if bundleIdentifier.hasSuffix(".share") {
            return String(bundleIdentifier.dropLast(".share".count))
        }
        return bundleIdentifier
    }
}
