import SwiftUI

struct HashtagText: View {
    let text: String
    let font: Font
    let textColor: Color
    let hashtagColor: Color
    let mentionColor: Color
    let linkColor: Color
    let onHashtagTap: (String) -> Void
    let onMentionTap: ((String) -> Void)?

    init(
        text: String,
        font: Font = .loopedBodyScaled,
        textColor: Color = .loopedTextPrimary,
        hashtagColor: Color = .loopedPrimary,
        mentionColor: Color? = nil,
        linkColor: Color = .loopedPrimary,
        onHashtagTap: @escaping (String) -> Void,
        onMentionTap: ((String) -> Void)? = nil
    ) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.hashtagColor = hashtagColor
        self.mentionColor = mentionColor ?? hashtagColor
        self.linkColor = linkColor
        self.onHashtagTap = onHashtagTap
        self.onMentionTap = onMentionTap
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
                if url.scheme == "mention", let handle = mentionHandle(from: url) {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    onMentionTap?(handle)
                    return .handled
                }
                return .systemAction
            })
    }

    private var attributedText: AttributedString {
        let components = LoopedTextParser.parse(
            text,
            detectHashtags: true,
            detectMentions: true,
            detectLinks: true
        )
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
            case .mention(let string):
                let cleanHandle = String(string.dropFirst())
                guard !cleanHandle.isEmpty else {
                    var regularText = AttributedString(string)
                    regularText.foregroundColor = textColor
                    result.append(regularText)
                    continue
                }
                var mentionText = AttributedString(string)
                mentionText.foregroundColor = mentionColor
                if let encodedHandle = cleanHandle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    mentionText.link = URL(string: "mention://profile?handle=\(encodedHandle)")
                }
                result.append(mentionText)
            case .url(let string, let url):
                var linkText = AttributedString(string)
                linkText.foregroundColor = linkColor
                linkText.link = url
                result.append(linkText)
            }
        }

        return result
    }

    private func mentionHandle(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let handle = components.queryItems?
            .first(where: { $0.name == "handle" })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return handle.isEmpty ? nil : handle
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
