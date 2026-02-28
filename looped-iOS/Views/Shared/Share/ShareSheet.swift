import SwiftUI
import UIKit

@MainActor
struct ShareSheet: View {
    @Environment(\.loopedPresentToast) private var presentToast
    let items: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType] = []
    var onComplete: ((Bool, UIActivity.ActivityType?) -> Void)? = nil
    var onDismiss: () -> Void = {}

    private var payload: ShareSheetPayload {
        ShareSheetPayload(items: items)
    }

    private var curatedTargets: [ShareExternalTarget] {
        [
            .instagram,
            .reddit,
            .linkedin,
            .whatsapp,
            .x,
            .threads,
            .facebook
        ]
    }

    private var visibleActions: [SharePrimaryAction] {
        var actions: [SharePrimaryAction] = [.copyLink, .mail, .messages]
        actions.append(contentsOf: curatedTargets.map(SharePrimaryAction.external))
        actions.append(.shareTo)
        return actions
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 4)
    }

    var body: some View {
        let _ = excludedActivityTypes

        VStack(alignment: .leading, spacing: 16) {
            Text("Send to")
                .font(.loopedSubheadSemibold)
                .foregroundColor(.loopedTextPrimary)

            shareActionGrid(actions: visibleActions)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shareActionGrid(actions: [SharePrimaryAction]) -> some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 18) {
            ForEach(actions) { action in
                ShareCircleActionButton(action: action) {
                    handleAction(action)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private func handleAction(_ action: SharePrimaryAction) {
        switch action {
        case .copyLink:
            handleCopyLink()
        case .mail:
            handleMail()
        case .messages:
            handleMessages()
        case .external(let target):
            handleExternalTarget(target)
        case .shareTo:
            presentNativeShareSheet()
        }
    }

    private func handleCopyLink() {
        guard let copyText = payload.copyText else { return }
        UIPasteboard.general.string = copyText
        LoopedHaptics.success()
        onComplete?(true, .copyToPasteboard)
        let toastPresenter = presentToast
        onDismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            toastPresenter(ToastMessage(text: "Link copied", kind: .success))
        }
    }

    private func handleMessages() {
        guard let body = payload.messageBody else { return }
        guard let url = makeSMSURL(body: body) else { return }

        UIApplication.shared.open(url, options: [:]) { success in
            Task { @MainActor in
                if success {
                    onComplete?(true, nil)
                    onDismiss()
                }
            }
        }
    }

    private func handleMail() {
        guard let url = makeMailURL() else {
            presentNativeShareSheet()
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            Task { @MainActor in
                if success {
                    onComplete?(true, nil)
                    onDismiss()
                } else {
                    presentNativeShareSheet()
                }
            }
        }
    }

    private func makeSMSURL(body: String) -> URL? {
        let allowed = CharacterSet.urlQueryAllowed
        guard let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return URL(string: "sms:")
        }
        return URL(string: "sms:&body=\(encodedBody)")
    }

    private func makeMailURL() -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"

        var queryItems: [URLQueryItem] = []
        if let subject = payload.primaryText {
            queryItems.append(URLQueryItem(name: "subject", value: subject))
        }
        if let body = payload.messageBody {
            queryItems.append(URLQueryItem(name: "body", value: body))
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
    }

    private func handleExternalTarget(_ target: ShareExternalTarget) {
        if target.requiresCopiedPayload, let copyText = payload.copyText {
            UIPasteboard.general.string = copyText
        }

        guard let url = target.destinationURL(for: payload) else {
            presentNativeShareSheet()
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            Task { @MainActor in
                if success {
                    onComplete?(true, nil)
                    onDismiss()
                } else {
                    presentNativeShareSheet()
                }
            }
        }
    }

    private func presentNativeShareSheet() {
        let activityController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        activityController.excludedActivityTypes = excludedActivityTypes
        activityController.completionWithItemsHandler = { activityType, completed, _, _ in
            Task { @MainActor in
                onComplete?(completed, activityType)
            }
        }

        onDismiss()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            UIHelpers.topViewController()?.present(activityController, animated: true)
        }
    }
}

@MainActor
final class ShareDrawerPresenter: ObservableObject {
    static let shared = ShareDrawerPresenter()

    @Published private(set) var presentation: ShareDrawerPresentation?

    private init() {}

    func present(
        sourceID: UUID,
        items: [Any],
        onComplete: ((Bool, UIActivity.ActivityType?) -> Void)?,
        onDismiss: @escaping () -> Void
    ) {
        presentation = ShareDrawerPresentation(
            sourceID: sourceID,
            items: items,
            onComplete: onComplete,
            onDismiss: onDismiss
        )
    }

    func dismiss(sourceID: UUID? = nil) {
        guard let current = presentation else { return }
        if let sourceID, current.sourceID != sourceID {
            return
        }
        presentation = nil
        current.onDismiss()
    }
}

struct ShareDrawerPresentation {
    let sourceID: UUID
    let items: [Any]
    let onComplete: ((Bool, UIActivity.ActivityType?) -> Void)?
    let onDismiss: () -> Void
}

struct GlobalShareDrawerHost: View {
    @ObservedObject private var presenter = ShareDrawerPresenter.shared

    var body: some View {
        LoopedBottomDrawer(
            isPresented: presenter.presentation != nil,
            onDismiss: {
                presenter.dismiss()
            }
        ) {
            if let presentation = presenter.presentation {
                ShareSheet(
                    items: presentation.items,
                    onComplete: presentation.onComplete,
                    onDismiss: {
                        presenter.dismiss()
                    }
                )
            }
        }
    }
}

extension View {
    func loopedShareDrawer(
        isPresented: Binding<Bool>,
        onDismiss: @escaping () -> Void = {},
        items: @autoclosure @escaping () -> [Any],
        onComplete: ((Bool, UIActivity.ActivityType?) -> Void)? = nil
    ) -> some View {
        modifier(
            LoopedShareDrawerModifier(
                isPresented: isPresented,
                onDismiss: onDismiss,
                items: items,
                onComplete: onComplete
            )
        )
    }

    func loopedShareDrawer<Item: Identifiable>(
        item: Binding<Item?>,
        onDismiss: @escaping () -> Void = {},
        items: @escaping (Item) -> [Any],
        onComplete: ((Bool, UIActivity.ActivityType?) -> Void)? = nil
    ) -> some View {
        modifier(
            LoopedShareDrawerItemModifier(
                item: item,
                onDismiss: onDismiss,
                items: items,
                onComplete: onComplete
            )
        )
    }
}

private struct LoopedShareDrawerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onDismiss: () -> Void
    let items: () -> [Any]
    let onComplete: ((Bool, UIActivity.ActivityType?) -> Void)?
    @State private var sourceID = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear {
                if isPresented {
                    presentDrawer()
                }
            }
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    presentDrawer()
                } else {
                    ShareDrawerPresenter.shared.dismiss(sourceID: sourceID)
                }
            }
            .onDisappear {
                ShareDrawerPresenter.shared.dismiss(sourceID: sourceID)
            }
    }

    private func dismissDrawer() {
        isPresented = false
    }

    private func presentDrawer() {
        ShareDrawerPresenter.shared.present(
            sourceID: sourceID,
            items: items(),
            onComplete: onComplete,
            onDismiss: {
                dismissDrawer()
                onDismiss()
            }
        )
    }
}

private struct LoopedShareDrawerItemModifier<Item: Identifiable>: ViewModifier {
    @Binding var item: Item?
    let onDismiss: () -> Void
    let items: (Item) -> [Any]
    let onComplete: ((Bool, UIActivity.ActivityType?) -> Void)?
    @State private var sourceID = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear {
                if let currentItem = item {
                    presentDrawer(for: currentItem)
                }
            }
            .onChange(of: item != nil) { _, newValue in
                if newValue, let currentItem = item {
                    presentDrawer(for: currentItem)
                } else {
                    ShareDrawerPresenter.shared.dismiss(sourceID: sourceID)
                }
            }
            .onDisappear {
                ShareDrawerPresenter.shared.dismiss(sourceID: sourceID)
            }
    }

    private func dismissDrawer() {
        item = nil
    }

    private func presentDrawer(for item: Item) {
        ShareDrawerPresenter.shared.present(
            sourceID: sourceID,
            items: items(item),
            onComplete: onComplete,
            onDismiss: {
                dismissDrawer()
                onDismiss()
            }
        )
    }
}

private struct ShareCircleActionButton: View {
    let action: SharePrimaryAction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(action.bubbleFillColor)
                        .frame(width: 58, height: 58)

                    if let brandAssetName = action.brandAssetName,
                       let image = UIImage(named: brandAssetName) {
                        if action.clipsBrandImageToBubble {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(
                                    width: action.brandImageSize.width,
                                    height: action.brandImageSize.height
                                )
                                .offset(
                                    x: action.brandImageOffset.width,
                                    y: action.brandImageOffset.height
                                )
                                .clipShape(Circle())
                        } else if action.rendersBrandAsTemplate {
                            Image(brandAssetName)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(action.brandTemplateTintColor)
                                .frame(
                                    width: action.brandImageSize.width,
                                    height: action.brandImageSize.height
                                )
                                .offset(
                                    x: action.brandImageOffset.width,
                                    y: action.brandImageOffset.height
                                )
                        } else {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(
                                    width: action.brandImageSize.width,
                                    height: action.brandImageSize.height
                                )
                                .offset(
                                    x: action.brandImageOffset.width,
                                    y: action.brandImageOffset.height
                                )
                        }
                    } else if let symbol = action.sfSymbol {
                        Image(systemName: symbol)
                            .font(.loopedSymbol(.semibold, size: 20))
                            .foregroundColor(action.bubbleContentColor)
                    } else {
                        Text(action.placeholderMonogram)
                            .font(.loopedSubBodyBold)
                            .foregroundColor(action.bubbleContentColor)
                    }
                }

                Text(action.title)
                    .font(.loopedSmallTextMedium)
                    .foregroundColor(.loopedTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                    .frame(width: 82, height: 16, alignment: .top)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.accessibilityLabel)
    }
}

private enum SharePrimaryAction: Identifiable {
    case copyLink
    case mail
    case messages
    case external(ShareExternalTarget)
    case shareTo

    var id: String {
        switch self {
        case .copyLink:
            return "copy_link"
        case .mail:
            return "mail"
        case .messages:
            return "messages"
        case .external(let target):
            return "external_\(target.rawValue)"
        case .shareTo:
            return "share_to"
        }
    }

    var title: String {
        switch self {
        case .copyLink:
            return "Copy link"
        case .mail:
            return "Mail"
        case .messages:
            return "Messages"
        case .external(let target):
            return target.title
        case .shareTo:
            return "Share to"
        }
    }

    var sfSymbol: String? {
        switch self {
        case .copyLink:
            return "link"
        case .mail:
            return "envelope.fill"
        case .messages:
            return "message.fill"
        case .external:
            return nil
        case .shareTo:
            return "square.and.arrow.up"
        }
    }

    var brandAssetName: String? {
        switch self {
        case .external(let target):
            return target.brandAssetName
        case .copyLink:
            return "link-icon"
        case .mail:
            return "mail-icon"
        case .messages:
            return "imessage-icon"
        case .shareTo:
            return "share-secondary"
        }
    }

    var brandImageSize: CGSize {
        switch self {
        case .external(.facebook), .external(.reddit):
            return CGSize(width: 58, height: 58)
        case .external(.linkedin):
            return CGSize(width: 38, height: 38)
        case .external(.instagram):
            return CGSize(width: 30, height: 30)
        case .external(.threads):
            return CGSize(width: 32, height: 32)
        case .copyLink, .mail:
            return CGSize(width: 28, height: 28)
        case .messages:
            return CGSize(width: 26, height: 26)
        case .shareTo:
            return CGSize(width: 26, height: 26)
        case .external:
            return CGSize(width: 24, height: 24)
        }
    }

    var brandImageOffset: CGSize {
        switch self {
        case .external(.linkedin):
            return CGSize(width: 0, height: 1)
        case .copyLink, .mail, .messages, .external, .shareTo:
            return .zero
        }
    }

    var clipsBrandImageToBubble: Bool {
        switch self {
        case .external(.facebook), .external(.reddit):
            return true
        case .copyLink, .mail, .messages, .external, .shareTo:
            return false
        }
    }

    var rendersBrandAsTemplate: Bool {
        switch self {
        case .copyLink, .mail, .messages:
            return true
        case .external, .shareTo:
            return false
        }
    }

    var brandTemplateTintColor: Color {
        switch self {
        case .copyLink, .mail, .messages:
            return .loopedWhite
        case .external, .shareTo:
            return .loopedTextPrimary
        }
    }

    var placeholderMonogram: String {
        switch self {
        case .external(let target):
            return target.placeholderMonogram
        case .copyLink:
            return "CL"
        case .mail:
            return "ML"
        case .messages:
            return "MS"
        case .shareTo:
            return "ST"
        }
    }

    var bubbleFillColor: Color {
        switch self {
        case .copyLink:
            return .loopedPrimary
        case .mail:
            return .loopedMailCyan
        case .external(.x), .external(.threads):
            return .loopedBlack
        case .external(.linkedin):
            return .loopedWhite
        case .external(.instagram):
            return .loopedContrast
        case .external(.whatsapp):
            return .loopedWhatsAppGreen
        case .messages:
            return .loopedMessagesGreen
        case .copyLink, .mail, .external, .shareTo:
            return .loopedMutedBackground
        }
    }

    var bubbleContentColor: Color {
        switch self {
        case .copyLink, .mail:
            return .loopedWhite
        case .external(.x), .external(.threads):
            return .loopedWhite
        case .messages:
            return .loopedWhite
        case .external, .shareTo:
            return .loopedTextPrimary
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .external(let target):
            return "Share to \(target.title)"
        case .copyLink:
            return "Copy share link"
        case .mail:
            return "Open Mail app"
        case .messages:
            return "Open Messages app"
        case .shareTo:
            return "Open native share sheet"
        }
    }
}

private enum ShareExternalTarget: String {
    case instagram
    case reddit
    case linkedin
    case tiktok
    case x
    case facebook
    case whatsapp
    case telegram
    case snapchat
    case threads

    static let primaryOrder: [ShareExternalTarget] = [
        .instagram,
        .reddit,
        .linkedin,
        .tiktok
    ]

    static let moreOrder: [ShareExternalTarget] = [
        .x,
        .facebook,
        .whatsapp,
        .telegram,
        .snapchat,
        .threads
    ]

    var title: String {
        switch self {
        case .instagram:
            return "Instagram"
        case .reddit:
            return "Reddit"
        case .linkedin:
            return "LinkedIn"
        case .tiktok:
            return "TikTok"
        case .x:
            return "X"
        case .facebook:
            return "Facebook"
        case .whatsapp:
            return "WhatsApp"
        case .telegram:
            return "Telegram"
        case .snapchat:
            return "Snapchat"
        case .threads:
            return "Threads"
        }
    }

    var brandAssetName: String {
        switch self {
        case .instagram:
            return "share_target_instagram"
        case .reddit:
            return "share_target_reddit"
        case .linkedin:
            return "share_target_linkedin"
        case .tiktok:
            return "share_target_tiktok"
        case .x:
            return "share_target_x"
        case .facebook:
            return "share_target_facebook"
        case .whatsapp:
            return "share_target_whatsapp"
        case .telegram:
            return "share_target_telegram"
        case .snapchat:
            return "share_target_snapchat"
        case .threads:
            return "share_target_threads"
        }
    }

    var placeholderMonogram: String {
        switch self {
        case .instagram:
            return "IG"
        case .reddit:
            return "RD"
        case .linkedin:
            return "IN"
        case .tiktok:
            return "TT"
        case .x:
            return "X"
        case .facebook:
            return "FB"
        case .whatsapp:
            return "WA"
        case .telegram:
            return "TG"
        case .snapchat:
            return "SC"
        case .threads:
            return "TH"
        }
    }

    var queryScheme: String {
        switch self {
        case .instagram:
            return "instagram"
        case .reddit:
            return "reddit"
        case .linkedin:
            return "linkedin"
        case .tiktok:
            return "tiktok"
        case .x:
            return "twitter"
        case .facebook:
            return "fb"
        case .whatsapp:
            return "whatsapp"
        case .telegram:
            return "tg"
        case .snapchat:
            return "snapchat"
        case .threads:
            return "threads"
        }
    }

    var appURL: URL {
        switch self {
        case .instagram:
            return URL(string: "instagram://app")!
        case .reddit:
            return URL(string: "reddit://")!
        case .linkedin:
            return URL(string: "linkedin://")!
        case .tiktok:
            return URL(string: "tiktok://")!
        case .x:
            return URL(string: "twitter://")!
        case .facebook:
            return URL(string: "fb://")!
        case .whatsapp:
            return URL(string: "whatsapp://")!
        case .telegram:
            return URL(string: "tg://")!
        case .snapchat:
            return URL(string: "snapchat://")!
        case .threads:
            return URL(string: "threads://")!
        }
    }

    var requiresCopiedPayload: Bool {
        switch self {
        case .instagram, .tiktok, .snapchat, .threads:
            return true
        case .reddit, .linkedin, .x, .facebook, .whatsapp, .telegram:
            return false
        }
    }

    @MainActor
    var isInstalled: Bool {
        guard let checkURL = URL(string: "\(queryScheme)://") else { return false }
        return UIApplication.shared.canOpenURL(checkURL)
    }

    @MainActor
    func destinationURL(for payload: ShareSheetPayload) -> URL? {
        switch self {
        case .instagram, .tiktok, .snapchat, .threads:
            return isInstalled ? appURL : nil
        case .reddit:
            guard payload.primaryURL != nil else { return isInstalled ? appURL : nil }
            return makeURL(
                base: "https://www.reddit.com/submit",
                queryItems: [
                    URLQueryItem(name: "url", value: payload.primaryURL?.absoluteString),
                    URLQueryItem(name: "title", value: payload.primaryText)
                ]
            )
        case .linkedin:
            guard payload.primaryURL != nil else { return isInstalled ? appURL : nil }
            return makeURL(
                base: "https://www.linkedin.com/sharing/share-offsite/",
                queryItems: [URLQueryItem(name: "url", value: payload.primaryURL?.absoluteString)]
            )
        case .x:
            if payload.primaryURL == nil && payload.primaryText == nil {
                return isInstalled ? appURL : nil
            }
            return makeURL(
                base: "https://twitter.com/intent/tweet",
                queryItems: [
                    URLQueryItem(name: "url", value: payload.primaryURL?.absoluteString),
                    URLQueryItem(name: "text", value: payload.primaryText)
                ]
            )
        case .facebook:
            guard payload.primaryURL != nil else { return isInstalled ? appURL : nil }
            return makeURL(
                base: "https://www.facebook.com/sharer/sharer.php",
                queryItems: [URLQueryItem(name: "u", value: payload.primaryURL?.absoluteString)]
            )
        case .whatsapp:
            if let message = payload.messageBody {
                if isInstalled {
                    return makeURL(
                        base: "whatsapp://send",
                        queryItems: [URLQueryItem(name: "text", value: message)]
                    )
                }
                return makeURL(
                    base: "https://wa.me/",
                    queryItems: [URLQueryItem(name: "text", value: message)]
                )
            }
            return isInstalled ? appURL : nil
        case .telegram:
            if let message = payload.messageBody {
                return makeURL(
                    base: "tg://msg",
                    queryItems: [URLQueryItem(name: "text", value: message)]
                )
            }
            return appURL
        }
    }

    private func makeURL(base: String, queryItems: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(string: base) else { return nil }
        let filtered = queryItems.filter { ($0.value ?? "").isEmpty == false }
        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.url
    }
}

struct ShareSheetPayload {
    let primaryURL: URL?
    let primaryText: String?
    let copyText: String?
    let messageBody: String?

    init(items: [Any]) {
        let urls = items.compactMap { $0 as? URL }
        let textItems = items
            .compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let firstURL = urls.first
        let firstText = textItems.first

        var segments: [String] = []
        if let firstText {
            segments.append(firstText)
        }
        if let firstURL {
            segments.append(firstURL.absoluteString)
        }

        let combined = segments.joined(separator: " ")

        self.primaryURL = firstURL
        self.primaryText = firstText
        self.copyText = combined.isEmpty ? firstText ?? firstURL?.absoluteString : combined
        self.messageBody = combined.isEmpty ? nil : combined
    }
}
