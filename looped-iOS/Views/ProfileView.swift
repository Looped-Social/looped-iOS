import SwiftUI

enum ProfileTab: String, CaseIterable {
    case posts = "Posts"
    case replies = "Replies"
    case saved = "Saved"
}

struct ProfileView: View {
    @State private var selectedTab: ProfileTab = .posts
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var commentsManager = CommentsModalManager()
    @StateObject private var repliesViewModel = UserRepliesViewModel()
    @StateObject private var savedViewModel = CollectionPostsViewModel(collection: .saved)
    @State private var headerVisible = true
    @State private var lastScrollOffset: CGFloat = 0
    @AppStorage("anonymousMode") private var isAnonymous = false
    @State private var showAnonError = false
    @State private var anonErrorMessage = ""
    @AppStorage("didShowProfileDiscovery") private var didShowProfileDiscovery = false
    @AppStorage("didShowAnonymousModeDiscovery") private var didShowAnonymousModeDiscovery = false
    @State private var profileDiscoveryStep: ProfileDiscoveryStep?
    @State private var anonymousDiscoveryStep: AnonymousModeDiscoveryStep?
    @State private var pendingAnonymousDiscovery = false
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var headerHeight: CGFloat = 300
    @State private var hasActiveVerifications: Bool?
    private let verificationService: CommunityVerificationServiceProtocol = CommunityVerificationService()

    var body: some View {
        ZStack(alignment: .top) {
            // ScrollView with content (bottom layer)
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Content based on selected tab
                    switch selectedTab {
                    case .posts:
                        PostsList(
                            posts: viewModel.userPosts,
                            isLoading: viewModel.isLoadingPosts,
                            onUpdate: { updated in
                                viewModel.updatePost(updated)
                            },
                            onDelete: { deleted in
                                viewModel.removePost(backendId: deleted.backendId)
                            }
                        )
                    case .replies:
                        UserRepliesList(viewModel: repliesViewModel)
                            .padding(.top, 20)

                    case .saved:
                        SavedPostsList(viewModel: savedViewModel)
                            .padding(.top, 20)
                    }

                    // Bottom spacer
                    Color.clear.frame(height: 100)
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.frame(in: .global).minY) { _, newValue in
                                handleScroll(newValue)
                            }
                    }
                )
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: headerHeight)
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
            }
            .background(
                Color.loopedBackground
                    .ignoresSafeArea(.all, edges: .top)
            )
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ProfileHeaderHeightKey.self, value: proxy.size.height)
                }
            )
            .offset(y: headerVisible ? 0 : -headerHeight)
            .opacity(headerVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: headerVisible)
        }
        .overlay(alignment: .topTrailing) {
            if displayProfile?.isCurrentUser ?? true {
                NavigationLink(destination: SettingsView().environmentObject(authViewModel)) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.loopedTextPrimary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Settings")
                .padding(.top, 10)
                .padding(.trailing, 16)
                .coachMarkTarget(.profileSettingsButton)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .environmentObject(commentsManager)
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
        .task {
            await viewModel.loadUserProfile()
            if isAnonymous {
                await viewModel.loadAnonymousProfile()
            }
            await loadVerificationStatus()
            if let userId = viewModel.user?.backendId {
                repliesViewModel.setUser(id: userId)
                if selectedTab == .replies {
                    await repliesViewModel.loadInitial()
                }
                if selectedTab == .saved {
                    await savedViewModel.loadInitial()
                }
            }
        }
        .refreshable {
            await viewModel.loadUserProfile()
            if isAnonymous {
                await viewModel.loadAnonymousProfile()
            }
            await loadVerificationStatus()
            if let userId = viewModel.user?.backendId {
                repliesViewModel.setUser(id: userId)
                if selectedTab == .replies {
                    await repliesViewModel.loadInitial()
                }
                if selectedTab == .saved {
                    await savedViewModel.loadInitial()
                }
            }
        }
        .onAppear {
            headerVisible = true
            lastScrollOffset = 0
            startProfileDiscoveryIfNeeded()
            if isAnonymous {
                queueAnonymousDiscoveryIfNeeded()
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .replies {
                guard repliesViewModel.replies.isEmpty else { return }
                Task { await repliesViewModel.loadInitial() }
            }
            if newValue == .saved {
                guard savedViewModel.posts.isEmpty else { return }
                Task { await savedViewModel.loadInitial() }
            }
        }
        .onChange(of: viewModel.user?.backendId) { _, newValue in
            repliesViewModel.setUser(id: newValue)
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
                if selectedTab == .replies {
                    await repliesViewModel.loadInitial()
                }
                if selectedTab == .saved {
                    await savedViewModel.loadInitial()
                }
                if isAnonymous {
                    queueAnonymousDiscoveryIfNeeded()
                }
            }
        }
        .onPreferenceChange(ProfileHeaderHeightKey.self) { newValue in
            if newValue > 0, abs(newValue - headerHeight) > 1 {
                headerHeight = newValue
            }
        }
        .overlayPreferenceValue(CoachMarkTargetKey.self) { targets in
            if let step = profileDiscoveryStep {
                CoachMarkOverlay(
                    target: step.target,
                    targets: targets,
                    message: step.message,
                    primaryTitle: step.primaryTitle,
                    secondaryTitle: step.secondaryTitle,
                    onPrimary: advanceProfileDiscovery,
                    onSecondary: skipProfileDiscovery
                )
            } else if let step = anonymousDiscoveryStep {
                CoachMarkOverlay(
                    target: step.target,
                    targets: targets,
                    message: step.message,
                    primaryTitle: step.primaryTitle,
                    secondaryTitle: nil,
                    onPrimary: advanceAnonymousDiscovery,
                    onSecondary: nil
                )
            }
        }
        .alert("Anonymous Mode Failed", isPresented: $showAnonError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(anonErrorMessage)
        }
    }

    private func handleScroll(_ offset: CGFloat) {
        let delta = offset - lastScrollOffset

        // Show header when near top
        if offset >= -50 {
            withAnimation(.easeInOut(duration: 0.25)) {
                headerVisible = true
            }
        }
        // Hide when scrolling down significantly
        else if delta < -30 && offset < -100 {
            withAnimation(.easeInOut(duration: 0.25)) {
                headerVisible = false
            }
        }
        // Show when scrolling up significantly
        else if delta > 30 {
            withAnimation(.easeInOut(duration: 0.25)) {
                headerVisible = true
            }
        }

        lastScrollOffset = offset
    }
}

private struct ProfileHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension ProfileView {
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

    func startProfileDiscoveryIfNeeded() {
        guard authViewModel.onboardingComplete else { return }
        guard !didShowProfileDiscovery else { return }
        guard profileDiscoveryStep == nil else { return }
        profileDiscoveryStep = .editProfile
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
        if profileDiscoveryStep == nil {
            anonymousDiscoveryStep = .privacy
        } else {
            pendingAnonymousDiscovery = true
        }
    }

    func showPendingAnonymousDiscoveryIfNeeded() {
        guard pendingAnonymousDiscovery, isAnonymous, !didShowAnonymousModeDiscovery else { return }
        pendingAnonymousDiscovery = false
        anonymousDiscoveryStep = .privacy
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

    var body: some View {
        headerContent
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

    private var headerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(isAnonymous ? Color.loopedSecondary : Color.loopedPrimary)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.loopedSubheadMedium)
                        .foregroundColor(isAnonymous ? .loopedSecondary : .loopedTextPrimary)

                    Text(handle)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()
            }

            if !resolvedBio.isEmpty {
                Text(resolvedBio)
                    .font(.loopedBody)
                    .foregroundColor(isBioAvailable ? .loopedTextPrimary : .loopedTextSecondary)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                if let yearsText = yearsInLoopText, !isAnonymous {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(.loopedTextSecondary)
                            .font(.system(size: 16))

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
                        NavigationLink(destination: UserSettingsView().environmentObject(authViewModel)) {
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
                        NavigationLink(destination: UserSettingsView().environmentObject(authViewModel)) {
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
                    HStack(spacing: 12) {
                        Text("\(followingCount)")
                            .font(.loopedBodyStrong)
                            .foregroundColor(.loopedTextPrimary)
                        Text("Following")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)

                        Text("\(followersCount)")
                            .font(.loopedBodyStrong)
                            .foregroundColor(.loopedTextPrimary)
                        Text("Followers")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)

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
        if let profile = userProfile { return profile.formattedYearsInLoop }
        return nil
    }

    private var followingCount: Int? {
        if let profile = userProfile { return profile.followingCount }
        if isAnonymous { return nil }
        return authViewModel.currentUser?.followingCount
    }

    private var followersCount: Int? {
        if let profile = userProfile { return profile.followersCount }
        if isAnonymous { return nil }
        return authViewModel.currentUser?.followerCount
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
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
    }
}

struct ProfileActionButtons: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    let userProfile: UserProfile?
    @Binding var isAnonymous: Bool

    var body: some View {
        HStack(spacing: 12) {
            if userProfile?.isCurrentUser ?? true {
                NavigationLink(destination: UserSettingsView().environmentObject(authViewModel)) {
                    ProfileActionButton(title: "Edit Profile", style: .outline)
                        .coachMarkTarget(.profileEditButton)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    isAnonymous.toggle()
                }) {
                    ProfileActionButton(
                        title: "Anonymous",
                        style: isAnonymous ? .filled : .outline
                    )
                    .coachMarkTarget(.profileAnonymousButton)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: {
                    // TODO: Implement follow action
                }) {
                    ProfileActionButton(title: "Follow", style: .outline)
                }
                .buttonStyle(PlainButtonStyle())

                if !isAnonymous {
                    Button(action: {
                        // TODO: Implement message action
                    }) {
                        ProfileActionButton(title: "Message", style: .outline)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}

private enum ProfileActionButtonStyle {
    case outline
    case filled
}

private struct ProfileActionButton: View {
    let title: String
    let style: ProfileActionButtonStyle

    var body: some View {
        Text(title)
            .font(.loopedSubBodyMedium)
            .foregroundColor(style == .filled ? .white : .loopedTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Group {
                    if style == .filled {
                        Color.loopedSecondary
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.loopedTextSecondary.opacity(0.3), lineWidth: style == .filled ? 0 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                            .font(.headline)
                            .fontWeight(.medium)
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
                case .posts:
                    PostsList(posts: viewModel.userPosts, isLoading: viewModel.isLoadingPosts)
                case .replies:
                    RepliesPlaceholderView()
                case .saved:
                    SavedPlaceholderView()
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

    var body: some View {
        if viewModel.isLoading && viewModel.posts.isEmpty {
            ProgressView()
                .padding(.top, 60)
        } else if let error = viewModel.errorMessage, viewModel.posts.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.loopedBody)
                    .foregroundColor(.red)
                Button("Retry") {
                    Task { await viewModel.loadInitial() }
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 60)
        } else if viewModel.posts.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "bookmark")
                    .font(.system(size: 48))
                    .foregroundColor(.loopedTextSecondary.opacity(0.5))
                Text("No saved posts yet")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextSecondary)
            }
            .padding(.top, 60)
        } else {
            ForEach(viewModel.posts) { post in
                PostCard(
                    post: post,
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
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .onAppear {
                    Task { await viewModel.loadMoreIfNeeded(currentPost: post) }
                }
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .padding()
            }
        }
    }
}

struct EmptyPostsListView: View {
    var message: String = "No posts yet"
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
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
                .font(.system(size: 48))
                .foregroundColor(.loopedTextSecondary.opacity(0.5))

            Text("Replies coming soon")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground)
    }
}

struct UserRepliesList: View {
    @ObservedObject var viewModel: UserRepliesViewModel
    @EnvironmentObject var commentsManager: CommentsModalManager

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
                        .font(.system(size: 48))
                        .foregroundColor(.loopedTextSecondary.opacity(0.5))

                    Text("No replies yet")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextSecondary)
                }
                .padding(.top, 60)
            } else {
                ForEach(viewModel.replies) { reply in
                    Button(action: {
                        Task { await openReply(reply) }
                    }) {
                        VStack(alignment: .leading, spacing: 10) {
                            if let post = viewModel.postPreview(for: reply) {
                                let preview = post.content.trimmingCharacters(in: .whitespacesAndNewlines)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("In reply to")
                                        .font(.loopedSmallText)
                                        .foregroundColor(.loopedTextSecondary)

                                    Text(preview.isEmpty ? "Post unavailable" : preview)
                                        .font(.loopedSubBodyRegular)
                                        .foregroundColor(.loopedTextSecondary)
                                        .lineLimit(2)
                                }
                                .padding(10)
                                .background(Color.loopedMutedBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }

                            Text(reply.isDeleted ? "Comment deleted" : reply.content)
                                .font(.loopedBody)
                                .foregroundColor(reply.isDeleted ? .loopedTextSecondary : .loopedTextPrimary)
                                .multilineTextAlignment(.leading)

                            Text(reply.createdAt, style: .date)
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .task {
                        await viewModel.loadPostPreview(for: reply)
                        await viewModel.loadMoreIfNeeded(current: reply)
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

    private func openReply(_ reply: Comment) async {
        guard let post = await viewModel.fetchPostForReply(reply) else { return }
        commentsManager.showComments(
            for: post,
            focusCommentId: reply.backendId,
            focusParentId: reply.replyToBackendId
        )
    }
}

struct SavedPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundColor(.loopedTextSecondary.opacity(0.5))

            Text("No saved posts yet")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground)
    }
}

// Preview intentionally omitted; ProfileView depends on live auth/user data.
