import Foundation

enum CommunityLabelText {
    static func preferredName(
        preferShortNames: Bool,
        name: String?,
        shortName: String?,
        fallback: String? = nil
    ) -> String? {
        if preferShortNames, let short = shortName?.trimmedNonEmpty {
            return short
        }
        if let long = name?.trimmedNonEmpty {
            return long
        }
        return fallback?.trimmedNonEmpty
    }
}

