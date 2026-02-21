import Foundation

enum AppVersionPolicy {
    static func currentAppVersion(bundle: Bundle = .main) -> String {
        (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func shouldPromptForMinimumSupportedVersion(currentVersion: String, minimumSupportedVersion: String?) -> Bool {
        guard let minimumSupportedVersion else { return false }
        return isVersion(currentVersion, lessThan: minimumSupportedVersion)
    }

    static func isVersion(_ lhs: String, lessThan rhs: String) -> Bool {
        guard let left = parseVersionComponents(lhs),
              let right = parseVersionComponents(rhs) else {
            return false
        }

        let maxCount = max(left.count, right.count)
        for index in 0..<maxCount {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0
            if leftValue != rightValue {
                return leftValue < rightValue
            }
        }

        return false
    }

    private static func parseVersionComponents(_ version: String) -> [Int]? {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let rawComponents = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard !rawComponents.isEmpty else { return nil }

        var parsed: [Int] = []
        parsed.reserveCapacity(rawComponents.count)

        for raw in rawComponents {
            let digits = raw.prefix(while: \.isNumber)
            guard !digits.isEmpty, let value = Int(digits) else { return nil }
            parsed.append(value)
        }

        return parsed
    }
}
