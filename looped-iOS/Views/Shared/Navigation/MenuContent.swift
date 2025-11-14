import SwiftUI

struct MenuContent: View {
    let onMenuItemTap: (MenuDestination) -> Void
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Profile Header Section
            VStack(alignment: .center, spacing: 16) {
                // Profile Avatar
                Circle()
                    .fill(Color.loopedTextSecondary.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(avatarInitials)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(.loopedTextPrimary)
                    )
                    .padding(.top, 60)

                // Display Name
                Text(displayName)
                    .font(.loopedBodyStrong32)
                    .foregroundColor(.loopedContrast)

                Text(handleText)
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedTextSecondary)

                // Hearts Metric
                if let company = companyText {
                    Text(company)
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedTextSecondary)
                }
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
    }
    
    private var displayName: String {
        authViewModel.currentUser?.displayName ?? "Looped User"
    }
    
    private var handleText: String {
        let handle = authViewModel.currentUser?.username ?? authViewModel.currentUser?.handle
        return handle.map { "@\($0)" } ?? "@looped"
    }
    
    private var companyText: String? {
        let company = authViewModel.currentUser?.company
        return company?.isEmpty == false ? company : nil
    }
    
    private var avatarInitials: String {
        if let name = authViewModel.currentUser?.displayName,
           let first = name.split(separator: " ").first?.first {
            return String(first).uppercased()
        }
        return "LU"
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
    @StateObject private var likedViewModel = CollectionPostsViewModel(collection: .liked)

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
                    CollectionPostsContent(viewModel: likedViewModel, emptyMessage: "No liked posts yet", emptyIcon: "heart")
                }
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .environmentObject(commentsManager)
        .task {
            await likedViewModel.loadInitial()
        }
        .refreshable {
            await likedViewModel.loadInitial()
        }
    }
}

// MARK: - Saved Posts View
struct SavedPostsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var commentsManager = CommentsModalManager()
    @StateObject private var savedViewModel = CollectionPostsViewModel(collection: .saved)

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
                    CollectionPostsContent(viewModel: savedViewModel, emptyMessage: "No saved posts yet", emptyIcon: "bookmark")
                }
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .environmentObject(commentsManager)
        .task {
            await savedViewModel.loadInitial()
        }
        .refreshable {
            await savedViewModel.loadInitial()
        }
    }
}

private struct CollectionPostsContent: View {
    @ObservedObject var viewModel: CollectionPostsViewModel
    let emptyMessage: String
    let emptyIcon: String
    @EnvironmentObject private var commentsManager: CommentsModalManager
    
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
                Image(systemName: emptyIcon)
                    .font(.system(size: 48))
                    .foregroundColor(.loopedTextSecondary.opacity(0.5))
                Text(emptyMessage)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextSecondary)
            }
            .padding(.top, 60)
        } else {
            ForEach(viewModel.posts) { post in
                PostCard(post: post) { saved in
                    viewModel.handleBookmarkChange(for: post, isSaved: saved)
                }
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

// Preview intentionally omitted; MenuContent relies on live auth state.
