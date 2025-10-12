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
                        let posts = viewModel.userPosts
                        ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                            PostCard(post: post)
                                .padding(.horizontal, 16)
                                .padding(.top, index == 0 ? 0 : 16)
                        }

                        if posts.isEmpty {
                            EmptyPostsListView()
                                .padding(.top, 60)
                        }

                    case .replies:
                        RepliesPlaceholderView()
                            .padding(.top, 60)

                    case .saved:
                        let posts = MockPosts.getSavedPosts()
                        ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                            PostCard(post: post)
                                .padding(.horizontal, 16)
                                .padding(.top, index == 0 ? 0 : 16)
                        }

                        if posts.isEmpty {
                            EmptyPostsListView()
                                .padding(.top, 60)
                        }
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
                ProfileHeaderView(viewModel: viewModel)

                // Stats Section
                ProfileStatsView()

                // Action Buttons
                ProfileActionButtons(viewModel: viewModel)

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
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Profile Avatar with Name and Handle beside it
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: viewModel.user?.profileImageURL ?? "")) { image in
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
                    Text(viewModel.user?.displayName ?? "")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.loopedTextPrimary)

                    Text("@\(viewModel.user?.handle ?? "")")
                        .font(.subheadline)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()
            }

            // Bio - left aligned
            if let bio = viewModel.user?.bio {
                Text(bio)
                    .font(.body)
                    .foregroundColor(.loopedTextPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
    }
}

struct ProfileStatsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Years in Loop and Company - left aligned
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(.loopedTextSecondary)
                        .font(.system(size: 16))
                    
                    Text("2 years in the Loop")
                        .font(.subheadline)
                        .foregroundColor(.loopedTextSecondary)
                    
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    // Google logo placeholder
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text("G")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    Text("Works at Google")
                        .font(.subheadline)
                        .foregroundColor(.loopedTextSecondary)
                    
                    Spacer()
                }
            }
            
            // Follower Stats - left aligned
            HStack(spacing: 16) {
                Text("100")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.loopedTextPrimary)
                +
                Text(" Following")
                    .font(.subheadline)
                    .foregroundColor(.loopedTextSecondary)
                
                Text("123")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.loopedTextPrimary)
                +
                Text(" Followers")
                    .font(.subheadline)
                    .foregroundColor(.loopedTextSecondary)
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

struct ProfileActionButtons: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        HStack(spacing: 64) {
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
                    PostsList(posts: viewModel.userPosts)
                case .replies:
                    RepliesPlaceholderView()
                case .saved:
                    PostsList(posts: MockPosts.getSavedPosts())
                }
            }
        }
        .background(Color.loopedBackground)
    }
}

struct PostsList: View {
    let posts: [Post]
    @EnvironmentObject var commentsManager: CommentsModalManager

    var body: some View {
        if posts.isEmpty {
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
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
                .foregroundColor(.loopedTextSecondary.opacity(0.5))

            Text("No posts yet")
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

#Preview {
    ProfileView()
}
