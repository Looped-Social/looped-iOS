import SwiftUI

struct MenuContent: View {
    let onMenuItemTap: (MenuDestination) -> Void
    @StateObject private var viewModel = ProfileViewModel()
    @State private var isAnonymous: Bool = false

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Profile Header Section
            VStack(alignment: .center, spacing: 16) {
                // Profile Avatar
                Circle()
                    .fill(Color.loopedTextSecondary.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.loopedTextSecondary)
                    )
                    .padding(.top, 60)

                // Display Name
                Text(viewModel.userProfile?.displayName ?? viewModel.user?.displayName ?? "Looped User")
                    .font(.loopedBodyStrong32)
                    .foregroundColor(.loopedContrast)

                // Anonymous Status Toggle
                Button(action: {
                    isAnonymous.toggle()
                    Task {
                        await viewModel.updateProfile(
                            displayName: viewModel.userProfile?.displayName ?? viewModel.user?.displayName,
                            bio: viewModel.userProfile?.bio ?? viewModel.user?.bio,
                            isAnonymous: isAnonymous
                        )
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("Anonymous Status:")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(isAnonymous ? Color(red: 0.2, green: 0.8, blue: 0.7) : .loopedTextSecondary)
                        Text(isAnonymous ? "ON" : "OFF")
                            .font(.loopedSubBodyBold)
                            .foregroundColor(isAnonymous ? Color(red: 0.2, green: 0.8, blue: 0.7) : .loopedTextSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isAnonymous ? Color(red: 0.2, green: 0.8, blue: 0.7) : .loopedTextSecondary.opacity(0.3), lineWidth: 1.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Hearts Metric
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                    Text("\(totalHearts) Hearts")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)

            // Menu Items
            VStack(alignment: .leading, spacing: 0) {
                MenuItemButton(icon: "heart", title: "Liked") {
                    onMenuItemTap(.liked)
                }
                MenuItemButton(icon: "bookmark", title: "Saved") {
                    onMenuItemTap(.saved)
                }
                MenuItemButton(icon: "lock", title: "Privacy") {
                    onMenuItemTap(.privacy)
                }
                MenuItemButton(icon: "doc.text", title: "Drafts") {
                    onMenuItemTap(.drafts)
                }
                MenuItemButton(icon: "chart.bar", title: "Analytics") {
                    onMenuItemTap(.analytics)
                }
                MenuItemButton(icon: "questionmark.circle", title: "FAQ") {
                    onMenuItemTap(.faq)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Settings Button (Bottom Right)
            HStack {
                Spacer()
                Button(action: {
                    onMenuItemTap(.settings)
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.loopedTextSecondary)
                        .padding(20)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.loopedBackground.ignoresSafeArea(.all))
        .task {
            await viewModel.loadUserProfile()
            isAnonymous = viewModel.userProfile?.isAnonymous ?? viewModel.user?.isAnonymous ?? false
        }
    }

    private var totalHearts: Int {
        viewModel.userPosts.reduce(0) { $0 + $1.reactionCount }
    }
}

// Menu Item Button Component
struct MenuItemButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.loopedTextSecondary)
                    .frame(width: 24)

                Text(title)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.loopedTextSecondary.opacity(0.5))
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Liked Posts View
struct LikedPostsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var commentsManager = CommentsModalManager()

    var likedPosts: [Post] {
        MockPosts.getLikedPosts()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                Text("Liked Posts")
                    .font(.loopedHeadingMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                // Invisible spacer for centering
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            .padding(.bottom, 12)

            // Posts List
            ScrollView {
                LazyVStack(spacing: 0) {
                    if likedPosts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "heart")
                                .font(.system(size: 48))
                                .foregroundColor(.loopedTextSecondary.opacity(0.5))

                            Text("No liked posts yet")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(likedPosts) { post in
                            PostCard(post: post)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }
                    }
                }
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .environmentObject(commentsManager)
    }
}

// MARK: - Saved Posts View
struct SavedPostsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var commentsManager = CommentsModalManager()

    var savedPosts: [Post] {
        MockPosts.getSavedPosts()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                Text("Saved Posts")
                    .font(.loopedHeadingMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                // Invisible spacer for centering
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            .padding(.bottom, 12)

            // Posts List
            ScrollView {
                LazyVStack(spacing: 0) {
                    if savedPosts.isEmpty {
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
                        ForEach(savedPosts) { post in
                            PostCard(post: post)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }
                    }
                }
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .environmentObject(commentsManager)
    }
}

struct PrivacyView: View {
    var body: some View {
        VStack {
            Text("Privacy Settings")
                .font(.loopedHeadingMedium)
                .foregroundColor(.loopedTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DraftsView: View {
    var body: some View {
        VStack {
            Text("Drafts")
                .font(.loopedHeadingMedium)
                .foregroundColor(.loopedTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AnalyticsView: View {
    var body: some View {
        VStack {
            Text("Analytics")
                .font(.loopedHeadingMedium)
                .foregroundColor(.loopedTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FAQView: View {
    var body: some View {
        VStack {
            Text("FAQ")
                .font(.loopedHeadingMedium)
                .foregroundColor(.loopedTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    MenuContent(onMenuItemTap: { destination in
        print("Tapped: \(destination)")
    })
    .background(Color.loopedBackground)
}
