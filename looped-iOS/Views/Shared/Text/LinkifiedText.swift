import SwiftUI

struct LinkifiedText: View {
    let text: String
    let font: Font
    let textColor: Color
    let linkColor: Color
    let showsLinkPreview: Bool
    @AppStorage(LinkPreviewSettings.appStorageKey) private var linkPreviewsEnabled = LinkPreviewSettings.defaultEnabled

    init(
        _ text: String,
        font: Font = .loopedBodyScaled,
        textColor: Color = .loopedTextPrimary,
        linkColor: Color = .loopedPrimary,
        showsLinkPreview: Bool = true
    ) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.linkColor = linkColor
        self.showsLinkPreview = showsLinkPreview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(attributedText)
                .font(font)

            if shouldRenderLinkPreview, let firstURL {
                NativeLinkPreviewView(url: firstURL)
            }
        }
    }

    private var shouldRenderLinkPreview: Bool {
        showsLinkPreview && linkPreviewsEnabled
    }

    private var firstURL: URL? {
        LoopedTextParser.firstURL(in: text)
    }

    private var attributedText: AttributedString {
        let components = LoopedTextParser.parse(text, detectHashtags: false, detectLinks: true)
        var result = AttributedString()

        for component in components {
            switch component {
            case .regular(let string), .hashtag(let string), .mention(let string):
                var regularText = AttributedString(string)
                regularText.foregroundColor = textColor
                result.append(regularText)
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
    VStack(alignment: .leading, spacing: 12) {
        LinkifiedText("Plain text")
        LinkifiedText("Check this out: https://apple.com and also www.mylooped.app/privacy")
        LinkifiedText("This has a #hashtag but it stays plain in this view.")
    }
    .padding()
}
