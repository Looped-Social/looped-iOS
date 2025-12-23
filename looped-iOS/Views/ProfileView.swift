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
    @State private var headerVisible = true
    @State private var lastScrollOffset: CGFloat = 0
    @AppStorage("anonymousMode") private var isAnonymous = false
    @State private var showAnonError = false
    @State private var anonErrorMessage = ""
    @EnvironmentObject private var authViewModel: AuthViewModel

    private let headerHeight: CGFloat = 300

    var body: some View {
        ZStack(alignment: .top) {
            // ScrollView with content (bottom layer)
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Content based on selected tab
                    switch selectedTab {
                    case .posts:
                        PostsList(posts: viewModel.userPosts, isLoading: viewModel.isLoadingPosts)
                    case .replies:
                        RepliesPlaceholderView()
                            .padding(.top, 60)

                    case .saved:
                        SavedPlaceholderView()
                            .padding(.top, 60)
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
                    isAnonymous: isAnonymous
                )

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
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .environmentObject(commentsManager)
        .task {
            await viewModel.loadUserProfile()
            if isAnonymous {
                await viewModel.loadAnonymousProfile()
            }
        }
        .refreshable {
            await viewModel.loadUserProfile()
            if isAnonymous {
                await viewModel.loadAnonymousProfile()
            }
        }
        .onAppear {
            headerVisible = true
            lastScrollOffset = 0
        }
        .onChange(of: isAnonymous) { _, newValue in
            Task {
                await viewModel.handleAnonymousModeChange(isEnabled: newValue)
                if let error = viewModel.anonErrorMessage, newValue {
                    anonErrorMessage = error
                    showAnonError = true
                    isAnonymous = false
                }
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

private extension ProfileView {
    var displayProfile: UserProfile? {
        if isAnonymous, let anonProfile = viewModel.anonProfile {
            let companyName = viewModel.user?.companyName ?? viewModel.user?.company
            return anonProfile.asUserProfile(companyName: companyName)
        }
        return viewModel.userProfile
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
            return "Bio not available"
        }
        let rawBio = userProfile?.bio ?? authViewModel.currentUser?.bio ?? ""
        let trimmed = rawBio.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Bio not available" : trimmed
    }

    private var isBioAvailable: Bool {
        let trimmed = resolvedBio.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "Bio not available"
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

                if let companyName = companyName {
                    HStack(spacing: 8) {
                        CompanyIconView(company: companyName)

                        Text("Works at \(companyName)")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)

                        Spacer()
                    }
                } else {
                    Text("Workplace not available")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
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

    private var companyName: String? {
        let rawCompany = userProfile?.company ?? (isAnonymous ? "" : (authViewModel.currentUser?.companyName ?? ""))
        let trimmed = rawCompany.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
        if isAnonymous { return false }
        if let profile = userProfile { return profile.showFollowerCount }
        return authViewModel.currentUser?.showFollowerCount ?? true
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
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    isAnonymous.toggle()
                }) {
                    ProfileActionButton(
                        title: "Anonymous",
                        style: isAnonymous ? .filled : .outline
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: {
                    // TODO: Implement follow action
                }) {
                    ProfileActionButton(title: "Follow", style: .outline)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    // TODO: Implement message action
                }) {
                    ProfileActionButton(title: "Message", style: .outline)
                }
                .buttonStyle(PlainButtonStyle())
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
    @EnvironmentObject var commentsManager: CommentsModalManager

    var body: some View {
        if isLoading {
            ProgressView()
                .padding(.top, 60)
        } else if posts.isEmpty {
            EmptyPostsListView()
                .padding(.top, 60)
        } else {
            ForEach(posts) { post in
                PostCard(post: post)

                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.loopedTextSecondary.opacity(0.1))
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

struct SavedPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundColor(.loopedTextSecondary.opacity(0.5))

            Text("Saved posts coming soon")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground)
    }
}

// Preview intentionally omitted; ProfileView depends on live auth/user data.
