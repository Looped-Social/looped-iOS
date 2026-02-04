import SwiftUI

final class PostActionBarState: ObservableObject {
    @Published var likeCount: Int = 0
    @Published var commentCount: Int = 0
    @Published var shareCount: Int = 0
    @Published var isLiked: Bool = false
    @Published var isReposted: Bool = false
    @Published var isSaved: Bool = false
    @Published var isRepostLoading: Bool = false
    @Published var isBookmarkLoading: Bool = false
    @Published var isPreparingShareSheet: Bool = false
    @Published var isReactionLocked: Bool = false
}

struct PostActionBarConfig {
    let state: PostActionBarState
    let onLike: () -> Void
    let onComment: () -> Void
    let onRepost: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
}

struct PostActionBarCompact: View {
    @ObservedObject private var state: PostActionBarState
    private let onLike: () -> Void
    private let onComment: () -> Void
    private let onRepost: () -> Void
    private let onShare: () -> Void
    private let onSave: () -> Void
    private let sizeScale: CGFloat

    private var iconSize: CGFloat { 16 * sizeScale }
    private var itemSpacing: CGFloat { 12 * sizeScale }
    private var labelSpacing: CGFloat { 4 * sizeScale }
    private var countFontSize: CGFloat { 12 * sizeScale }
    private var lockFontSize: CGFloat { 8 * sizeScale }
    private var lockPadding: CGFloat { 2 * sizeScale }
    private var lockOffset: CGFloat { 6 * sizeScale }

    init(config: PostActionBarConfig, sizeScale: CGFloat = 1.0) {
        _state = ObservedObject(wrappedValue: config.state)
        onLike = config.onLike
        onComment = config.onComment
        onRepost = config.onRepost
        onShare = config.onShare
        onSave = config.onSave
        self.sizeScale = max(sizeScale, 0.75)
    }

    var body: some View {
        HStack(spacing: itemSpacing) {
            actionButton(
                icon: Image(systemName: state.isLiked ? "heart.fill" : "heart"),
                count: state.likeCount,
                tint: state.isLiked ? .loopedError : .loopedWhite,
                disabled: false,
                action: onLike,
                showsLock: state.isReactionLocked
            )

            actionButton(
                icon: Image("comment-icon"),
                count: state.commentCount,
                tint: .loopedWhite,
                disabled: false,
                action: onComment
            )

            actionButton(
                icon: Image(systemName: "arrow.2.squarepath"),
                count: nil,
                tint: state.isReposted ? .loopedPrimary : .loopedWhite,
                disabled: state.isRepostLoading,
                action: onRepost
            )

            actionButton(
                icon: Image("send-icon-fab"),
                count: state.shareCount,
                tint: .loopedWhite,
                disabled: state.isPreparingShareSheet,
                action: onShare
            )

            Spacer(minLength: 0)

            actionButton(
                icon: Image(state.isSaved ? "saved-icon" : "save-icon"),
                count: nil,
                tint: state.isSaved ? .loopedPrimary : .loopedWhite,
                disabled: state.isBookmarkLoading,
                action: onSave
            )
        }
        .font(.loopedSmallText)
        .foregroundColor(.loopedWhite)
    }

    @ViewBuilder
    private func actionButton(
        icon: Image,
        count: Int?,
        tint: Color,
        disabled: Bool,
        action: @escaping () -> Void,
        showsLock: Bool = false
    ) -> some View {
        Button(action: action) {
            HStack(spacing: labelSpacing) {
                ZStack(alignment: .topTrailing) {
                    icon
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .foregroundColor(tint)

                    if showsLock {
                        Image(systemName: "lock.fill")
                            .font(.loopedCustom(.bold, size: lockFontSize))
                            .foregroundColor(.loopedWhite.opacity(0.8))
                            .padding(lockPadding)
                            .background(Circle().fill(Color.loopedBlack.opacity(0.6)))
                            .offset(x: lockOffset, y: -lockOffset)
                    }
                }

                if let count {
                    Text("\(max(count, 0))")
                        .font(.loopedCustom(size: countFontSize))
                        .foregroundColor(.loopedWhite.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.6 : 1)
    }
}
