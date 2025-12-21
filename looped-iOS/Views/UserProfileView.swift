import SwiftUI

enum UserProfileTab: String, CaseIterable {
    case posts = "Posts"
    case comments = "Comments"
}

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: UserProfileViewModel
    @StateObject private var postsViewModel: CollectionPostsViewModel
    @StateObject private var commentsViewModel = UserCommentsViewModel()
    @StateObject private var commentsManager = CommentsModalManager()
    @State private var selectedTab: UserProfileTab = .posts
    @State private var hasLoaded = false

    init(userId: Int, currentUserId: Int? = nil, preloadedProfile: UserProfile? = nil) {
        _viewModel = StateObject(
            wrappedValue: UserProfileViewModel(
                userId: userId,
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

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    content
                    Color.clear.frame(height: 80)
                }
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .task { await loadIfNeeded() }
            .refreshable { await reload() }

            VStack {
                UserProfileHeader {
                    dismiss()
                }
                Spacer()
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .environmentObject(commentsManager)
        .overlay(
            Group {
                if commentsManager.isPresented {
                    commentsModalOverlay
                }
            }
        )
        .onChange(of: selectedTab) { newValue in
            if newValue == .comments {
                Task { await loadCommentsIfNeeded() }
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
                UserProfileInfoSection(userProfile: profile)
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
            commentsViewModel.setUser(id: backendId)
        }
        await postsViewModel.loadInitial()
        if selectedTab == .comments {
            await loadCommentsIfNeeded()
        }
    }

    private func loadCommentsIfNeeded() async {
        guard commentsViewModel.comments.isEmpty, viewModel.profile?.backendId != nil else { return }
        await commentsViewModel.loadInitial()
    }

    private var commentsModalOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    commentsManager.dismissComments()
                }

            VStack(spacing: 0) {
                Spacer()

                if let post = commentsManager.currentPost {
                    VStack(spacing: 0) {
                        SimplifiedPostCard(post: post)

                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.loopedTextSecondary.opacity(0.1))
                    }
                    .background(Color.loopedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.loopedTextSecondary.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    if let post = commentsManager.currentPost {
                        CommentsView(
                            post: post
                        ) {
                            commentsManager.dismissComments()
                        }
                        .environmentObject(commentsManager)
                    }
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.75)
                .background(Color.loopedBackground)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
            }
            .transition(.move(edge: .bottom))
        }
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
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.loopedPrimary)

                    Text("Back")
                        .font(.loopedBody)
                        .foregroundColor(.loopedPrimary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

// MARK: - Profile Info Section
struct UserProfileInfoSection: View {
    let userProfile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: userProfile.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.loopedTextSecondary.opacity(0.1))
                        .overlay(
                            Image("profile-icon")
                                .renderingMode(.template)
                                .font(.system(size: 32))
                                .foregroundColor(.loopedTextSecondary)
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(userProfile.resolvedDisplayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.loopedTextPrimary)

                    Text(userProfile.formattedHandle)
                        .font(.subheadline)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Text(userProfile.formattedJobTitle)
                    .font(.subheadline)
                    .foregroundColor(.loopedTextSecondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.loopedTextSecondary)

                Spacer()
            }

            Text(bioDisplay.text)
                .font(.body)
                .foregroundColor(bioDisplay.isPlaceholder ? .loopedTextSecondary : .loopedTextPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(.loopedTextSecondary)
                        .font(.system(size: 16))

                    Text(userProfile.formattedYearsInLoop)
                        .font(.subheadline)
                        .foregroundColor(.loopedTextSecondary)

                    Spacer()
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.loopedPrimary)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text(String(userProfile.resolvedCompany.prefix(1)).uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )

                    Text("Works at \(userProfile.resolvedCompany)")
                        .font(.subheadline)
                        .foregroundColor(.loopedTextSecondary)

                    Spacer()
                }
            }

            HStack(spacing: 16) {
                Text("\(userProfile.followingCount)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.loopedTextPrimary)
                +
                Text(" Following")
                    .font(.subheadline)
                    .foregroundColor(.loopedTextSecondary)

                Text("\(userProfile.followersCount)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.loopedTextPrimary)
                +
                Text(" Followers")
                    .font(.subheadline)
                    .foregroundColor(.loopedTextSecondary)

                Spacer()
            }

            UserProfileActionButtons(userProfile: userProfile)
        }
        .padding(.horizontal, 16)
        .padding(.top, 50)
        .padding(.bottom, 20)
    }

    private var bioDisplay: (text: String, isPlaceholder: Bool) {
        let rawBio = userProfile.bio ?? ""
        let trimmed = rawBio.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ("No bio yet", true)
        }
        return (trimmed, false)
    }
}

// MARK: - Action Buttons
struct UserProfileActionButtons: View {
    let userProfile: UserProfile
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                // TODO: Handle edit profile / follow
            }) {
                Text(userProfile.isCurrentUser ? "Edit Profile" : "Follow")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.loopedTextPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.loopedTextSecondary.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())

            if userProfile.isCurrentUser {
                NavigationLink(destination: SettingsView().environmentObject(authViewModel)) {
                    Text("Settings")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.loopedTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.loopedTextSecondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: {
                    // TODO: Handle message
                }) {
                    Text("Message")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.loopedTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.loopedTextSecondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 8)
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

    var body: some View {
        LazyVStack(spacing: 0) {
            switch selectedTab {
            case .posts:
                UserPostsList(viewModel: postsViewModel)
            case .comments:
                UserCommentsList(userProfile: userProfile, viewModel: commentsViewModel)
            }
        }
        .padding(.top, 16)
    }
}

// MARK: - Posts List
struct UserPostsList: View {
    @ObservedObject var viewModel: CollectionPostsViewModel

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.1)
                    .padding(.top, 32)
            } else if !viewModel.posts.isEmpty {
                ForEach(viewModel.posts) { post in
                    PostCard(
                        post: post,
                        onBookmarkToggle: { isSaved in
                            viewModel.handleBookmarkChange(for: post, isSaved: isSaved)
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, post.id == viewModel.posts.first?.id ? 0 : 16)
                    .task {
                        await viewModel.loadMoreIfNeeded(currentPost: post)
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 16)
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
                        .font(.system(size: 48))
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
                        .font(.system(size: 48))
                        .foregroundColor(.loopedTextSecondary.opacity(0.5))

                    Text("No comments yet")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextSecondary)
                }
                .padding(.top, 60)
            } else {
                ForEach(viewModel.comments) { comment in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(comment.content)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .multilineTextAlignment(.leading)

                        Text(comment.createdAt, style: .date)
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .task {
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
        isCurrentUser: false,
        createdAt: Date(),
        updatedAt: Date()
    )

    NavigationView {
        UserProfileView(userId: 1, preloadedProfile: sampleProfile)
    }
}
