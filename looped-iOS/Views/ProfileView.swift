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

    private let headerHeight: CGFloat = 350

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
                ProfileHeaderView(userProfile: viewModel.userProfile)

                // Stats Section
                ProfileStatsView(userProfile: viewModel.userProfile)

                // Action Buttons
                ProfileActionButtons(viewModel: viewModel, userProfile: viewModel.userProfile)

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
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .environmentObject(commentsManager)
        .task {
            await viewModel.loadUserProfile()
        }
        .refreshable {
            await viewModel.loadUserProfile()
        }
        .onAppear {
            headerVisible = true
            lastScrollOffset = 0
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

struct ProfileHeaderView: View {
    let userProfile: UserProfile?
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Profile Avatar with Name and Handle beside it
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: userProfile?.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.loopedTextSecondary.opacity(0.1))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.loopedTextSecondary)
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())

                // Name and Handle beside profile picture
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.loopedTextPrimary)

                    Text(handle)
                        .font(.subheadline)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()
            }

            // Bio - left aligned
            Text(bioPlaceholder)
                .font(.body)
                .foregroundColor(.loopedTextPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
    }

    private var displayName: String {
        userProfile?.displayName ?? authViewModel.currentUser?.displayName ?? "Looped User"
    }

    private var handle: String {
        if let handle = userProfile?.formattedHandle { return handle }
        if let username = authViewModel.currentUser?.username ?? authViewModel.currentUser?.handle {
            return "@\(username)"
        }
        return "@looped"
    }

    private var bioPlaceholder: String {
        if let bio = userProfile?.bio ?? authViewModel.currentUser?.bio, !bio.isEmpty {
            return bio
        }
        return "Add your bio in Settings"
    }
}

struct ProfileStatsView: View {
    let userProfile: UserProfile?
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Years in Loop and Company - left aligned
            if let profile = resolvedProfile {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(.loopedTextSecondary)
                            .font(.system(size: 16))
                        
                        Text(profile.formattedYearsInLoop)
                            .font(.subheadline)
                            .foregroundColor(.loopedTextSecondary)
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.loopedPrimary)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text(String(profile.company.prefix(1)).uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        Text(profile.formattedJobTitle)
                            .font(.subheadline)
                            .foregroundColor(.loopedTextSecondary)
                        
                        Spacer()
                    }
                }
                
                // Follower Stats placeholder
                HStack(spacing: 16) {
                    StatPill(title: "Following", value: profile.followingCount)
                    StatPill(title: "Followers", value: profile.followersCount)
                    Spacer()
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private var resolvedProfile: UserProfile? {
        if let profile = userProfile { return profile }
        if let user = authViewModel.currentUser {
            return UserProfile.from(user: user, isCurrentUser: true)
        }
        return nil
    }
}

private struct StatPill: View {
    let title: String
    let value: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
                .foregroundColor(.loopedTextPrimary)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.loopedMutedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ProfileActionButtons: View {
    @ObservedObject var viewModel: ProfileViewModel
    let userProfile: UserProfile?

    var body: some View {
        HStack(spacing: 64) {
            if userProfile?.isCurrentUser ?? true {
                NavigationLink(destination: EditProfileView(viewModel: viewModel)) {
                    Text("Edit Profile")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.loopedTextPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.loopedTextSecondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())

                NavigationLink(destination: SettingsView()) {
                    Text("Settings")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.loopedTextPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.loopedTextSecondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: {
                    // TODO: Implement follow action
                }) {
                    Text("Follow")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.loopedTextPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.loopedTextSecondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    // TODO: Implement message action
                }) {
                    Text("Message")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.loopedTextPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.loopedTextSecondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 10)
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
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
