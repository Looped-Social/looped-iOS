import Foundation

enum LoopedTextComponent: Equatable {
    case regular(String)
    case hashtag(String)
    case url(text: String, url: URL)
}

struct LoopedTextParser {
    static func parse(_ text: String, detectHashtags: Bool = true, detectLinks: Bool = true) -> [LoopedTextComponent] {
        let matches = collectMatches(in: text, detectHashtags: detectHashtags, detectLinks: detectLinks)
        guard !matches.isEmpty else { return [.regular(text)] }

        var components: [LoopedTextComponent] = []
        var lastIndex = text.startIndex

        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            guard range.lowerBound >= lastIndex else { continue }

            if lastIndex < range.lowerBound {
                components.append(.regular(String(text[lastIndex..<range.lowerBound])))
            }

            switch match.kind {
            case .hashtag:
                components.append(.hashtag(String(text[range])))
            case .url(let url):
                components.append(.url(text: String(text[range]), url: url))
            }

            lastIndex = range.upperBound
        }

        if lastIndex < text.endIndex {
            components.append(.regular(String(text[lastIndex...])))
        }

        return components.isEmpty ? [.regular(text)] : components
    }

    private enum MatchKind: Equatable {
        case hashtag
        case url(URL)
    }

    private struct Match: Equatable {
        let range: NSRange
        let kind: MatchKind
    }

    private static func collectMatches(in text: String, detectHashtags: Bool, detectLinks: Bool) -> [Match] {
        let searchRange = NSRange(text.startIndex..., in: text)
        var matches: [Match] = []

        if detectLinks, let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            for result in detector.matches(in: text, options: [], range: searchRange) {
                guard let url = result.url else { continue }
                guard url.scheme == "http" || url.scheme == "https" else { continue }
                matches.append(Match(range: result.range, kind: .url(url)))
            }
        }

        if detectHashtags, let regex = try? NSRegularExpression(pattern: "#\\w+") {
            for result in regex.matches(in: text, options: [], range: searchRange) {
                matches.append(Match(range: result.range, kind: .hashtag))
            }
        }

        guard !matches.isEmpty else { return [] }

        // Sort by location, then prefer longer matches (helps avoid overlaps).
        matches.sort { lhs, rhs in
            if lhs.range.location != rhs.range.location {
                return lhs.range.location < rhs.range.location
            }
            return lhs.range.length > rhs.range.length
        }

        // Remove overlaps.
        var nonOverlapping: [Match] = []
        var currentEnd = 0
        for match in matches {
            guard match.range.location >= currentEnd else { continue }
            nonOverlapping.append(match)
            currentEnd = match.range.location + match.range.length
        }

        return nonOverlapping
    }
}

