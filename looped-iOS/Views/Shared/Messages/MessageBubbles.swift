import SwiftUI
import UIKit

private enum MessageBubbleTimeFormatters {
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

private enum MessageBubbleLayout {
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 10
    static let bubbleMaxWidth: CGFloat = min(420, UIScreen.main.bounds.width * 0.72)
    static let mediaTileSize: CGFloat = 220
}

private struct ChatBubbleWidthLayout: Layout {
    let maxWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let subview = subviews.first else { return .zero }

        let unconstrained = subview.sizeThatFits(ProposedViewSize(width: nil, height: proposal.height))
        if unconstrained.width <= maxWidth {
            let resolved = subview.sizeThatFits(ProposedViewSize(width: unconstrained.width, height: proposal.height))
            return CGSize(width: unconstrained.width, height: resolved.height)
        }

        let constrained = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: proposal.height))
        return CGSize(width: min(maxWidth, constrained.width), height: constrained.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let subview = subviews.first else { return }
        subview.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}

// MARK: - Sent Message Bubble (User's Messages)
struct SentMessageBubble: View {
    let message: Message
    let isGroupStart: Bool
    let isGroupEnd: Bool

    @State private var selectedImageUrl: String?
    @State private var selectedImageIndex: Int = 0
    @State private var selectedVideoUrl: String?
    @State private var showImageViewer = false
    @State private var showVideoPlayer = false

    init(message: Message, isGroupStart: Bool = true, isGroupEnd: Bool = true) {
        self.message = message
        self.isGroupStart = isGroupStart
        self.isGroupEnd = isGroupEnd
    }

    private var imageUrls: [String] {
        message.attachments?.filter { $0.type == .image }.map { $0.url } ?? []
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Show media if present
            if let attachments = message.attachments, !attachments.isEmpty {
                ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                    if attachment.type == .video {
                        // Video thumbnail with play button
                        ZStack {
                            MessageMediaTile(
                                url: firstValidURL(from: [attachment.thumbnailUrl, attachment.url]),
                                resolveKey: attachment.id.hasPrefix("dm/") ? attachment.id : nil
                            )
                                .frame(width: MessageBubbleLayout.mediaTileSize, height: MessageBubbleLayout.mediaTileSize)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            // Play button overlay
                            Circle()
                                .fill(Color.loopedBlack.opacity(0.6))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .font(.loopedCustom(size: 22))
                                        .foregroundColor(.loopedWhite)
                                        .offset(x: 2)
                                )
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if !message.hasVisibleContent, index == attachments.count - 1 {
                                MessageMediaTimeBadge(timeText: formatBubbleTime(message.createdAt))
                            }
                        }
                        .onTapGesture {
                            selectedVideoUrl = attachment.url
                            showVideoPlayer = true
                        }
                    } else {
                        MessageMediaTile(
                            url: firstValidURL(from: [attachment.url]),
                            resolveKey: attachment.id.hasPrefix("dm/") ? attachment.id : nil
                        )
                            .frame(width: MessageBubbleLayout.mediaTileSize, height: MessageBubbleLayout.mediaTileSize)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            if !message.hasVisibleContent, index == attachments.count - 1 {
                                MessageMediaTimeBadge(timeText: formatBubbleTime(message.createdAt))
                            }
                        }
	                        .onTapGesture {
	                            // Find the index of the tapped image among all images
	                            if let index = imageUrls.firstIndex(of: attachment.url) {
	                                selectedImageIndex = index
	                            }
	                            selectedImageUrl = attachment.url
	                            DispatchQueue.main.async {
	                                showImageViewer = true
	                            }
	                        }
                    }
                }
            }

            // Show text if present
            if message.hasVisibleContent {
                let bubbleShape = ChatBubbleShape(isFromCurrentUser: true, isGroupStart: isGroupStart, isGroupEnd: isGroupEnd)
                ChatBubbleWidthLayout(maxWidth: MessageBubbleLayout.bubbleMaxWidth) {
                    bubbleTextWithNewlineTime(message: message, isFromCurrentUser: true)
                        .padding(.horizontal, MessageBubbleLayout.horizontalPadding)
                        .padding(.vertical, MessageBubbleLayout.verticalPadding)
                }
                .background(Color.loopedMessageColor)
                .clipShape(bubbleShape)
            }
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            if !imageUrls.isEmpty {
                FullScreenImageViewer(
                    imageUrls: imageUrls,
                    initialIndex: selectedImageIndex,
                    isPresented: $showImageViewer
                )
            }
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let videoUrl = selectedVideoUrl {
                VideoPlayerSheet(videoUrl: videoUrl, isPresented: $showVideoPlayer)
            }
        }
    }
}

// MARK: - Received Message Bubble (Other Users' Messages)
struct ReceivedMessageBubble: View {
    let message: Message
    let showSenderName: Bool
    let isGroupStart: Bool
    let isGroupEnd: Bool

    @State private var selectedImageUrl: String?
    @State private var selectedImageIndex: Int = 0
    @State private var selectedVideoUrl: String?
    @State private var showImageViewer = false
    @State private var showVideoPlayer = false

    init(
        message: Message,
        showSenderName: Bool,
        isGroupStart: Bool = true,
        isGroupEnd: Bool = true
    ) {
        self.message = message
        self.showSenderName = showSenderName
        self.isGroupStart = isGroupStart
        self.isGroupEnd = isGroupEnd
    }

    private var imageUrls: [String] {
        message.attachments?.filter { $0.type == .image }.map { $0.url } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Sender Name (only for group chats)
            if showSenderName {
                Text(message.senderDisplayName ?? "Unknown User")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                    .padding(.leading, 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Show media if present
                if let attachments = message.attachments, !attachments.isEmpty {
                    ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
	                        if attachment.type == .video {
	                            // Video thumbnail with play button
	                            ZStack {
	                                MessageMediaTile(
	                                    url: firstValidURL(from: [attachment.thumbnailUrl, attachment.url]),
	                                    resolveKey: attachment.id.hasPrefix("dm/") ? attachment.id : nil
	                                )
	                                    .frame(width: MessageBubbleLayout.mediaTileSize, height: MessageBubbleLayout.mediaTileSize)
	                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                // Play button overlay
                                Circle()
                                    .fill(Color.loopedBlack.opacity(0.6))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Image(systemName: "play.fill")
                                            .font(.loopedCustom(size: 22))
                                            .foregroundColor(.loopedWhite)
                                            .offset(x: 2)
                                    )
                            }
                            .overlay(alignment: .bottomTrailing) {
                                if !message.hasVisibleContent, index == attachments.count - 1 {
                                    MessageMediaTimeBadge(timeText: formatBubbleTime(message.createdAt))
                                }
	                            }
	                            .onTapGesture {
	                                selectedVideoUrl = attachment.url
	                                showVideoPlayer = true
	                            }
	                        } else {
	                            MessageMediaTile(
	                                url: firstValidURL(from: [attachment.url]),
	                                resolveKey: attachment.id.hasPrefix("dm/") ? attachment.id : nil
	                            )
	                                .frame(width: MessageBubbleLayout.mediaTileSize, height: MessageBubbleLayout.mediaTileSize)
	                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
	                            .overlay(alignment: .bottomTrailing) {
	                                if !message.hasVisibleContent, index == attachments.count - 1 {
	                                    MessageMediaTimeBadge(timeText: formatBubbleTime(message.createdAt))
                                }
                            }
	                            .onTapGesture {
	                                // Find the index of the tapped image among all images
	                                if let index = imageUrls.firstIndex(of: attachment.url) {
	                                    selectedImageIndex = index
	                                }
	                                selectedImageUrl = attachment.url
	                                DispatchQueue.main.async {
	                                    showImageViewer = true
	                                }
	                            }
                        }
                    }
                }

                // Show text if present
                if message.hasVisibleContent {
                    let bubbleShape = ChatBubbleShape(isFromCurrentUser: false, isGroupStart: isGroupStart, isGroupEnd: isGroupEnd)
                    ChatBubbleWidthLayout(maxWidth: MessageBubbleLayout.bubbleMaxWidth) {
                        bubbleTextWithNewlineTime(message: message, isFromCurrentUser: false)
                            .padding(.horizontal, MessageBubbleLayout.horizontalPadding)
                            .padding(.vertical, MessageBubbleLayout.verticalPadding)
                    }
                    .background(Color.loopedMessageMutedColor)
                    .clipShape(bubbleShape)
                }
            }
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            if !imageUrls.isEmpty {
                FullScreenImageViewer(
                    imageUrls: imageUrls,
                    initialIndex: selectedImageIndex,
                    isPresented: $showImageViewer
                )
            }
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let videoUrl = selectedVideoUrl {
                VideoPlayerSheet(videoUrl: videoUrl, isPresented: $showVideoPlayer)
            }
        }
    }
}

// MARK: - Image Message Bubble (for handling image attachments)
struct ImageMessageBubble: View {
    let message: Message
    let imageUrl: String
    let showProfilePicture: Bool
    let showSenderName: Bool
    let isFromCurrentUser: Bool

    @State private var showImageViewer = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isFromCurrentUser {
                // Profile Picture (only for group chats and received messages)
                if showProfilePicture {
                    ProfileAvatarView(imageURL: nil, size: 32)
                }
            }

            if isFromCurrentUser {
                Spacer()
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender Name (only for group chats and received messages)
                if showSenderName && !isFromCurrentUser {
                    Text(message.senderDisplayName ?? "Unknown User")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.leading, 4)
                }

                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                    // Image with text overlay if there's content
                    VStack(spacing: 8) {
                        MessageMediaTile(url: firstValidURL(from: [imageUrl]), resolveKey: nil)
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onTapGesture {
                            showImageViewer = true
                        }

                        if message.hasVisibleContent {
                            LinkifiedText(
                                message.normalizedContent,
                                font: .loopedBody,
                                textColor: .loopedTextPrimary,
                                linkColor: .loopedPrimary
                            )
                            .multilineTextAlignment(isFromCurrentUser ? .trailing : .leading)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isFromCurrentUser ? Color.loopedWhite : Color.loopedMessageColor)
                            .shadow(color: .loopedBlack.opacity(0.1), radius: 2, x: 0, y: 1)
                    )

                    Text(formatBubbleTime(message.createdAt))
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.leading, isFromCurrentUser ? 0 : 4)
                        .padding(.trailing, isFromCurrentUser ? 4 : 0)
                }
            }

            if !isFromCurrentUser {
                Spacer()
            }
        }
        .padding(.leading, isFromCurrentUser ? 80 : (showProfilePicture ? 0 : 40))
        .padding(.trailing, isFromCurrentUser ? 0 : 80)
        .fullScreenCover(isPresented: $showImageViewer) {
            FullScreenImageViewer(
                imageUrls: [imageUrl],
                initialIndex: 0,
                isPresented: $showImageViewer
            )
        }
    }
}

private struct MessageMediaTile: View {
    let url: URL?
    let resolveKey: String?

    @State private var resolvedUrl: URL?
    @State private var showSpinner = true
    @State private var loadCompleted = false
    @State private var scheduledRetry = false
    @State private var retryCount = 0
    @State private var reloadToken = UUID()
    @State private var resolveAttemptCount = 0
    @State private var resolveInFlight = false

    private static let messageMediaService: MessageMediaServiceProtocol = MessageMediaService()

    init(url: URL?, resolveKey: String?) {
        self.url = url
        self.resolveKey = resolveKey
        _resolvedUrl = State(initialValue: url)
    }

    var body: some View {
        let urlToLoad = resolvedUrl
        Group {
            if let urlToLoad {
                AsyncImage(url: urlToLoad) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .onAppear {
                                loadCompleted = true
                            }
                    case .failure:
                        placeholder(showSpinner: retryCount < 2, showErrorIcon: true)
                            .task {
                                await refreshSignedUrlIfPossible()
                            }
                            .task {
                                await scheduleRetryIfNeeded(afterNanoseconds: 2_000_000_000)
                            }
                    case .empty:
                        placeholder(showSpinner: showSpinner, showErrorIcon: false)
                            .task {
                                guard showSpinner else { return }
                                try? await Task.sleep(nanoseconds: 6_000_000_000)
                                showSpinner = false
                            }
                            .task {
                                await scheduleRetryIfNeeded(afterNanoseconds: 4_000_000_000)
                            }
                    @unknown default:
                        placeholder(showSpinner: retryCount < 2, showErrorIcon: true)
                            .task {
                                await refreshSignedUrlIfPossible()
                            }
                            .task {
                                await scheduleRetryIfNeeded(afterNanoseconds: 2_000_000_000)
                            }
                    }
                }
                .id(reloadToken)
            } else {
                placeholder(showSpinner: false, showErrorIcon: true)
            }
        }
        .onChange(of: url) { _, _ in
            showSpinner = true
            loadCompleted = false
            scheduledRetry = false
            retryCount = 0
            reloadToken = UUID()
            resolveAttemptCount = 0
            resolveInFlight = false
            resolvedUrl = url
        }
    }

    @MainActor
    private func scheduleRetryIfNeeded(afterNanoseconds delay: UInt64) async {
        guard !loadCompleted else { return }
        guard !scheduledRetry else { return }
        guard retryCount < 2 else {
            loadCompleted = true
            return
        }

        scheduledRetry = true
        try? await Task.sleep(nanoseconds: delay)
        guard !Task.isCancelled else { return }
        guard !loadCompleted else { return }

        retryCount += 1
        scheduledRetry = false
        showSpinner = true
        reloadToken = UUID()
    }

    private func placeholder(showSpinner: Bool, showErrorIcon: Bool) -> some View {
        Rectangle()
            .fill(Color.loopedMutedBackground)
            .overlay {
                if showErrorIcon {
                    Image(systemName: "photo")
                        .font(.loopedCustom(size: 18))
                        .foregroundColor(.loopedTextSecondary.opacity(0.9))
                } else if showSpinner {
                    ProgressView()
                        .tint(.loopedTextSecondary.opacity(0.9))
                } else {
                    Image(systemName: "photo")
                        .font(.loopedCustom(size: 18))
                        .foregroundColor(.loopedTextSecondary.opacity(0.9))
                }
            }
    }

    @MainActor
    private func refreshSignedUrlIfPossible() async {
        guard !loadCompleted else { return }
        guard let resolveKey, resolveKey.hasPrefix("dm/") else { return }
        guard !resolveInFlight else { return }
        guard resolveAttemptCount < 2 else { return }

        resolveInFlight = true
        resolveAttemptCount += 1
        defer { resolveInFlight = false }

        do {
            let items = try await Self.messageMediaService.resolve(keys: [resolveKey])
            guard let item = items.first, let fresh = URL(string: item.downloadUrl), !item.downloadUrl.isEmpty else { return }
            resolvedUrl = fresh
            showSpinner = true
            loadCompleted = false
            scheduledRetry = false
            retryCount = 0
            reloadToken = UUID()
        } catch {
            // Best-effort: keep showing placeholder/retry.
        }
    }
}

private func firstValidURL(from candidates: [String?]) -> URL? {
    for candidate in candidates {
        let trimmed = (candidate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { continue }

        if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            return url
        }
        // If a URL is missing scheme but has a host, we can still try it.
        if url.scheme == nil, url.host != nil {
            return url
        }
    }

    return nil
}

// MARK: - Helper Functions
private func formatBubbleTime(_ date: Date) -> String {
    MessageBubbleTimeFormatters.timeOnly.string(from: date)
}

private func bubbleTextWithNewlineTime(message: Message, isFromCurrentUser: Bool) -> some View {
    let timeText = Text(formatBubbleTime(message.createdAt))
        .font(.loopedSmallText)
        .foregroundColor(.loopedTextSecondary)

    return VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
        LinkifiedText(
            message.normalizedContent,
            font: .loopedBody,
            textColor: .loopedTextPrimary,
            linkColor: .loopedPrimary
        )
        .multilineTextAlignment(isFromCurrentUser ? .trailing : .leading)
        .fixedSize(horizontal: false, vertical: true)

        timeText
            .opacity(0)
            .accessibilityHidden(true)
    }
    .overlay(alignment: .bottomTrailing) {
        timeText
    }
}

private struct MessageMediaTimeBadge: View {
    let timeText: String

    var body: some View {
        Text(timeText)
            .font(.loopedSmallTextMedium)
            .foregroundColor(.loopedWhite)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.loopedBlack.opacity(0.55))
            )
            .padding(8)
    }
}
