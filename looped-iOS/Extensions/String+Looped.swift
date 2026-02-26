import Foundation

extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func compactRailPersonName(maxLength: Int = 18) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Looped User" }
        guard trimmed.count > maxLength else { return trimmed }

        let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        if let first = parts.first, let last = parts.last, parts.count >= 2, let lastInitial = last.first {
            let abbreviated = "\(first) \(lastInitial)."
            if abbreviated.count <= maxLength {
                return abbreviated
            }
        }

        return twoDotTruncate(trimmed, maxLength: maxLength)
    }

    private func twoDotTruncate(_ value: String, maxLength: Int) -> String {
        guard maxLength > 2 else { return ".." }
        guard value.count > maxLength else { return value }
        return String(value.prefix(maxLength - 2)) + ".."
    }
}
