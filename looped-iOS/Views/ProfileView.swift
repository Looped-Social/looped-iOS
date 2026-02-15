import SwiftUI

enum ProfileTab: String, CaseIterable {
    case content = "Content"
    case saved = "Saved"
    case reposts = "Reposts"
}

struct ProfileView: View {
    @Environment(\.floatingActionButtonState) private var fabState
    @State private var selectedTab: ProfileTab = .content
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var contentViewModel = UserContentViewModel()
    @StateObject private var savedViewModel = CollectionPostsViewModel(collection: .saved)
    @StateObject private var repostsViewModel = CollectionPostsViewModel(collection: .myReposts)
    @State private var headerVisible = true
    @State private var isAtTop = true
    @AppStorage("anonymousMode") private var isAnonymous = false
    @State private var showAnonError = false
    @State private var anonErrorMessage = ""
    @AppStorage("didShowProfileDiscovery") private var didShowProfileDiscovery = false
    @AppStorage("didShowAnonymousModeDiscovery") private var didShowAnonymousModeDiscovery = false
    @State private var profileDiscoveryStep: ProfileDiscoveryStep?
    @State private var anonymousDiscoveryStep: AnonymousModeDiscoveryStep?
    @State private var pendingAnonymousDiscovery = false
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var coachMarkPresenter: CoachMarkPresenter
    @EnvironmentObject private var commentsManager: CommentsModalManager
    @Environment(\.loopedPresentMainOverlay) private var presentMainOverlay
    @State private var refreshIndicatorState: LoopedPullToRefreshIndicatorState?

		@State private var headerHeight: CGFloat = 300
		@State private var hasActiveVerifications: Bool?
	private let verificationService: CommunityVerificationServiceProtocol = CommunityVerificationService()
    private let anonService: AnonService = .shared
    private let scrollCoordinateSpace = "profileScrollCoordinateSpace"

	private var isShowingDiscoveryOverlay: Bool {
		profileDiscoveryStep != nil || anonymousDiscoveryStep != nil
	}

		var body: some View {
			ZStack(alignment: .top) {
            // ScrollView with content (bottom layer)
			            ScrollView {
			                LazyVStack(spacing: 0) {
			                    // Content based on selected tab
			                    switch selectedTab {
		                        case .content:
		                            if let profile = displayProfile {
		                                UserContentList(
		                                    userProfile: profile,
		                                    viewModel: contentViewModel,
		                                    showsLoadMoreIndicator: false
		                                )
		                            } else if viewModel.isLoading {
		                                ProgressView()
		                                    .padding(.top, 60)
		                            } else {
                                EmptyPostsListView(message: "No content yet")
                                    .padding(.top, 60)
                            }
		                    case .saved:
		                        SavedPostsList(viewModel: savedViewModel, showsLoadMoreIndicator: false)
		                            .padding(.top, 20)
		                    case .reposts:
		                        RepostedPostsList(viewModel: repostsViewModel, showsLoadMoreIndicator: false)
		                            .padding(.top, 20)
		                    }

	                    // Bottom spacer
	                    Color.loopedClear.frame(height: 100)
                }
	                .background(
	                    GeometryReader { geo in
	                        Color.loopedClear
	                            .onChange(of: geo.frame(in: .named(scrollCoordinateSpace)).minY) { oldValue, newValue in
	                                guard abs(newValue - oldValue) > 0.5 else { return }
	                                handleScroll(oldOffset: oldValue, newOffset: newValue)
	                            }
	                    }
	                )
	            }
                    .coordinateSpace(name: scrollCoordinateSpace)
			            .loopedPullToRefresh(
			                isAtTop: isAtTop,
			                indicatorTopPadding: headerVisible ? headerHeight + 14 : 16,
		                showsIndicatorOverlay: false,
		                indicatorState: $refreshIndicatorState
		            ) {
		                await refreshAll()
		            }
	            .safeAreaInset(edge: .top, spacing: 0) {
	                Color.loopedClear.frame(height: headerHeight)
	            }
	            .background(Color.loopedBackground.ignoresSafeArea())

            // Fixed collapsible header (middle layer)
            VStack(spacing: 0) {
                // Profile Header
                ProfileHeaderView(
                    userProfile: displayProfile,
                    isLoading: viewModel.isLoading,
                    errorMessage: viewModel.errorMessage,
                    isAnonymous: isAnonymous,
                    anonHandle: viewModel.anonProfile?.formattedHandle
                )

                // Stats Section
                ProfileStatsView(
                    userProfile: displayProfile,
                    isLoading: viewModel.isLoading,
                    isAnonymous: isAnonymous,
                    hasActiveVerifications: hasActiveVerifications
                )
                .coachMarkTarget(.profileStats)

                // Action Buttons
                ProfileActionButtons(
                    userProfile: displayProfile,
                    isAnonymous: $isAnonymous
                )

                // Tab Navigation
                ProfileTabsView(selectedTab: $selectedTab)

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
            .background(
                Color.loopedBackground
                    .ignoresSafeArea(.all, edges: .top)
                    .allowsHitTesting(false)
            )
            .background(
                GeometryReader { proxy in
                    Color.loopedClear.preference(key: ProfileHeaderHeightKey.self, value: proxy.size.height)
                }
            )
            .offset(y: headerVisible ? 0 : -headerHeight)
            .opacity(headerVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: headerVisible)
        }
			.overlay(alignment: .topTrailing) {
				if displayProfile?.isCurrentUser ?? true {
					Button(action: { presentMainOverlay(.settings) }) {
						Image(systemName: "gearshape.fill")
							.font(.loopedCustom(.semibold, size: 18))
							.foregroundColor(.loopedTextSecondary)
							.frame(width: 28, height: 28)
							.loopedTapTarget()
							.coachMarkTarget(.profileSettingsButton)
					}
					.buttonStyle(PlainButtonStyle())
					.accessibilityLabel("Settings")
					.padding(.top, 16)
					.padding(.trailing, 16)
				}
			}
	        .background(Color.loopedBackground.ignoresSafeArea())
	        .navigationBarHidden(true)
		        .task { await refreshAll() }
	        .onAppear {
                fabState.isHidden = false
	            headerVisible = true
	            startProfileDiscoveryIfNeeded()
            if isAnonymous {
                queueAnonymousDiscoveryIfNeeded()
            }
            syncCoachMarkOverlay()
        }
	        .onChange(of: selectedTab) { _, newValue in
                if newValue == .content {
                    guard contentViewModel.items.isEmpty else { return }
                    Task { await contentViewModel.loadInitial() }
                }
	            if newValue == .saved {
	                guard savedViewModel.posts.isEmpty else { return }
	                Task { await savedViewModel.loadInitial() }
	            }
	            if newValue == .reposts {
	                guard repostsViewModel.posts.isEmpty else { return }
	                Task { await repostsViewModel.loadInitial() }
	            }
	        }
	        .onChange(of: isAnonymous) { _, newValue in
	            Task {
	                await viewModel.handleAnonymousModeChange(isEnabled: newValue)
	                if let error = viewModel.anonErrorMessage, newValue {
	                    anonErrorMessage = error
	                    showAnonError = true
	                    isAnonymous = false
	                }
	                await loadVerificationStatus()
	                await viewModel.loadUserPosts()
                    await updateContentTarget()
                    if selectedTab == .content {
                        await contentViewModel.loadInitial()
                    }
	                if selectedTab == .saved {
	                    await savedViewModel.loadInitial()
	                }
	                if selectedTab == .reposts {
	                    await repostsViewModel.loadInitial()
	                }
	                if isAnonymous {
	                    queueAnonymousDiscoveryIfNeeded()
	                }
	            }
	        }
        .onChange(of: profileDiscoveryStep) { _, _ in
            syncCoachMarkOverlay()
        }
        .onChange(of: anonymousDiscoveryStep) { _, _ in
            syncCoachMarkOverlay()
        }
        .onPreferenceChange(ProfileHeaderHeightKey.self) { newValue in
            if newValue > 0, abs(newValue - headerHeight) > 1 {
                headerHeight = newValue
            }
		}
        .alert("Anonymous Mode Failed", isPresented: $showAnonError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(anonErrorMessage)
        }
	        .onDisappear {
	            coachMarkPresenter.dismissIfSource(.profile)
	        }
            .loopedHashtagNavigationHost()
            .loopedMentionNavigationHost()
		    }

				private func handleScroll(oldOffset: CGFloat, newOffset: CGFloat) {
					guard !isShowingDiscoveryOverlay else {
						if !headerVisible {
							withAnimation(.easeInOut(duration: 0.25)) {
								headerVisible = true
							}
						}
                        let atTop = newOffset >= -50
                        if atTop != isAtTop {
                            isAtTop = atTop
                        }
						return
					}

                    let delta = newOffset - oldOffset
                    var nextHeaderVisible: Bool?

                    if newOffset >= -50 {
                        nextHeaderVisible = true
                    } else if delta < -2 {
                        nextHeaderVisible = false
                    } else if delta > 2 {
                        nextHeaderVisible = true
                    }

                    if let nextHeaderVisible, nextHeaderVisible != headerVisible {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            headerVisible = nextHeaderVisible
                        }
                    }

                    let atTop = newOffset >= -50
                    if atTop != isAtTop {
                        isAtTop = atTop
                    }
                }
		}

private struct ProfileHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension ProfileView {
    func refreshAll() async {
        await viewModel.loadUserProfile()
        if isAnonymous {
            await viewModel.loadAnonymousProfile()
        }
        await loadVerificationStatus()
        await updateContentTarget()
        if selectedTab == .content {
            await contentViewModel.loadInitial()
        }
        if selectedTab == .saved {
            await savedViewModel.loadInitial()
        }
        if selectedTab == .reposts {
            await repostsViewModel.loadInitial()
        }
    }

    func loadVerificationStatus() async {
        guard !isAnonymous else {
            hasActiveVerifications = nil
            return
        }
        do {
            let items = try await verificationService.fetchCommunityVerifications()
            hasActiveVerifications = items.contains { $0.isActive }
        } catch {
            hasActiveVerifications = nil
        }
    }

    var displayProfile: UserProfile? {
        if isAnonymous, let anonProfile = viewModel.anonProfile {
            let companyName = viewModel.user?.companyName ?? viewModel.user?.company
            return anonProfile.asUserProfile(companyName: companyName)
        }
        return viewModel.userProfile
    }

    func updateContentTarget() async {
        if isAnonymous {
            let identity = await anonService.currentIdentity()
            contentViewModel.setAnonProfile(id: identity?.profileId)
        } else {
            contentViewModel.setCurrentUser(userId: viewModel.user?.backendId)
        }
    }

	func startProfileDiscoveryIfNeeded() {
		guard authViewModel.onboardingComplete else { return }
		guard !didShowProfileDiscovery else { return }
		guard profileDiscoveryStep == nil else { return }
		DispatchQueue.main.async {
			guard profileDiscoveryStep == nil else { return }
			headerVisible = true
			profileDiscoveryStep = .editProfile
		}
	}

    func advanceProfileDiscovery() {
        guard let step = profileDiscoveryStep else { return }
        if let next = ProfileDiscoveryStep(rawValue: step.rawValue + 1) {
            profileDiscoveryStep = next
        } else {
            didShowProfileDiscovery = true
            profileDiscoveryStep = nil
            showPendingAnonymousDiscoveryIfNeeded()
        }
    }

    func skipProfileDiscovery() {
        didShowProfileDiscovery = true
        profileDiscoveryStep = nil
        showPendingAnonymousDiscoveryIfNeeded()
    }

	func queueAnonymousDiscoveryIfNeeded() {
		guard !didShowAnonymousModeDiscovery else { return }
		headerVisible = true
		if profileDiscoveryStep == nil {
			anonymousDiscoveryStep = .privacy
		} else {
			pendingAnonymousDiscovery = true
		}
	}

	func showPendingAnonymousDiscoveryIfNeeded() {
		guard pendingAnonymousDiscovery, isAnonymous, !didShowAnonymousModeDiscovery else { return }
		pendingAnonymousDiscovery = false
		headerVisible = true
		anonymousDiscoveryStep = .privacy
	}

    func syncCoachMarkOverlay() {
        if let step = profileDiscoveryStep {
            coachMarkPresenter.show(
                CoachMarkPresenter.Overlay(
                    source: .profile,
                    target: step.target,
                    message: step.message,
                    primaryTitle: step.primaryTitle,
                    secondaryTitle: step.secondaryTitle,
                    onPrimary: advanceProfileDiscovery,
                    onSecondary: skipProfileDiscovery
                )
            )
            return
        }

        if let step = anonymousDiscoveryStep {
            coachMarkPresenter.show(
                CoachMarkPresenter.Overlay(
                    source: .profile,
                    target: step.target,
                    message: step.message,
                    primaryTitle: step.primaryTitle,
                    secondaryTitle: nil,
                    onPrimary: advanceAnonymousDiscovery,
                    onSecondary: nil
                )
            )
            return
        }

        coachMarkPresenter.dismissIfSource(.profile)
    }

    func advanceAnonymousDiscovery() {
        guard let step = anonymousDiscoveryStep else { return }
        if let next = AnonymousModeDiscoveryStep(rawValue: step.rawValue + 1) {
            anonymousDiscoveryStep = next
        } else {
            didShowAnonymousModeDiscovery = true
            anonymousDiscoveryStep = nil
            pendingAnonymousDiscovery = false
        }
    }

    enum ProfileDiscoveryStep: Int, CaseIterable {
        case editProfile
        case anonymousMode

        var target: CoachMarkTarget {
            switch self {
            case .editProfile:
                return .profileEditButton
            case .anonymousMode:
                return .profileAnonymousButton
            }
        }

        var message: String {
            switch self {
            case .editProfile:
                return "Edit your profile details any time."
            case .anonymousMode:
                return "Tap Anonymous to toggle anonymous mode."
            }
        }

        var primaryTitle: String {
            switch self {
            case .editProfile:
                return "Next"
            case .anonymousMode:
                return "Got it"
            }
        }

        var secondaryTitle: String? {
            switch self {
            case .editProfile:
                return "Skip"
            case .anonymousMode:
                return nil
            }
        }
    }

    enum AnonymousModeDiscoveryStep: Int, CaseIterable {
        case privacy
        case backup

        var target: CoachMarkTarget {
            switch self {
            case .privacy:
                return .profileAnonymousButton
            case .backup:
                return .profileSettingsButton
            }
        }

        var message: String {
            switch self {
            case .privacy:
                return "You're in anonymous mode. Your real name and account aren't linked."
            case .backup:
                return "Back up your anonymous profile in Settings > Anonymous Recovery."
            }
        }

        var primaryTitle: String {
            switch self {
            case .privacy:
                return "Next"
            case .backup:
                return "Got it"
            }
        }
    }
}

struct ProfileHeaderView: View {
    let userProfile: UserProfile?
    let isLoading: Bool
    let errorMessage: String?
    let isAnonymous: Bool
    let anonHandle: String?
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showAvatarViewer = false

    var body: some View {
        headerContent
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

    private var displayName: String {
        if isAnonymous { return "Anonymous" }
        return resolvedProfile?.resolvedDisplayName ?? "Looped User"
    }

    private var handle: String {
        if isAnonymous {
            let trimmed = (anonHandle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "@anonymous" }
            return trimmed.hasPrefix("@") ? trimmed : "@\(trimmed)"
        }
        if let handle = resolvedProfile?.formattedHandle { return handle }
        if let username = authViewModel.currentUser?.username ?? authViewModel.currentUser?.handle {
            let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
            return "@\(trimmed.isEmpty ? "looped" : trimmed)"
        }
        return "@looped"
    }

    private var resolvedProfile: UserProfile? {
        if let profile = userProfile { return profile }
        if isAnonymous { return nil }
        if let user = authViewModel.currentUser {
            return UserProfile.from(user: user, isCurrentUser: true)
        }
        return nil
    }

    private var resolvedBio: String {
        if isAnonymous { return "" }
        if let error = errorMessage, !error.isEmpty {
            return "No bio yet"
        }
        let rawBio = userProfile?.bio ?? authViewModel.currentUser?.bio ?? ""
        let trimmed = rawBio.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No bio yet" : trimmed
    }

    private var isBioAvailable: Bool {
        let trimmed = resolvedBio.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "No bio yet"
    }

    private var avatarViewerUrl: String? {
        guard !isAnonymous else { return nil }
        let trimmed = (resolvedProfile?.profileImageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return trimmed
    }

    private var headerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Group {
                    if isAnonymous {
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
                                ProfileAvatarView(imageURL: resolvedProfile?.profileImageURL, size: 64)
                            }
                        }
                    }
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 0) {
                    Text(displayName)
                        .font(.loopedHeaderProfile)
                        .foregroundColor(isAnonymous ? .loopedSecondary : .loopedTextPrimary)

                    Text(handle)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.top, -2)
                }

                Spacer()
            }

            if !resolvedBio.isEmpty {
                Text(resolvedBio)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
    }
}

struct ProfileStatsView: View {
    let userProfile: UserProfile?
    let isLoading: Bool
    let isAnonymous: Bool
    let hasActiveVerifications: Bool?
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.loopedPresentMainOverlay) private var presentMainOverlay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                if let yearsText = yearsInLoopText, !isAnonymous {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(.loopedTextSecondary)
                            .font(.loopedCustom(size: 16))

                        Text(yearsText)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)

                        Spacer()
                    }
                } else if !isAnonymous {
                    Text("Years in the Loop not available")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }

                if displaySpecializationLine != nil {
                    if canSelectDisplayCommunity {
                        Button(action: { presentMainOverlay(.editProfile) }) {
                            DisplaySpecializationRow(
                                specialization: displaySpecialization,
                                displayCommunity: displayCommunity,
                                fallbackText: "Member",
                                font: .loopedSubBodyRegular,
                                textColor: .loopedTextSecondary,
                                iconSize: 16
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        DisplaySpecializationRow(
                            specialization: displaySpecialization,
                            displayCommunity: displayCommunity,
                            fallbackText: "Member",
                            font: .loopedSubBodyRegular,
                            textColor: .loopedTextSecondary,
                            iconSize: 16
                        )
                    }
                } else if shouldShowDisplayCommunityRow {
                    if canSelectDisplayCommunity {
                        Button(action: { presentMainOverlay(.editProfile) }) {
                            DisplayCommunityRow(
                                displayCommunity: displayCommunity,
                                fallbackText: displayCommunityFallbackText,
                                font: .loopedSubBodyRegular,
                                textColor: .loopedTextSecondary,
                                iconSize: 16
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        DisplayCommunityRow(
                            displayCommunity: displayCommunity,
                            fallbackText: displayCommunityFallbackText,
                            font: .loopedSubBodyRegular,
                            textColor: .loopedTextSecondary,
                            iconSize: 16
                        )
                    }
                }
            }

            if showFollowerStats {
                if let followingCount = followingCount, let followersCount = followersCount {
                    HStack(spacing: 16) {
                        if let subject = followListSubject {
                            NavigationLink(destination: UserFollowListView(subject: subject, kind: .followers)) {
                                statLabel(count: followersCount, title: "Followers")
                            }
                            .buttonStyle(PlainButtonStyle())

                            NavigationLink(destination: UserFollowListView(subject: subject, kind: .following)) {
                                statLabel(count: followingCount, title: "Following")
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            statLabel(count: followersCount, title: "Followers")
                            statLabel(count: followingCount, title: "Following")
                        }

                        Spacer()
                    }
                } else {
                    Text("Follower stats not available")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var resolvedProfile: UserProfile? {
        if let profile = userProfile { return profile }
        if isAnonymous { return nil }
        if let user = authViewModel.currentUser {
            return UserProfile.from(user: user, isCurrentUser: true)
        }
        return nil
    }

    private var displayCommunity: DisplayCommunity? {
        if let profile = userProfile { return profile.displayCommunity }
        return authViewModel.currentUser?.displayCommunity
    }

    private var displaySpecialization: DisplayCommunity? {
        resolvedProfile?.displaySpecialization
    }

    private var displaySpecializationLine: String? {
        resolvedProfile?.displaySpecializationLine
    }

    private var displayCommunityFallbackText: String {
        if isAnonymous {
            return "Select a community to show on your anonymous profile"
        }
        if let hasActiveVerifications {
            return hasActiveVerifications ? "Select a primary community" : "Verify a community to show it here"
        }
        return "Select a primary community"
    }

	    private var yearsInLoopText: String? {
	        guard !isAnonymous else { return nil }
	        return resolvedProfile?.formattedYearsInLoop
	    }

	    private var followingCount: Int? {
	        if let profile = userProfile { return profile.followingCount }
	        if isAnonymous { return nil }
	        return authViewModel.currentUser?.followingCount ?? 0
	    }

	    private var followersCount: Int? {
	        if let profile = userProfile { return profile.followersCount }
	        if isAnonymous { return nil }
	        return authViewModel.currentUser?.followerCount ?? 0
	    }

    private var showFollowerStats: Bool {
        if isAnonymous { return true }
        if let profile = userProfile { return profile.showFollowerCount }
        return authViewModel.currentUser?.showFollowerCount ?? true
    }

    private var canSelectDisplayCommunity: Bool {
        if let profile = userProfile { return profile.isCurrentUser }
        return true
    }

    private var shouldShowDisplayCommunityRow: Bool {
        if let profile = userProfile {
            if profile.isAnonymous {
                return profile.displayCommunity != nil || profile.isCurrentUser
            }
            return true
        }
        return !isAnonymous
    }

    private func statLabel(count: Int, title: String) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedContrast)
            Text(title)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
        }
        .contentShape(Rectangle())
    }

    private var followListSubject: UserFollowListSubject? {
        if isAnonymous {
            guard let anonProfileId = userProfile?.backendId else { return nil }
            return .anon(anonProfileId: anonProfileId)
        }
        guard let userId = userProfile?.backendId ?? authViewModel.currentUser?.backendId else { return nil }
        return .user(userId: userId)
    }
}

private struct CompanyIconView: View {
    let company: String

    private var usesGoogleLogo: Bool {
        company.lowercased().contains("google")
    }

    var body: some View {
        Group {
            if usesGoogleLogo {
                Image("google-logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
            } else {
                Circle()
                    .fill(Color.loopedPrimary)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Text(String(company.prefix(1)).uppercased())
                            .font(.loopedCustom(.bold, size: 10))
                            .foregroundColor(.loopedWhite)
                    )
            }
        }
    }
}

	struct ProfileActionButtons: View {
	    struct FollowConfig {
	        let isFollowing: Bool
	        let isInFlight: Bool
	        let onToggle: () -> Void
	    }

	    struct MessageConfig {
	        let isInFlight: Bool
	        let onTap: () -> Void
	    }

		    @EnvironmentObject private var authViewModel: AuthViewModel
		    @Environment(\.loopedPresentMainOverlay) private var presentMainOverlay
		    let userProfile: UserProfile?
		    @Binding var isAnonymous: Bool
		    let followConfig: FollowConfig?
		    let messageConfig: MessageConfig?

	    init(
	        userProfile: UserProfile?,
	        isAnonymous: Binding<Bool>,
	        followConfig: FollowConfig? = nil,
	        messageConfig: MessageConfig? = nil
	    ) {
	        self.userProfile = userProfile
	        self._isAnonymous = isAnonymous
	        self.followConfig = followConfig
	        self.messageConfig = messageConfig
	    }

	    var body: some View {
	        HStack(spacing: 12) {
	            if isCurrentUser {
	                Button(action: { presentMainOverlay(.editProfile) }) {
                        PillButtonLabel(
                            title: "Edit Profile",
                            variant: .muted,
                            size: .profile,
                            fillWidth: true
                        )
                        .coachMarkTarget(.profileEditButton)
	                }
	                .buttonStyle(PlainButtonStyle())
	                .frame(maxWidth: .infinity, alignment: .center)

                Button(action: {
                    isAnonymous.toggle()
                }) {
                    PillButtonLabel(
                        title: "Anonymous",
                        variant: isAnonymous ? .secondary : .muted,
                        size: .profile,
                        fillWidth: true
                    )
                    .coachMarkTarget(.profileAnonymousButton)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity, alignment: .center)
	            } else {
	                Button(action: {
	                    followConfig?.onToggle()
	                }) {
                        FollowPillButtonLabel(
                            title: followButtonTitle,
                            isFollowing: followConfig?.isFollowing == true,
                            size: .profile,
                            fillWidth: true,
                            isEnabled: followConfig != nil && followConfig?.isInFlight != true,
                            showsLoadingIndicator: followConfig?.isInFlight == true
                        )
	                }
	                .buttonStyle(PlainButtonStyle())
	                .disabled(isFollowDisabled)
	                .opacity(isFollowDisabled ? 0.7 : 1)
	                .frame(maxWidth: .infinity, alignment: .center)

	                if !isAnonymous {
	                    Button(action: {
	                        messageConfig?.onTap()
	                    }) {
                            PillButtonLabel(
                                title: "Message",
                                variant: .muted,
                                size: .profile,
                                fillWidth: true,
                                isEnabled: messageConfig != nil && messageConfig?.isInFlight != true,
                                showsLoadingIndicator: messageConfig?.isInFlight == true
                            )
	                    }
	                    .buttonStyle(PlainButtonStyle())
	                    .disabled(isMessageDisabled)
	                    .opacity(isMessageDisabled ? 0.7 : 1)
	                    .frame(maxWidth: .infinity, alignment: .center)
	                }
	            }
	        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var isCurrentUser: Bool {
        if let userProfile {
            // Anonymous profile IDs are a separate namespace from user IDs.
            // Trust the backend-derived ownership flag to avoid false "self" matches.
            if userProfile.isAnonymous {
                return userProfile.isCurrentUser
            }
            if userProfile.isCurrentUser {
                return true
            }
        }

        guard let profileId = userProfile?.backendId else { return true }
        if let currentUserId = authViewModel.currentUser?.backendId {
            return profileId == currentUserId
        }
        return false
    }

	    private var isFollowDisabled: Bool {
	        followConfig == nil || followConfig?.isInFlight == true
	    }

	    private var isMessageDisabled: Bool {
	        messageConfig == nil || messageConfig?.isInFlight == true
	    }

    private var followButtonTitle: String {
        followConfig?.isFollowing == true ? "Following" : "Follow"
    }
	}

struct ProfileTabsView: View {
    @Binding var selectedTab: ProfileTab
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
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
            
            // Full-width underlines
            HStack(spacing: 0) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Rectangle()
                        .frame(height: selectedTab == tab ? 2 : 1)
                        .foregroundColor(selectedTab == tab ? .loopedPrimary : .loopedTextSecondary.opacity(0.3))
                }
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea(.all, edges: .horizontal))
    }
}

struct ProfileContentView: View {
    let selectedTab: ProfileTab
    @ObservedObject var viewModel: ProfileViewModel
    @EnvironmentObject var commentsManager: CommentsModalManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                switch selectedTab {
                case .content:
                    PostsList(posts: viewModel.userPosts, isLoading: viewModel.isLoadingPosts)
                case .saved:
                    SavedPlaceholderView()
                case .reposts:
                    RepostsPlaceholderView()
                }
            }
        }
        .background(Color.loopedBackground)
    }
}

struct PostsList: View {
    let posts: [Post]
    var isLoading: Bool = false
    let onUpdate: ((Post) -> Void)?
    let onDelete: ((Post) -> Void)?
    @EnvironmentObject var commentsManager: CommentsModalManager

    init(
        posts: [Post],
        isLoading: Bool = false,
        onUpdate: ((Post) -> Void)? = nil,
        onDelete: ((Post) -> Void)? = nil
    ) {
        self.posts = posts
        self.isLoading = isLoading
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }

    var body: some View {
        if isLoading {
            ProgressView()
                .padding(.top, 60)
        } else if posts.isEmpty {
            EmptyPostsListView()
                .padding(.top, 60)
        } else {
            ForEach(posts) { post in
                PostCard(
                    post: post,
                    showsCommunityLabel: true,
                    onUpdate: onUpdate,
                    onDelete: onDelete
                )

                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.loopedTextSecondary.opacity(0.1))
            }
        }
    }
}

struct SavedPostsList: View {
    @ObservedObject var viewModel: CollectionPostsViewModel
    @EnvironmentObject var commentsManager: CommentsModalManager
    var showsLoadMoreIndicator: Bool = true

    var body: some View {
        if viewModel.isLoading && viewModel.posts.isEmpty {
            ProgressView()
                .padding(.top, 60)
        } else if let error = viewModel.errorMessage, viewModel.posts.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.loopedBody)
                    .foregroundColor(.loopedError)
                Button("Retry") {
                    Task { await viewModel.loadInitial() }
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 60)
        } else if viewModel.posts.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "bookmark")
                    .font(.loopedCustom(size: 48))
                    .foregroundColor(.loopedTextSecondary.opacity(0.5))
                Text("No saved posts yet")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextSecondary)
            }
            .padding(.top, 60)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.posts) { post in
                    PostCard(
                        post: post,
                        showsCommunityLabel: true,
                        onBookmarkToggle: { saved in
                            viewModel.handleBookmarkChange(for: post, isSaved: saved)
                        },
                        onUpdate: { updated in
                            viewModel.updatePost(updated)
                        },
                        onDelete: { deleted in
                            viewModel.removePost(backendId: deleted.backendId)
                        }
                    )
                    .onAppear {
                        Task { await viewModel.loadMoreIfNeeded(currentPost: post) }
                    }

                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.loopedTextSecondary.opacity(0.1))
                }

	                if showsLoadMoreIndicator, viewModel.isLoadingMore {
	                    LoopedInlineLoadingIndicator()
	                }
	            }
	        }
	    }
	}

struct RepostedPostsList: View {
    @ObservedObject var viewModel: CollectionPostsViewModel
    @EnvironmentObject var commentsManager: CommentsModalManager
    var showsLoadMoreIndicator: Bool = true

    var body: some View {
        if viewModel.isLoading && viewModel.posts.isEmpty {
            ProgressView()
                .padding(.top, 60)
        } else if let error = viewModel.errorMessage, viewModel.posts.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.loopedBody)
                    .foregroundColor(.loopedError)
                Button("Retry") {
                    Task { await viewModel.loadInitial() }
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 60)
        } else if viewModel.posts.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "arrow.2.squarepath")
                    .font(.loopedCustom(size: 48))
                    .foregroundColor(.loopedTextSecondary.opacity(0.5))
                Text("No reposts yet")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextSecondary)
            }
            .padding(.top, 60)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.posts) { post in
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
                    .onAppear {
                        Task { await viewModel.loadMoreIfNeeded(currentPost: post) }
                    }

                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.loopedTextSecondary.opacity(0.1))
                }

	                if showsLoadMoreIndicator, viewModel.isLoadingMore {
	                    LoopedInlineLoadingIndicator()
	                }
	            }
	        }
	    }
	}

struct EmptyPostsListView: View {
    var message: String = "No posts yet"
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.loopedCustom(size: 48))
                .foregroundColor(.loopedTextSecondary.opacity(0.5))

            Text(message)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RepliesPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.loopedCustom(size: 48))
                .foregroundColor(.loopedTextSecondary.opacity(0.5))

            Text("Replies coming soon")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground)
    }
}

private struct ProfileCombinedContentList: View {
    enum Payload {
        case post(Post)
        case reply(Comment)
    }

    struct Item: Identifiable {
        let id: String
        let createdAt: Date
        let payload: Payload
        let sortPriority: Int
    }

    let posts: [Post]
    let isLoadingPosts: Bool
    @ObservedObject var repliesViewModel: UserRepliesViewModel
    let onUpdatePost: (Post) -> Void
    let onDeletePost: (Post) -> Void

    @EnvironmentObject var commentsManager: CommentsModalManager
    @State private var showPostUnavailableAlert = false

    var body: some View {
        VStack(spacing: 16) {
            if isInitialLoading {
                ProgressView()
                    .scaleEffect(1.1)
                    .padding(.top, 32)
            } else if let errorMessage, items.isEmpty {
                VStack(spacing: 8) {
                    Text(errorMessage)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)

                    Button("Retry") {
                        Task { await repliesViewModel.loadInitial() }
                    }
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedPrimary)
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
            } else if items.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "text.bubble")
                        .font(.loopedCustom(size: 48))
                        .foregroundColor(.loopedTextSecondary.opacity(0.5))

                    Text("No content yet")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextSecondary)
                }
                .padding(.top, 60)
            } else {
                ForEach(items) { item in
                    Group {
                        switch item.payload {
                        case .post(let post):
                            PostCard(
                                post: post,
                                showsCommunityLabel: true,
                                onUpdate: onUpdatePost,
                                onDelete: onDeletePost
                            )
                        case .reply(let reply):
                            UserContentReplyRow(
                                reply: UserContentReply(comment: reply),
                                previewText: previewText(for: reply),
                                onTap: { Task { await openReply(reply) } }
                            )
                            .task {
                                await repliesViewModel.loadPostPreview(for: reply)
                                await repliesViewModel.loadMoreIfNeeded(current: reply)
                            }
                        }

                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.loopedTextSecondary.opacity(0.1))
                    }
                }

                if repliesViewModel.isLoadingMore {
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

    private var isInitialLoading: Bool {
        items.isEmpty && (isLoadingPosts || repliesViewModel.isLoading)
    }

    private var errorMessage: String? {
        if let message = repliesViewModel.errorMessage, !message.isEmpty {
            return message
        }
        return nil
    }

    private var items: [Item] {
        let postItems: [Item] = posts.map { post in
            let stableId = post.backendId.map(String.init) ?? post.id.uuidString
            return Item(
                id: "post-\(stableId)",
                createdAt: post.createdAt,
                payload: .post(post),
                sortPriority: 0
            )
        }
        let replyItems: [Item] = repliesViewModel.replies.map { reply in
            let stableId = reply.backendId.map(String.init) ?? reply.id.uuidString
            return Item(
                id: "reply-\(stableId)",
                createdAt: reply.createdAt,
                payload: .reply(reply),
                sortPriority: 1
            )
        }
        return (postItems + replyItems).sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            if lhs.sortPriority != rhs.sortPriority { return lhs.sortPriority < rhs.sortPriority }
            return lhs.id < rhs.id
        }
    }

    private func previewText(for reply: Comment) -> String? {
        if let post = repliesViewModel.postPreview(for: reply) {
            let preview = post.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return preview.isEmpty ? "Post unavailable" : preview
        }
        if repliesViewModel.isPostUnavailable(postId: reply.postBackendId) {
            return "Post unavailable"
        }
        return nil
    }

    private func openReply(_ reply: Comment) async {
        if let post = await repliesViewModel.fetchPostForReply(reply) {
            commentsManager.showComments(
                for: post,
                focusCommentId: reply.backendId,
                focusParentId: reply.replyToBackendId
            )
            return
        }
        guard repliesViewModel.isPostUnavailable(postId: reply.postBackendId) else { return }
        await MainActor.run {
            showPostUnavailableAlert = true
        }
    }
}

struct UserRepliesList: View {
    @ObservedObject var viewModel: UserRepliesViewModel
    @EnvironmentObject var commentsManager: CommentsModalManager
    @State private var showPostUnavailableAlert = false

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading && viewModel.replies.isEmpty {
                ProgressView()
                    .scaleEffect(1.1)
                    .padding(.top, 32)
            } else if let error = viewModel.errorMessage, viewModel.replies.isEmpty {
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
            } else if viewModel.replies.isEmpty {
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
                ForEach(viewModel.replies) { reply in
                    let previewText = previewText(for: reply)
                    ProfileReplyRow(comment: reply, previewText: previewText) {
                        Task { await openReply(reply) }
                    }
                    .task {
                        await viewModel.loadPostPreview(for: reply)
                        await viewModel.loadMoreIfNeeded(current: reply)
                    }

                    Rectangle()
                        .fill(Color.loopedTextSecondary.opacity(0.25))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
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

    private func previewText(for reply: Comment) -> String? {
        if let post = viewModel.postPreview(for: reply) {
            let preview = post.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return preview.isEmpty ? "Post unavailable" : preview
        }
        if viewModel.isPostUnavailable(postId: reply.postBackendId) {
            return "Post unavailable"
        }
        return nil
    }

    private func openReply(_ reply: Comment) async {
        if let post = await viewModel.fetchPostForReply(reply) {
            commentsManager.showComments(
                for: post,
                focusCommentId: reply.backendId,
                focusParentId: reply.replyToBackendId
            )
            return
        }
        guard viewModel.isPostUnavailable(postId: reply.postBackendId) else { return }
        await MainActor.run {
            showPostUnavailableAlert = true
        }
    }
}

struct SavedPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.loopedCustom(size: 48))
                .foregroundColor(.loopedTextSecondary.opacity(0.5))

            Text("No saved posts yet")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground)
    }
}

struct RepostsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.2.squarepath")
                .font(.loopedCustom(size: 48))
                .foregroundColor(.loopedTextSecondary.opacity(0.5))

            Text("No reposts yet")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground)
    }
}

// Preview intentionally omitted; ProfileView depends on live auth/user data.
