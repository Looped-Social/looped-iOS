import SwiftUI

struct HashtagText: View {
    let text: String
    let font: Font
    let textColor: Color
    let hashtagColor: Color
    let onHashtagTap: (String) -> Void

    init(
        text: String,
        font: Font = .loopedBodyScaled,
        textColor: Color = .loopedTextPrimary,
        hashtagColor: Color = .loopedPrimary,
        onHashtagTap: @escaping (String) -> Void
    ) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.hashtagColor = hashtagColor
        self.onHashtagTap = onHashtagTap
    }

    var body: some View {
        Text(attributedText)
            .font(font)
            .environment(\.openURL, OpenURLAction { url in
                // Handle hashtag taps via URL scheme
                if url.scheme == "hashtag", let hashtag = url.host {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    onHashtagTap(hashtag)
                    return .handled
                }
                return .systemAction
            })
    }

    private var attributedText: AttributedString {
        let components = parseText(text)
        var result = AttributedString()

        for component in components {
            switch component {
            case .regular(let string):
                var regularText = AttributedString(string)
                regularText.foregroundColor = textColor
                result.append(regularText)
            case .hashtag(let string):
                // Remove # from hashtag for URL
                let cleanHashtag = string.hasPrefix("#") ? String(string.dropFirst()) : string
                var hashtagText = AttributedString(string)
                hashtagText.foregroundColor = hashtagColor
                hashtagText.link = URL(string: "hashtag://\(cleanHashtag)")
                result.append(hashtagText)
            }
        }

        return result
    }

    private func parseText(_ text: String) -> [TextComponent] {
        var components: [TextComponent] = []
        let pattern = "#\\w+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.regular(text)]
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var lastIndex = text.startIndex

        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }

            // Add regular text before hashtag
            if lastIndex < range.lowerBound {
                let regularText = String(text[lastIndex..<range.lowerBound])
                components.append(.regular(regularText))
            }

            // Add hashtag
            let hashtag = String(text[range])
            components.append(.hashtag(hashtag))

            lastIndex = range.upperBound
        }

        // Add remaining regular text
        if lastIndex < text.endIndex {
            let regularText = String(text[lastIndex...])
            components.append(.regular(regularText))
        }

        return components.isEmpty ? [.regular(text)] : components
    }

    enum TextComponent {
        case regular(String)
        case hashtag(String)
    }
}

#Preview {
    VStack(spacing: 20) {
        HashtagText(
            text: "This is a test with #hashtag and #another one!",
            onHashtagTap: { _ in }
        )

        HashtagText(
            text: "Check out #TGIF #productdesign and let me know!",
            font: .loopedHeadlineScaled,
            onHashtagTap: { _ in }
        )
    }
    .padding()
}
