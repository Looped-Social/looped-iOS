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
    @EnvironmentObject private var commentsManager: CommentsModalManager
    @StateObject private var viewModel: UserProfileViewModel
    @StateObject private var postsViewModel: CollectionPostsViewModel
    @StateObject private var contentViewModel: UserContentViewModel
    @StateObject private var repostsViewModel: CollectionPostsViewModel
    @StateObject private var commentsViewModel = UserCommentsViewModel()
    @State private var isAtTop = true
    @State private var refreshIndicatorState: LoopedPullToRefreshIndicatorState?
    @State private var headerHeight: CGFloat = 0
    @State private var headerVisible = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var selectedTab: UserProfileTab = .content
    @State private var hasLoaded = false
    @State private var canPop: Bool?
    @AppStorage("anonymousMode") private var isAnonymousMode = false
    @State private var showBlockConfirm = false
    @State private var blockErrorMessage: String?
    @State private var isBlocking = false
    @State private var showChat = false
    @State private var isStartingConversation = false
	    @State private var startedConversation: Conversation?
	    @State private var messageErrorMessage: String?

	    private let blockService: BlockServiceProtocol = BlockService()
	    private let messageService: MessageServiceProtocol = MessageService()

    private let requestedBackendUserId: Int?

    init(userId: Int, currentUserId: Int? = nil, preloadedProfile: UserProfile? = nil) {
        requestedBackendUserId = userId
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
        requestedBackendUserId = nil
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
        _selectedTab = State(initialValue: .posts)
    }

    var body: some View {
        profileLayout
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { toolbarContent }
            .background(NavigationCanPopReader(canPop: $canPop))
            .modifier(profileActionsModifier)
            .onPreferenceChange(UserProfileHeaderHeightKey.self, perform: handleHeaderHeightChange)
            .onAppear { syncFloatingActionButtonVisibility() }
            .onChange(of: viewModel.profile?.backendId) { _, _ in
                syncFloatingActionButtonVisibility()
            }
            .onChange(of: viewModel.profile?.isCurrentUser) { _, _ in
                syncFloatingActionButtonVisibility()
            }
            .onChange(of: authViewModel.currentUser?.backendId) { _, _ in
                syncFloatingActionButtonVisibility()
            }
            .fullScreenCover(isPresented: $showChat) {
                ChatNavigationHost(conversation: startedConversation, channel: nil) {
                    showChat = false
                    startedConversation = nil
                }
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
            .onChange(of: selectedTab) { _, newValue in
                if newValue == .content, contentViewModel.items.isEmpty {
                    Task { await contentViewModel.loadInitial() }
                }
                if newValue == .posts, postsViewModel.posts.isEmpty {
                    Task { await postsViewModel.loadInitial() }
                }
                if newValue == .reposts, repostsViewModel.posts.isEmpty {
                    Task { await repostsViewModel.loadInitial() }
                }
                if newValue == .replies, commentsViewModel.comments.isEmpty {
                    Task { await loadCommentsIfNeeded() }
                }
            }
            .loopedHashtagNavigationHost()
    }

    private var tabs: [UserProfileTab] {
        if viewModel.isAnonymousProfile {
            return [.posts, .reposts]
        }
        return [.content, .reposts]
    }

    private func syncFloatingActionButtonVisibility() {
        fabState.isHidden = !shouldShowPostButton
    }

    private var shouldShowPostButton: Bool {
        if viewModel.isAnonymousProfile {
            return viewModel.profile?.isCurrentUser == true
        }

        if let requestedBackendUserId,
           let currentBackendId = authViewModel.currentUser?.backendId,
           requestedBackendUserId == currentBackendId {
            return true
        }

        if let profileBackendId = viewModel.profile?.backendId,
           let currentBackendId = authViewModel.currentUser?.backendId,
           profileBackendId == currentBackendId {
            return true
        }

        return viewModel.profile?.isCurrentUser == true
    }

    private var followConfig: ProfileActionButtons.FollowConfig? {
        guard viewModel.profile != nil else { return nil }
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

    private var profileActionsModifier: ProfileActionsModifier {
        ProfileActionsModifier(
            showBlockConfirm: $showBlockConfirm,
            blockErrorMessage: $blockErrorMessage,
            isBlocking: isBlocking,
            blockTargetLabel: blockTargetLabel,
            onConfirmBlock: { Task { await blockProfileUser() } }
        )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if canPop == false {
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
                Menu {
                    if canBlockUser {
                        Button(role: .destructive) {
                            showBlockConfirm = true
                        } label: {
                            Label("Block User", systemImage: "hand.raised")
                        }
                        .disabled(isBlocking)
                    }
                } label: {
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

	    private var profileLayout: some View {
	        ZStack(alignment: .top) {
	            ScrollView {
	                LazyVStack(spacing: 0) {
	                    scrollContent
	                    Color.loopedClear.frame(height: 80)
	                }
	                .background(
	                    GeometryReader { geo in
	                        Color.loopedClear
	                            .onChange(of: geo.frame(in: .global).minY) { _, newValue in
	                                handleScroll(newValue)
	                            }
	                    }
	                )
	            }
	            .background(Color.loopedBackground.ignoresSafeArea())
	            .task { await loadIfNeeded() }
	            .loopedPullToRefresh(
	                isAtTop: isAtTop,
	                showsIndicatorOverlay: false,
	                indicatorState: $refreshIndicatorState
	            ) { await reload() }
	            .safeAreaInset(edge: .top, spacing: 0) {
	                Color.loopedClear.frame(height: headerHeight)
	            }

	            headerOverlay
	        }
	    }

	    @ViewBuilder
	    private var scrollContent: some View {
	        if viewModel.isLoading && viewModel.profile == nil {
	            loadingState
		        } else if let error = viewModel.errorMessage, viewModel.profile == nil {
		            errorState(error)
		        } else if let profile = viewModel.profile {
	            UserProfileContentView(
	                userProfile: profile,
	                selectedTab: selectedTab,
	                contentViewModel: contentViewModel,
	                postsViewModel: postsViewModel,
	                repostsViewModel: repostsViewModel,
	                commentsViewModel: commentsViewModel
	            )
	        } else {
	            Text("Profile unavailable")
	                .font(.loopedBodyMedium)
	                .foregroundColor(.loopedTextSecondary)
	                .padding(.top, 120)
	        }
	    }

	    @ViewBuilder
	    private var headerOverlay: some View {
	        if let profile = viewModel.profile {
	            VStack(spacing: 0) {
	                UserProfileInfoSection(
	                    userProfile: profile,
	                    isAnonymousMode: $isAnonymousMode,
	                    followConfig: followConfig,
	                    messageConfig: messageConfig
	                )
	                UserProfileTabsView(selectedTab: $selectedTab, tabs: tabs)
	                if let state = refreshIndicatorState {
	                    LoopedPullToRefreshIndicator(
	                        fillProgress: state.fillProgress,
	                        stretchProgress: state.stretchProgress,
	                        phase: state.phase
	                    )
	                    .frame(height: 44)
	                    .frame(maxWidth: .infinity)
	                    .padding(.bottom, 6)
	                    .transition(.opacity)
	                }
	            }
	            .padding(.top, 12)
	            .background(Color.loopedBackground.ignoresSafeArea(.all, edges: .top).allowsHitTesting(false))
	            .background(
	                GeometryReader { proxy in
	                    Color.loopedClear.preference(key: UserProfileHeaderHeightKey.self, value: proxy.size.height)
	                }
	            )
                .offset(y: headerVisible ? 0 : -headerHeight)
                .opacity(headerVisible ? 1 : 0)
                .allowsHitTesting(headerVisible)
                .animation(.easeInOut(duration: 0.22), value: headerVisible)
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

	    private func handleHeaderHeightChange(_ newValue: CGFloat) {
	        guard newValue > 0, abs(newValue - headerHeight) > 1 else { return }
	        headerHeight = newValue
	    }

        private func handleScroll(_ offset: CGFloat) {
            let delta = offset - lastScrollOffset

            // At/near top: always show header
            if offset >= -20 {
                if !headerVisible {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        headerVisible = true
                    }
                }
            } else if delta < -2, headerVisible {
                // Any meaningful scroll down collapses
                withAnimation(.easeInOut(duration: 0.22)) {
                    headerVisible = false
                }
            } else if delta > 2, !headerVisible {
                // Any meaningful scroll up expands
                withAnimation(.easeInOut(duration: 0.22)) {
                    headerVisible = true
                }
            }

            isAtTop = offset >= -20
            lastScrollOffset = offset
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
        if selectedTab == .posts {
            await postsViewModel.loadInitial()
        } else {
            await contentViewModel.loadInitial()
        }
        if selectedTab == .replies {
            await loadCommentsIfNeeded()
        }
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
	        canBlockUser
	    }

	    private var canBlockUser: Bool {
	        guard let profileId = viewModel.profile?.backendId else { return false }
	        if let currentUserId = authViewModel.currentUser?.backendId, currentUserId == profileId {
	            return false
	        }
	        guard !viewModel.isAnonymousProfile else { return false }
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
	            guard canBlockUser else { return }
	            _ = try await blockService.blockUser(userId: profileId, asAnonymousActor: isAnonymousMode, communityId: nil)
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
    @Binding var showBlockConfirm: Bool
    @Binding var blockErrorMessage: String?
    let isBlocking: Bool
    let blockTargetLabel: String
    let onConfirmBlock: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Block user?", isPresented: $showBlockConfirm, titleVisibility: .visible) {
                Button("Block User", role: .destructive) {
                    onConfirmBlock()
                }
                .disabled(isBlocking)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You won't see posts from \(blockTargetLabel) anymore.")
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
        let rawBio = userProfile.bio ?? ""
        let trimmed = rawBio.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if userProfile.isCurrentUser {
                return ("No bio yet", true)
            }
            return ("", false)
        }
        return (trimmed, false)
    }

    private var identityTitle: String {
        if userProfile.isAnonymous {
            let trimmedUsername = userProfile.username.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedUsername.isEmpty {
                return trimmedUsername
            }
            return "Anonymous"
        }
        return userProfile.resolvedDisplayName
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if userProfile.isAnonymous {
                    ProfileAvatarView(
                        imageURL: nil,
                        size: 64,
                        variant: .anonymous
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

                VStack(alignment: .leading, spacing: 0) {
                    Text(identityTitle)
                        .font(.loopedHeaderProfile)
                        .foregroundColor(userProfile.isAnonymous ? .loopedSecondary : .loopedTextPrimary)

                    Text(userProfile.formattedHandle)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.top, -2)
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
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(.loopedTextSecondary)
                        .font(.loopedCustom(size: 16))

                    Text(userProfile.formattedYearsInLoop)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)

                    Spacer()
                }

                if userProfile.displaySpecializationLine != nil {
                    UserProfileMembershipLinksRow(
                        specialization: userProfile.displaySpecialization,
                        displayCommunity: userProfile.displayCommunity,
                        fallbackText: "Member"
                    )
                } else {
                    UserProfileMembershipLinksRow(
                        specialization: nil,
                        displayCommunity: userProfile.displayCommunity,
                        fallbackText: "No primary community selected"
                    )
                }
            }

            if userProfile.showFollowerCount {
                HStack(spacing: 16) {
                    if let subject = followListSubject {
                        NavigationLink(destination: UserFollowListView(subject: subject, kind: .followers)) {
                            statLabel(count: userProfile.followersCount, title: "Followers")
                        }
                        .buttonStyle(PlainButtonStyle())

                        NavigationLink(destination: UserFollowListView(subject: subject, kind: .following)) {
                            statLabel(count: userProfile.followingCount, title: "Following")
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        statLabel(count: userProfile.followersCount, title: "Followers")
                        statLabel(count: userProfile.followingCount, title: "Following")
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

    private func statLabel(count: Int, title: String) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedContrast)
            Text(title)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
        }
        .contentShape(Rectangle())
    }

    private var followListSubject: UserFollowListSubject? {
        guard let backendId = userProfile.backendId else { return nil }
        if userProfile.isAnonymous {
            return .anon(anonProfileId: backendId)
        }
        return .user(userId: backendId)
    }
}

private struct UserProfileMembershipLinksRow: View {
    let specialization: DisplayCommunity?
    let displayCommunity: DisplayCommunity?
    let fallbackText: String
    @Environment(\.preferCommunityShortNames) private var preferCommunityShortNames

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconSystemName)
                .foregroundColor(.loopedTextSecondary)
                .font(.loopedCustom(size: 16))

            HStack(spacing: 0) {
                memberLabelView

                if specializationLabel != nil, (displayCommunityLabel != nil || displayCommunity != nil) {
                    Text(" @ ")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .accessibilityHidden(true)

                    if let displayCommunity {
                        NavigationLink(destination: CommunityProfileView(community: CommunityProfileData(displayCommunity: displayCommunity))) {
                            Text(displayCommunityLabel ?? displayCommunity.displayText)
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else if let displayCommunityLabel {
                        Text(displayCommunityLabel)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var memberLabelView: some View {
        if let specialization, let specializationLabel {
            NavigationLink(destination: CommunityProfileView(community: CommunityProfileData(displayCommunity: specialization))) {
                Text(specializationLabel)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }
            .buttonStyle(PlainButtonStyle())
        } else if let displayCommunity, specialization == nil {
            NavigationLink(destination: CommunityProfileView(community: CommunityProfileData(displayCommunity: displayCommunity))) {
                Text(displayCommunityLabel ?? displayCommunity.displayText)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            Text(baseText)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
        }
    }

    private var iconSystemName: String {
        if specialization != nil {
            return specializationLabel == nil ? "graduationcap" : "graduationcap.fill"
        }
        return displayCommunity == nil ? "briefcase" : "briefcase.fill"
    }

    private var baseText: String {
        specializationLabel ?? displayCommunityLabel ?? fallbackText
    }

    private var specializationLabel: String? {
        CommunityLabelText.preferredName(
            preferShortNames: preferCommunityShortNames,
            name: specialization?.name,
            shortName: specialization?.shortName
        )
    }

    private var displayCommunityLabel: String? {
        CommunityLabelText.preferredName(
            preferShortNames: preferCommunityShortNames,
            name: displayCommunity?.name,
            shortName: displayCommunity?.shortName
        )
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
	    var showsLoadMoreIndicator: Bool = true
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

	                    if showsLoadMoreIndicator, viewModel.isLoadingMore {
	                        LoopedInlineLoadingIndicator()
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

private struct UserProfileHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
    .environmentObject(CommentsModalManager())
    .environmentObject(FeedViewModel())
    .environment(\.floatingActionButtonState, FloatingActionButtonState())
}
