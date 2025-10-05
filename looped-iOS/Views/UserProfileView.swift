import SwiftUI

enum UserProfileTab: String, CaseIterable {
    case posts = "Posts"
    case comments = "Comments"
}

struct UserProfileView: View {
    let userProfile: UserProfile
    @State private var selectedTab: UserProfileTab = .posts
    @Environment(\.dismiss) private var dismiss
    @StateObject private var commentsManager = CommentsModalManager()

    var body: some View {
        VStack(spacing: 0) {
            // Header with Back Button
            UserProfileHeader {
                dismiss()
            }

            ScrollView {
                VStack(spacing: 0) {
                    // Profile Info Section
                    UserProfileInfoSection(userProfile: userProfile)

                    // Tab Navigation
                    UserProfileTabsView(selectedTab: $selectedTab)

                    // Content based on selected tab
                    UserProfileContentView(userProfile: userProfile, selectedTab: selectedTab)
                }
            }
            .background(Color.loopedBackground.ignoresSafeArea())

            Spacer(minLength: 0)
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
    }

    private var commentsModalOverlay: some View {
        ZStack {
            // Background dimming - covers entire screen including safe area
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    commentsManager.dismissComments()
                }

            // Modal content with post above
            VStack(spacing: 0) {
                Spacer()

                // Post display above comments
                if let post = commentsManager.currentPost {
                    VStack(spacing: 0) {
                        SimplifiedPostCard(post: post)

                        // Separator line
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

                // Comments modal
                VStack(spacing: 0) {
                    // Modal handle
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.loopedTextSecondary.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    // Comments content
                    if let post = commentsManager.currentPost {
                        CommentsView(
                            post: post,
                            comments: commentsManager.currentComments
                        ) {
                            commentsManager.dismissComments()
                        }
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
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

// MARK: - Profile Info Section
struct UserProfileInfoSection: View {
    let userProfile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Profile Picture with Name and Handle beside it
            HStack(spacing: 16) {
                // Profile Picture
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

                // Name and Handle beside profile picture
                VStack(alignment: .leading, spacing: 4) {
                    Text(userProfile.displayName ?? "Anonymous")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.loopedTextPrimary)

                    Text(userProfile.formattedHandle)
                        .font(.subheadline)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()
            }

            // Job Title with Chevron
            HStack(spacing: 8) {
                Text(userProfile.formattedJobTitle)
                    .font(.subheadline)
                    .foregroundColor(.loopedTextSecondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.loopedTextSecondary)

                Spacer()
            }

            // Bio
            if let bio = userProfile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.body)
                    .foregroundColor(.loopedTextPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Years in Loop and Company Info
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
                    // Company logo placeholder - use Google logo for Google, generic for others
                    if userProfile.company.lowercased() == "google" {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text("G")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    } else {
                        Circle()
                            .fill(Color.loopedPrimary)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text(String(userProfile.company.prefix(1)).uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }

                    Text("Works at \(userProfile.company)")
                        .font(.subheadline)
                        .foregroundColor(.loopedTextSecondary)

                    Spacer()
                }
            }

            // Follower Stats
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

            // Action Buttons
            UserProfileActionButtons(userProfile: userProfile)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

// MARK: - Action Buttons
struct UserProfileActionButtons: View {
    let userProfile: UserProfile

    var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                // TODO: Handle edit profile
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
                NavigationLink(destination: SettingsView()) {
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

            // Full-width underlines
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

    var body: some View {
        LazyVStack(spacing: 0) {
            switch selectedTab {
            case .posts:
                UserPostsList(userProfile: userProfile)
            case .comments:
                UserCommentsList(userProfile: userProfile)
            }
        }
        .padding(.top, 16)
    }
}

// MARK: - Posts List
struct UserPostsList: View {
    let userProfile: UserProfile

    var userPosts: [Post] {
        MockPosts.getPostsByUser(userProfile.id)
    }

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(userPosts) { post in
                PostCard(post: post)
                    .padding(.horizontal, 16)
            }

            if userPosts.isEmpty {
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

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.loopedTextSecondary.opacity(0.5))

            Text("Comments coming soon")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(.top, 60)
    }
}


#Preview {
    NavigationView {
        UserProfileView(userProfile: MockUserProfiles.profiles[0])
    }
}
