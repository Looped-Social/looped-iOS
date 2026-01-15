import SwiftUI

struct HashtagText: View {
    let text: String
    let font: Font
    let textColor: Color
    let hashtagColor: Color
    let linkColor: Color
    let onHashtagTap: (String) -> Void

    init(
        text: String,
        font: Font = .loopedBodyScaled,
        textColor: Color = .loopedTextPrimary,
        hashtagColor: Color = .loopedPrimary,
        linkColor: Color = .loopedPrimary,
        onHashtagTap: @escaping (String) -> Void
    ) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.hashtagColor = hashtagColor
        self.linkColor = linkColor
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
        let components = LoopedTextParser.parse(text, detectHashtags: true, detectLinks: true)
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
            case .url(let string, let url):
                var linkText = AttributedString(string)
                linkText.foregroundColor = linkColor
                linkText.link = url
                result.append(linkText)
            }
        }

        return result
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
