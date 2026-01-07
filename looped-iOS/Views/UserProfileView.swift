import SwiftUI

enum UserProfileTab: String, CaseIterable {
    case posts = "Posts"
    case replies = "Replies"
}

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.floatingActionButtonState) private var fabState
    @StateObject private var viewModel: UserProfileViewModel
    @StateObject private var postsViewModel: CollectionPostsViewModel
    @StateObject private var commentsViewModel = UserCommentsViewModel()
    @StateObject private var commentsManager = CommentsModalManager()
    @State private var selectedTab: UserProfileTab = .posts
    @State private var hasLoaded = false
    @State private var overlayHeaderHeight: CGFloat = 0
    @AppStorage("anonymousMode") private var isAnonymousMode = false

    init(userId: Int, currentUserId: Int? = nil, preloadedProfile: UserProfile? = nil) {
        _viewModel = StateObject(
            wrappedValue: UserProfileViewModel(
                source: .user(id: userId),
                currentUserId: currentUserId,
                initialProfile: preloadedProfile
            )
        )
        _postsViewModel = StateObject(
            wrappedValue: CollectionPostsViewModel(
                collection: .user(userId: userId)
            )
        )
    }

    init(anonProfileId: Int, preloadedProfile: UserProfile? = nil) {
        _viewModel = StateObject(
            wrappedValue: UserProfileViewModel(
                source: .anon(id: anonProfileId),
                initialProfile: preloadedProfile
            )
        )
        _postsViewModel = StateObject(
            wrappedValue: CollectionPostsViewModel(
                collection: .anon(profileId: anonProfileId)
            )
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    content
                    Color.loopedClear.frame(height: 80)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.loopedClear.frame(height: overlayHeaderHeight)
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .task { await loadIfNeeded() }
            .refreshable { await reload() }

            UserProfileHeader {
                dismiss()
            }
            .background(
                GeometryReader { proxy in
                    Color.loopedClear.preference(key: UserProfileHeaderHeightKey.self, value: proxy.size.height)
                }
            )
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .environmentObject(commentsManager)
        .onAppear {
            fabState.isHidden = true
        }
        .onDisappear {
            fabState.isHidden = false
        }
        .overlay(
            Group {
                if commentsManager.isPresented, let post = commentsManager.currentPost {
                    CommentsView(post: post) {
                        commentsManager.dismissComments()
                    }
                    .environmentObject(commentsManager)
                    .transition(.move(edge: .trailing))
                }
            }
        )
        .onChange(of: selectedTab) { newValue in
            if newValue == .replies {
                Task { await loadCommentsIfNeeded() }
            }
        }
        .onPreferenceChange(UserProfileHeaderHeightKey.self) { newValue in
            if newValue > 0, abs(newValue - overlayHeaderHeight) > 1 {
                overlayHeaderHeight = newValue
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.profile == nil {
            loadingState
        } else if let error = viewModel.errorMessage, viewModel.profile == nil {
            errorState(error)
        } else if let profile = viewModel.profile {
            VStack(spacing: 0) {
                UserProfileInfoSection(userProfile: profile, isAnonymousMode: $isAnonymousMode)
                UserProfileTabsView(selectedTab: $selectedTab)
                UserProfileContentView(
                    userProfile: profile,
                    selectedTab: selectedTab,
                    postsViewModel: postsViewModel,
                    commentsViewModel: commentsViewModel
                )
            }
        } else {
            Text("Profile unavailable")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)
                .padding(.top, 120)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading profile...")
                .font(.loopedBody)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(.top, 80)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await reload()
                }
            }
            .font(.loopedBodyMedium)
            .foregroundColor(.loopedPrimary)
        }
        .padding(.top, 80)
        .padding(.horizontal, 24)
    }

    private func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await reload()
    }

    private func reload() async {
        await viewModel.loadProfile()
        if let backendId = viewModel.profile?.backendId {
            if viewModel.isAnonymousProfile {
                commentsViewModel.setAnonProfile(id: backendId)
            } else {
                commentsViewModel.setUser(id: backendId)
            }
        }
        await postsViewModel.loadInitial()
        if selectedTab == .replies {
            await loadCommentsIfNeeded()
        }
    }

    private func loadCommentsIfNeeded() async {
        guard commentsViewModel.comments.isEmpty,
              viewModel.profile?.backendId != nil
        else { return }
        await commentsViewModel.loadInitial()
    }
}

// MARK: - Header
struct UserProfileHeader: View {
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.loopedCustom(.medium, size: 18))
                        .foregroundColor(.loopedPrimary)

                    Text("Back")
                        .font(.loopedBody)
                        .foregroundColor(.loopedPrimary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.loopedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.loopedTextSecondary, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
    }
}

// MARK: - Profile Info Section
struct UserProfileInfoSection: View {
    let userProfile: UserProfile
    @Binding var isAnonymousMode: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            statsSection
            ProfileActionButtons(userProfile: userProfile, isAnonymous: $isAnonymousMode)
        }
    }

    private var bioDisplay: (text: String, isPlaceholder: Bool) {
        if userProfile.isAnonymous {
            return ("", false)
        }
        let rawBio = userProfile.bio ?? ""
        let trimmed = rawBio.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ("No bio yet", true)
        }
        return (trimmed, false)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if userProfile.isAnonymous {
                    Circle()
                        .fill(Color.loopedSecondary)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.loopedCustom(.semibold, size: 28))
                                .foregroundColor(.loopedWhite)
                        )
                } else {
                    ProfileAvatarView(imageURL: userProfile.profileImageURL, size: 64)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(userProfile.resolvedDisplayName)
                        .font(.loopedHeaderProfile)
                        .foregroundColor(userProfile.isAnonymous ? .loopedSecondary : .loopedTextPrimary)

                    Text(userProfile.formattedHandle)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()
            }

            if !bioDisplay.text.isEmpty {
                Text(bioDisplay.text)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                if !userProfile.isAnonymous {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(.loopedTextSecondary)
                            .font(.loopedCustom(size: 16))

                        Text(userProfile.formattedYearsInLoop)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)

                        Spacer()
                    }
                }

                if userProfile.displaySpecializationLine != nil {
                    DisplaySpecializationRow(
                        specialization: userProfile.displaySpecialization,
                        displayCommunity: userProfile.displayCommunity,
                        fallbackText: "Member",
                        font: .loopedSubBodyRegular,
                        textColor: .loopedTextSecondary,
                        iconSize: 16
                    )
                } else if !userProfile.isAnonymous || userProfile.displayCommunity != nil {
                    DisplayCommunityRow(
                        displayCommunity: userProfile.displayCommunity,
                        fallbackText: "No primary community selected",
                        font: .loopedSubBodyRegular,
                        textColor: .loopedTextSecondary,
                        iconSize: 16
                    )
                }
            }

            if userProfile.showFollowerCount {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("\(userProfile.followingCount)")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedContrast)
                        Text("Following")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                    }

                    HStack(spacing: 4) {
                        Text("\(userProfile.followersCount)")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedContrast)
                        Text("Followers")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                    }

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Tabs
struct UserProfileTabsView: View {
    @Binding var selectedTab: UserProfileTab

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(UserProfileTab.allCases, id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        Text(tab.rawValue)
                            .font(selectedTab == tab ? .loopedSubBodyBold : .loopedSubBodyMedium)
                            .foregroundColor(selectedTab == tab ? .loopedPrimary : .loopedTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)

            HStack(spacing: 0) {
                ForEach(UserProfileTab.allCases, id: \.self) { tab in
                    Rectangle()
                        .frame(height: selectedTab == tab ? 2 : 1)
                        .foregroundColor(selectedTab == tab ? .loopedPrimary : .loopedTextSecondary.opacity(0.3))
                }
            }
        }
        .background(Color.loopedBackground)
    }
}

// MARK: - Content
struct UserProfileContentView: View {
    let userProfile: UserProfile
    let selectedTab: UserProfileTab
    @ObservedObject var postsViewModel: CollectionPostsViewModel
    @ObservedObject var commentsViewModel: UserCommentsViewModel
    @ScaledMetric private var contentTopSpacing: CGFloat = 20

    var body: some View {
        LazyVStack(spacing: 0) {
            Color.loopedClear.frame(height: contentTopSpacing)
            switch selectedTab {
            case .posts:
                UserPostsList(viewModel: postsViewModel)
            case .replies:
                UserCommentsList(userProfile: userProfile, viewModel: commentsViewModel)
            }
        }
    }
}


// MARK: - Posts List
struct UserPostsList: View {
    @ObservedObject var viewModel: CollectionPostsViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.1)
                    .padding(.top, 32)
            } else if !viewModel.posts.isEmpty {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.posts) { post in
                        PostCard(
                            post: post,
                            showsCommunityLabel: true,
                            onBookmarkToggle: { isSaved in
                                viewModel.handleBookmarkChange(for: post, isSaved: isSaved)
                            },
                            onUpdate: { updated in
                                viewModel.updatePost(updated)
                            },
                            onDelete: { deleted in
                                viewModel.removePost(backendId: deleted.backendId)
                            }
                        )
                        .task {
                            await viewModel.loadMoreIfNeeded(currentPost: post)
                        }

                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.loopedTextSecondary.opacity(0.1))
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .padding(.vertical, 16)
                    }
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Text(error)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)

                    Button("Retry") {
                        Task { await viewModel.loadInitial() }
                    }
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedPrimary)
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "text.bubble")
                        .font(.loopedCustom(size: 48))
                        .foregroundColor(.loopedTextSecondary.opacity(0.5))

                    Text("No posts yet")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextSecondary)
                }
                .padding(.top, 60)
            }
        }
        .padding(.bottom, 100)
    }
}

// MARK: - Comments List
struct UserCommentsList: View {
    let userProfile: UserProfile
    @ObservedObject var viewModel: UserCommentsViewModel
    @EnvironmentObject var commentsManager: CommentsModalManager

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading && viewModel.comments.isEmpty {
                ProgressView()
                    .scaleEffect(1.1)
                    .padding(.top, 32)
            } else if let error = viewModel.errorMessage, viewModel.comments.isEmpty {
                VStack(spacing: 8) {
                    Text(error)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)

                    Button("Retry") {
                        Task { await viewModel.loadInitial() }
                    }
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedPrimary)
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
            } else if viewModel.comments.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.loopedCustom(size: 48))
                        .foregroundColor(.loopedTextSecondary.opacity(0.5))

                    Text("No replies yet")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextSecondary)
                }
                .padding(.top, 60)
            } else {
                ForEach(viewModel.comments) { comment in
                    let previewText = previewText(for: viewModel.postPreview(for: comment))
                    ProfileReplyRow(comment: comment, previewText: previewText) {
                        Task { await openReply(comment) }
                    }
                    .task {
                        await viewModel.loadPostPreview(for: comment)
                        await viewModel.loadMoreIfNeeded(current: comment)
                    }

                    Divider()
                        .padding(.leading, 16)
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 16)
                }
            }
        }
        .padding(.bottom, 80)
    }

    private func previewText(for post: Post?) -> String? {
        guard let post else { return nil }
        let preview = post.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.isEmpty ? "Post unavailable" : preview
    }

    private func openReply(_ comment: Comment) async {
        guard let post = await viewModel.fetchPostForReply(comment) else { return }
        commentsManager.showComments(
            for: post,
            focusCommentId: comment.backendId,
            focusParentId: comment.replyToBackendId
        )
    }
}

#Preview {
    let sampleProfile = UserProfile(
        id: UUID(),
        backendId: 1,
        username: "sample",
        displayName: "Sample User",
        handle: "sample",
        company: "Looped",
        jobTitle: "Team Member",
        bio: "Profile preview",
        profileImageURL: nil,
        isVerified: true,
        isAnonymous: false,
        yearsInLoop: 1,
        followingCount: 0,
        followersCount: 0,
        postsCount: 0,
        commentsCount: 0,
        showFollowerCount: true,
        isCurrentUser: false,
        displayCommunity: nil,
        displaySpecialization: nil,
        createdAt: Date(),
        updatedAt: Date()
    )

    NavigationView {
        UserProfileView(userId: 1, preloadedProfile: sampleProfile)
    }
    .environmentObject(AuthViewModel())
    .environmentObject(FeedViewModel())
    .environment(\.floatingActionButtonState, FloatingActionButtonState())
}

private struct UserProfileHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
