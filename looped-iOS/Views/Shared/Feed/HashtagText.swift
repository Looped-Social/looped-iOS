import SwiftUI

struct HashtagText: View {
    let text: String
    let prefix: String?
    let prefixFont: Font?
    let prefixColor: Color?
    let font: Font
    let textColor: Color
    let hashtagColor: Color
    let mentionColor: Color
    let linkColor: Color
    let showsLinkPreview: Bool
    let onHashtagTap: (String) -> Void
    let onMentionTap: ((String) -> Void)?
    @AppStorage(LinkPreviewSettings.appStorageKey) private var linkPreviewsEnabled = LinkPreviewSettings.defaultEnabled

    init(
        text: String,
        prefix: String? = nil,
        prefixFont: Font? = nil,
        prefixColor: Color? = nil,
        font: Font = .loopedBodyScaled,
        textColor: Color = .loopedTextPrimary,
        hashtagColor: Color = .loopedPrimary,
        mentionColor: Color? = nil,
        linkColor: Color = .loopedPrimary,
        showsLinkPreview: Bool = true,
        onHashtagTap: @escaping (String) -> Void,
        onMentionTap: ((String) -> Void)? = nil
    ) {
        self.text = text
        self.prefix = prefix
        self.prefixFont = prefixFont
        self.prefixColor = prefixColor
        self.font = font
        self.textColor = textColor
        self.hashtagColor = hashtagColor
        self.mentionColor = mentionColor ?? hashtagColor
        self.linkColor = linkColor
        self.showsLinkPreview = showsLinkPreview
        self.onHashtagTap = onHashtagTap
        self.onMentionTap = onMentionTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !displayTextTrimmed.isEmpty {
                Text(attributedText)
            }

            if shouldRenderLinkPreview, let firstURL {
                NativeLinkPreviewView(url: firstURL)
            }
        }
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

    private var shouldRenderLinkPreview: Bool {
        showsLinkPreview && linkPreviewsEnabled
    }

    private var firstURL: URL? {
        LoopedTextParser.firstURL(in: text)
    }

    private var displayText: String {
        if shouldRenderLinkPreview && firstURL != nil {
            return LoopedTextParser.removingURLs(from: text)
        }
        return text
    }

    private var displayTextTrimmed: String {
        displayText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var attributedText: AttributedString {
        let components = LoopedTextParser.parse(
            displayText,
            detectHashtags: true,
            detectMentions: true,
            detectLinks: true
        )
        var result = AttributedString()

        if let prefix, !prefix.isEmpty {
            var prefixText = AttributedString(prefix)
            prefixText.foregroundColor = prefixColor ?? textColor
            prefixText.font = prefixFont ?? font
            result.append(prefixText)
        }

        for component in components {
            switch component {
            case .regular(let string):
                var regularText = AttributedString(string)
                regularText.foregroundColor = textColor
                regularText.font = font
                result.append(regularText)
            case .hashtag(let string):
                // Remove # from hashtag for URL
                let cleanHashtag = string.hasPrefix("#") ? String(string.dropFirst()) : string
                var hashtagText = AttributedString(string)
                hashtagText.foregroundColor = hashtagColor
                hashtagText.font = font
                hashtagText.link = URL(string: "hashtag://\(cleanHashtag)")
                result.append(hashtagText)
            case .mention(let string):
                let cleanHandle = String(string.dropFirst())
                guard !cleanHandle.isEmpty else {
                    var regularText = AttributedString(string)
                    regularText.foregroundColor = textColor
                    regularText.font = font
                    result.append(regularText)
                    continue
                }
                var mentionText = AttributedString(string)
                mentionText.foregroundColor = mentionColor
                mentionText.font = font
                if let encodedHandle = cleanHandle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    mentionText.link = URL(string: "mention://profile?handle=\(encodedHandle)")
                }
                result.append(mentionText)
            case .url(let string, let url):
                var linkText = AttributedString(string)
                linkText.foregroundColor = linkColor
                linkText.font = font
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
