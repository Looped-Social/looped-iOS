import SwiftUI

enum UserProfileTab: String, Hashable {
    case content = "Content"
    case reposts = "Reposts"
    case posts = "Posts"
    case replies = "Replies"
}

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.floatingActionButtonState) private var fabState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel: UserProfileViewModel
    @StateObject private var postsViewModel: CollectionPostsViewModel
    @StateObject private var contentViewModel: UserContentViewModel
    @StateObject private var repostsViewModel: CollectionPostsViewModel
    @StateObject private var commentsViewModel = UserCommentsViewModel()
    @StateObject private var commentsManager = CommentsModalManager()
    @State private var selectedTab: UserProfileTab = .content
    @State private var hasLoaded = false
    @State private var canPop = false
    @AppStorage("anonymousMode") private var isAnonymousMode = false
	    @State private var showActionMenu = false
	    @State private var showBlockConfirm = false
	    @State private var blockErrorMessage: String?
	    @State private var isBlocking = false
	    @State private var showChat = false
	    @State private var isStartingConversation = false
	    @State private var startedConversation: Conversation?
	    @State private var messageErrorMessage: String?

	    private let blockService: BlockServiceProtocol = BlockService()
	    private let messageService: MessageServiceProtocol = MessageService()

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
        _contentViewModel = StateObject(wrappedValue: UserContentViewModel(userId: userId))
        _repostsViewModel = StateObject(
            wrappedValue: CollectionPostsViewModel(
                collection: .userReposts(userId: userId)
            )
        )
        _selectedTab = State(initialValue: .content)
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
        _contentViewModel = StateObject(wrappedValue: UserContentViewModel(userId: nil))
        _repostsViewModel = StateObject(
            wrappedValue: CollectionPostsViewModel(
                collection: .anonReposts(profileId: anonProfileId)
            )
        )
        _selectedTab = State(initialValue: .content)
    }

	    var body: some View {
		        profileLayout
		            .background(Color.loopedBackground.ignoresSafeArea())
		            .navigationBarTitleDisplayMode(.inline)
		            .toolbar(.visible, for: .navigationBar)
		            .toolbarBackground(.hidden, for: .navigationBar)
		            .toolbar {
		                if !canPop {
		                    ToolbarItem(placement: .topBarLeading) {
		                        Button(action: { dismiss() }) {
	                            Image(systemName: "xmark")
	                                .font(.loopedCustom(.semibold, size: 16))
	                                .foregroundColor(.loopedTextSecondary)
	                                .frame(width: 44, height: 44)
	                        }
	                        .buttonStyle(.plain)
	                        .accessibilityLabel("Close")
	                    }
	                }

	                if canShowActionMenu {
	                    ToolbarItem(placement: .topBarTrailing) {
	                        Button(action: { showActionMenu = true }) {
	                            Image(systemName: "ellipsis")
	                                .font(.loopedCustom(.medium, size: 18))
	                                .foregroundColor(.loopedTextSecondary)
	                                .frame(width: 44, height: 44)
	                        }
	                        .buttonStyle(.plain)
	                        .accessibilityLabel("More options")
	                    }
	                }
	            }
	            .background(NavigationCanPopReader(canPop: $canPop))
	            .environmentObject(commentsManager)
            .modifier(
                ProfileActionsModifier(
                    canBlockUser: canBlockUser,
                    canBlockPrincipal: canBlockPrincipal,
                    showActionMenu: $showActionMenu,
                    showBlockConfirm: $showBlockConfirm,
                    blockErrorMessage: $blockErrorMessage,
                    isBlocking: isBlocking,
                    blockTargetLabel: blockTargetLabel,
                    onConfirmBlock: { Task { await blockProfileUser() } }
                )
            )
	            .onAppear { fabState.isHidden = true }
	            .onDisappear { fabState.isHidden = false }
	            .overlay(commentsOverlay)
	            .fullScreenCover(isPresented: $showChat) {
	                ChatView(
	                    conversation: startedConversation,
	                    channel: nil,
	                    onBackTapped: {
	                        showChat = false
	                        startedConversation = nil
	                    }
	                )
	            }
	            .alert(
	                "Couldn't start chat",
	                isPresented: Binding(
	                    get: { messageErrorMessage != nil },
	                    set: { if !$0 { messageErrorMessage = nil } }
	                )
	            ) {
	                Button("OK", role: .cancel) { }
            } message: {
                Text(messageErrorMessage ?? "")
            }
	            .alert(
	                "Couldn't update follow",
	                isPresented: Binding(
	                    get: { viewModel.followErrorMessage != nil },
                    set: { if !$0 { viewModel.followErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.followErrorMessage ?? "")
            }
            .onChange(of: selectedTab) { newValue in
                if newValue == .content, contentViewModel.items.isEmpty {
                    Task { await contentViewModel.loadInitial() }
                }
                if newValue == .reposts, repostsViewModel.posts.isEmpty {
                    Task { await repostsViewModel.loadInitial() }
                }
            }
    }

    private var tabs: [UserProfileTab] {
        [.content, .reposts]
    }

	    private var followConfig: ProfileActionButtons.FollowConfig? {
	        guard viewModel.profile != nil else { return nil }
	        guard !viewModel.isAnonymousProfile else { return nil }
	        return ProfileActionButtons.FollowConfig(
	            isFollowing: viewModel.isFollowing,
	            isInFlight: viewModel.isFollowActionInFlight,
	            onToggle: { Task { await viewModel.toggleFollow(asAnonymousActor: isAnonymousMode) } }
	        )
	    }

	    private var messageConfig: ProfileActionButtons.MessageConfig? {
	        guard viewModel.profile?.backendId != nil else { return nil }
	        guard !viewModel.isAnonymousProfile else { return nil }
	        return ProfileActionButtons.MessageConfig(
	            isInFlight: isStartingConversation,
	            onTap: { Task { await startConversationIfPossible() } }
	        )
	    }

    private var profileLayout: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                content
                Color.loopedClear.frame(height: 80)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .task { await loadIfNeeded() }
        .refreshable { await reload() }
    }

    private var commentsOverlay: some View {
        Group {
            if commentsManager.isPresented, let post = commentsManager.currentPost {
                CommentsNavigationHost(post: post) {
                    commentsManager.dismissComments()
                }
                .environmentObject(commentsManager)
                .transition(.move(edge: .trailing))
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
	                UserProfileInfoSection(
	                    userProfile: profile,
	                    isAnonymousMode: $isAnonymousMode,
	                    followConfig: followConfig,
	                    messageConfig: messageConfig
	                )
	                UserProfileTabsView(selectedTab: $selectedTab, tabs: tabs)
	                UserProfileContentView(
	                    userProfile: profile,
	                    selectedTab: selectedTab,
                    contentViewModel: contentViewModel,
                    postsViewModel: postsViewModel,
                    repostsViewModel: repostsViewModel,
                    commentsViewModel: commentsViewModel
                )
            }
            .padding(.top, 12)
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
                contentViewModel.setAnonProfile(id: backendId)
            } else {
                commentsViewModel.setUser(id: backendId)
                contentViewModel.setUser(id: backendId)
            }
        }
        await contentViewModel.loadInitial()
        if selectedTab == .reposts {
            await repostsViewModel.loadInitial()
        }
    }

    private func loadCommentsIfNeeded() async {
        guard commentsViewModel.comments.isEmpty,
              viewModel.profile?.backendId != nil
        else { return }
        await commentsViewModel.loadInitial()
    }

	    private var canShowActionMenu: Bool {
	        canBlockUser || canBlockPrincipal
	    }

	    private var canBlockUser: Bool {
	        guard let profileId = viewModel.profile?.backendId else { return false }
	        if let currentUserId = authViewModel.currentUser?.backendId, currentUserId == profileId {
	            return false
	        }
	        guard !viewModel.isAnonymousProfile else { return false }
	        return true
	    }

	    private var canBlockPrincipal: Bool {
	        guard viewModel.isAnonymousProfile else { return false }
	        guard viewModel.profile?.backendId != nil else { return false }
	        return true
	    }

	    private var blockTargetLabel: String {
	        guard let profile = viewModel.profile else { return "this user" }
	        if profile.isAnonymous {
	            return "this user"
	        }
        return profile.formattedHandle
    }

	    @MainActor
	    private func blockProfileUser() async {
	        guard let profileId = viewModel.profile?.backendId else { return }
	        guard !isBlocking else { return }
	        isBlocking = true
	        defer { isBlocking = false }

	        do {
	            if viewModel.isAnonymousProfile {
	                guard canBlockPrincipal else { return }
	                _ = try await blockService.blockPrincipal(
	                    principalId: profileId,
	                    asAnonymousActor: isAnonymousMode,
	                    communityId: nil
	                )
	            } else {
	                guard canBlockUser else { return }
	                _ = try await blockService.blockUser(userId: profileId, asAnonymousActor: isAnonymousMode, communityId: nil)
	            }
	            NotificationCenter.default.post(name: .contentPreferencesChanged, object: nil)
	            dismiss()
	        } catch {
	            blockErrorMessage = error.localizedDescription
	        }
	    }

	    @MainActor
	    private func startConversationIfPossible() async {
	        guard !isStartingConversation else { return }
	        guard !isAnonymousMode else { return }
	        guard let targetUserId = viewModel.profile?.backendId else { return }
	        if let currentUserId = authViewModel.currentUser?.backendId, currentUserId == targetUserId {
	            return
	        }

	        isStartingConversation = true
	        defer { isStartingConversation = false }

	        do {
	            let conversation = try await messageService.startConversation(with: targetUserId)
	            startedConversation = conversation
	            showChat = true
	        } catch {
	            messageErrorMessage = error.localizedDescription
	        }
	    }
	}

private struct ProfileActionsModifier: ViewModifier {
    let canBlockUser: Bool
    let canBlockPrincipal: Bool
    @Binding var showActionMenu: Bool
    @Binding var showBlockConfirm: Bool
    @Binding var blockErrorMessage: String?
    let isBlocking: Bool
    let blockTargetLabel: String
    let onConfirmBlock: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Profile options", isPresented: $showActionMenu, titleVisibility: .visible) {
                if canBlockUser || canBlockPrincipal {
                    Button("Block User", role: .destructive) {
                        showBlockConfirm = true
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .confirmationDialog("Block user?", isPresented: $showBlockConfirm, titleVisibility: .visible) {
                Button("Block User", role: .destructive) {
                    onConfirmBlock()
                }
                .disabled(isBlocking)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You won't see posts or messages from \(blockTargetLabel) anymore.")
            }
            .alert(
                "Couldn't block user",
                isPresented: Binding(
                    get: { blockErrorMessage != nil },
                    set: { if !$0 { blockErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(blockErrorMessage ?? "")
            }
    }
}

// MARK: - Profile Info Section
struct UserProfileInfoSection: View {
    let userProfile: UserProfile
    @Binding var isAnonymousMode: Bool
    let followConfig: ProfileActionButtons.FollowConfig?
    let messageConfig: ProfileActionButtons.MessageConfig?
    @State private var showAvatarViewer = false

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            statsSection
            ProfileActionButtons(
                userProfile: userProfile,
                isAnonymous: $isAnonymousMode,
                followConfig: followConfig,
                messageConfig: messageConfig
            )
        }
        .fullScreenCover(isPresented: $showAvatarViewer) {
            Group {
                if let avatarViewerUrl {
                    FullScreenImageViewer(
                        imageUrls: [avatarViewerUrl],
                        initialIndex: 0,
                        isPresented: $showAvatarViewer
                    )
                } else {
                    Color.loopedClear
                }
            }
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
                    Group {
                        if let avatarViewerUrl {
                            Button {
                                showAvatarViewer = true
                            } label: {
                                ProfileAvatarView(imageURL: avatarViewerUrl, size: 64)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel("View profile photo")
                        } else {
                            ProfileAvatarView(imageURL: userProfile.profileImageURL, size: 64)
                        }
                    }
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
                } else {
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

    private var avatarViewerUrl: String? {
        guard !userProfile.isAnonymous else { return nil }
        let trimmed = (userProfile.profileImageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return trimmed
    }
}

// MARK: - Tabs
struct UserProfileTabsView: View {
    @Binding var selectedTab: UserProfileTab
    let tabs: [UserProfileTab]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
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
                ForEach(tabs, id: \.self) { tab in
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
    @ObservedObject var contentViewModel: UserContentViewModel
    @ObservedObject var postsViewModel: CollectionPostsViewModel
    @ObservedObject var repostsViewModel: CollectionPostsViewModel
    @ObservedObject var commentsViewModel: UserCommentsViewModel
    @ScaledMetric private var contentTopSpacing: CGFloat = 20

    var body: some View {
        LazyVStack(spacing: 0) {
            Color.loopedClear.frame(height: contentTopSpacing)
            switch selectedTab {
            case .content:
                UserContentList(userProfile: userProfile, viewModel: contentViewModel)
            case .reposts:
                UserPostsList(viewModel: repostsViewModel)
            case .posts:
                UserPostsList(viewModel: postsViewModel)
            case .replies:
                UserCommentsList(userProfile: userProfile, viewModel: commentsViewModel)
            }
        }
    }
}


// MARK: - Content List
struct UserContentList: View {
    let userProfile: UserProfile
    @ObservedObject var viewModel: UserContentViewModel
    @EnvironmentObject var commentsManager: CommentsModalManager
    @State private var showPostUnavailableAlert = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
                    .scaleEffect(1.1)
                    .padding(.top, 32)
            } else if !viewModel.items.isEmpty {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.items) { item in
                        Group {
                            switch item.payload {
                            case .post(let post):
                                PostCard(
                                    post: post,
                                    showsCommunityLabel: true,
                                    onUpdate: { updated in
                                        viewModel.updatePost(updated)
                                    },
                                    onDelete: { deleted in
                                        viewModel.removePost(backendId: deleted.backendId)
                                    }
                                )
                            case .reply(let reply, _):
                                UserContentReplyRow(
                                    reply: reply,
                                    previewText: previewText(for: reply),
                                    onTap: { Task { await openReply(reply) } }
                                )
                                .task {
                                    await viewModel.loadPostPreview(for: reply)
                                }
                            }

                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.loopedTextSecondary.opacity(0.1))
                        }
                        .task { await viewModel.loadMoreIfNeeded(current: item) }
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

                    Text("No content yet")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextSecondary)
                }
                .padding(.top, 60)
            }
        }
        .padding(.bottom, 100)
        .alert("Post unavailable", isPresented: $showPostUnavailableAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This post is no longer available.")
        }
    }

    private func previewText(for reply: UserContentReply) -> String? {
        if let post = viewModel.postPreview(for: reply) {
            let preview = post.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return preview.isEmpty ? "Post unavailable" : preview
        }
        if viewModel.isPostUnavailable(postId: reply.postId) {
            return "Post unavailable"
        }
        return nil
    }

    private func openReply(_ reply: UserContentReply) async {
        if let post = viewModel.postPreview(for: reply) {
            commentsManager.showComments(for: post)
            return
        }
        await viewModel.loadPostPreview(for: reply)
        if let post = viewModel.postPreview(for: reply) {
            commentsManager.showComments(for: post)
            return
        }
        guard viewModel.isPostUnavailable(postId: reply.postId) else { return }
        await MainActor.run {
            showPostUnavailableAlert = true
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
    @State private var showPostUnavailableAlert = false

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
                    let previewText = previewText(for: comment)
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
        .alert("Post unavailable", isPresented: $showPostUnavailableAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This post may be hidden or no longer available.")
        }
    }

    private func previewText(for comment: Comment) -> String? {
        if let post = viewModel.postPreview(for: comment) {
            let preview = post.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return preview.isEmpty ? "Post unavailable" : preview
        }
        if viewModel.isPostUnavailable(postId: comment.postBackendId) {
            return "Post unavailable"
        }
        return nil
    }

    private func openReply(_ comment: Comment) async {
        if let post = await viewModel.fetchPostForReply(comment) {
            commentsManager.showComments(
                for: post,
                focusCommentId: comment.backendId,
                focusParentId: comment.replyToBackendId
            )
            return
        }
        guard viewModel.isPostUnavailable(postId: comment.postBackendId) else { return }
        await MainActor.run {
            showPostUnavailableAlert = true
        }
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

    NavigationStack {
        UserProfileView(userId: 1, preloadedProfile: sampleProfile)
    }
    .environmentObject(AuthViewModel())
    .environmentObject(FeedViewModel())
    .environment(\.floatingActionButtonState, FloatingActionButtonState())
}
