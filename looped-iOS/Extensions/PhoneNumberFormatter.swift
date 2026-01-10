import Foundation

struct PhoneNumberFormatter {
    static func sanitizedDigits(from input: String, countryCallingCode: String) -> String {
        var digits = input.filter { $0.isNumber }

        if countryCallingCode == "1" {
            if digits.count > 10, digits.hasPrefix("1") {
                digits.removeFirst()
            }
            return String(digits.prefix(10))
        }

        return String(digits.prefix(15))
    }

    static func formattedNational(digits: String, countryCallingCode: String) -> String {
        let sanitized = sanitizedDigits(from: digits, countryCallingCode: countryCallingCode)
        guard !sanitized.isEmpty else { return "" }

        if countryCallingCode == "1" {
            return formattedNANP(sanitized)
        }

        return groupDigits(sanitized, pattern: [3, 3, 3, 3, 3], separator: " ")
    }

    static func e164(digits: String, countryCallingCode: String) -> String? {
        let sanitized = sanitizedDigits(from: digits, countryCallingCode: countryCallingCode)
        if countryCallingCode == "1" {
            guard sanitized.count == 10 else { return nil }
        } else {
            guard (6...15).contains(sanitized.count) else { return nil }
        }
        return "+\(countryCallingCode)\(sanitized)"
    }

    static func placeholderNational(countryCallingCode: String) -> String {
        if countryCallingCode == "1" {
            return "555-123-4567"
        }
        return "20 123 456 789"
    }

    private static func formattedNANP(_ digits: String) -> String {
        groupDigits(digits, pattern: [3, 3, 4], separator: "-")
    }

    private static func groupDigits(_ digits: String, pattern: [Int], separator: String) -> String {
        var parts: [String] = []
        var remaining = digits[...]

        for length in pattern {
            guard !remaining.isEmpty else { break }
            let take = min(length, remaining.count)
            parts.append(String(remaining.prefix(take)))
            remaining = remaining.dropFirst(take)
        }

        return parts.joined(separator: separator)
    }
}
