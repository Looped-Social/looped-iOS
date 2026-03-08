import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var hasHandledShare = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasHandledShare else { return }
        hasHandledShare = true

        Task { @MainActor in
            await processShare()
        }
    }

    @MainActor
    private func processShare() async {
        guard let payload = await extractPayload() else {
            presentResultAlert(
                title: "Couldn't Save Share",
                message: "Looped couldn't read this share. Please open Looped and paste the link manually."
            )
            return
        }

        guard SharedPostPrefillWriter.save(payload) else {
            presentResultAlert(
                title: "Couldn't Save Share",
                message: "Looped couldn't access shared storage. Please open Looped and paste the link manually."
            )
            return
        }
        presentResultAlert(
            title: "Saved to Looped",
            message: "Your link is ready. Open Looped and tap New Post to finish sharing. The link will be prefilled."
        )
    }

    @MainActor
    private func presentResultAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Done", style: .cancel) { [weak self] _ in
            self?.complete()
        })

        present(alert, animated: true)
    }

    @MainActor
    private func complete() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func extractPayload() async -> SharedPostPrefill? {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }

        var textParts: [String] = []
        var firstURL: URL?

        for extensionItem in extensionItems {
            if let inlineText = extensionItem.attributedContentText?.string.trimmedNonEmpty {
                textParts.append(inlineText)
            }

            guard let attachments = extensionItem.attachments else { continue }
            for itemProvider in attachments {
                if firstURL == nil, let url = await loadURL(from: itemProvider) {
                    firstURL = url
                }

                if let text = await loadText(from: itemProvider) {
                    textParts.append(text)
                }
            }
        }

        let uniqueParts = Array(NSOrderedSet(array: textParts.map { $0.trimmedNonEmpty }.compactMap { $0 })) as? [String] ?? []
        let normalizedURLString = firstURL?.absoluteString.trimmedNonEmpty
        let urlAlreadyIncluded = normalizedURLString.map { url in
            uniqueParts.contains(where: { $0.contains(url) })
        } ?? false

        var composedSegments = uniqueParts
        if let normalizedURLString, !urlAlreadyIncluded {
            composedSegments.append(normalizedURLString)
        }

        let composedText = composedSegments.joined(separator: "\n").trimmedNonEmpty
        guard let composedText else { return nil }

        return SharedPostPrefill(composedText: composedText, createdAt: Date())
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let url = await loadItem(for: UTType.url.identifier, from: provider) as? URL {
            return url
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let urlString = await loadItem(for: UTType.url.identifier, from: provider) as? String,
           let url = URL(string: urlString) {
            return url
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier),
           let text = await loadItem(for: UTType.text.identifier, from: provider) as? String,
           let detectedURL = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
           detectedURL.scheme != nil {
            return detectedURL
        }

        return nil
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
           let text = await loadItem(for: UTType.plainText.identifier, from: provider) as? String,
           let normalized = text.trimmedNonEmpty {
            return normalized
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier),
           let text = await loadItem(for: UTType.text.identifier, from: provider) as? String,
           let normalized = text.trimmedNonEmpty {
            return normalized
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let url = await loadItem(for: UTType.url.identifier, from: provider) as? URL {
            return url.absoluteString
        }

        return nil
    }

    private func loadItem(for typeIdentifier: String, from provider: NSItemProvider) async -> NSSecureCoding? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                continuation.resume(returning: item as? NSSecureCoding)
            }
        }
    }
}

private enum SharedPostPrefillWriter {
    private static let defaultsKey = "com.mylooped.looped.share.pending_post_prefill_v1"
    private static let knownSuiteNames: [String] = [
        "group.com.mylooped.looped",
        "group.com.mylooped.looped.staging"
    ]

    static func save(_ payload: SharedPostPrefill) -> Bool {
        guard let data = try? JSONEncoder().encode(payload) else { return false }
        var wroteAtLeastOne = false
        for suiteName in candidateSuiteNames() {
            guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) != nil else {
                continue
            }
            guard let defaults = UserDefaults(suiteName: suiteName) else { continue }
            defaults.set(data, forKey: defaultsKey)
            defaults.synchronize()
            wroteAtLeastOne = true
        }
        return wroteAtLeastOne
    }

    private static func appGroupSuiteName() -> String? {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return nil }
        let normalized = normalizeBundleIdentifier(bundleIdentifier)
        guard !normalized.isEmpty else { return nil }
        return "group.\(normalized)"
    }

    private static func candidateSuiteNames() -> [String] {
        var suites: [String] = []
        if let derived = appGroupSuiteName() {
            suites.append(derived)
        }
        for known in knownSuiteNames where !suites.contains(known) {
            suites.append(known)
        }
        return suites
    }

    private static func normalizeBundleIdentifier(_ bundleIdentifier: String) -> String {
        if bundleIdentifier.hasSuffix(".share-extension-staging") {
            return String(bundleIdentifier.dropLast(".share-extension-staging".count))
        }
        if bundleIdentifier.hasSuffix(".share-extenstion-staging") {
            return String(bundleIdentifier.dropLast(".share-extenstion-staging".count))
        }
        if bundleIdentifier.hasSuffix(".share-extension") {
            return String(bundleIdentifier.dropLast(".share-extension".count))
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

private struct SharedPostPrefill: Codable {
    let composedText: String
    let createdAt: Date
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
