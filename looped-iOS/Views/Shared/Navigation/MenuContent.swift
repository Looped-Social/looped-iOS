import SwiftUI
import UIKit

struct MenuContent: View {
    let onMenuItemTap: (MenuDestination) -> Void
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("anonymousMode") private var isAnonymous = false

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Profile Header Section
            VStack(alignment: .center, spacing: 12) {
                // Profile Avatar
                Circle()
                    .fill(isAnonymous ? Color.loopedSecondary : Color.loopedPrimary)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .padding(.top, 72)

                // Display Name
                Text(displayName)
                    .font(.loopedBodyStrong32)
                    .foregroundColor(.loopedContrast)

                AnonymousStatusPill(isOn: $isAnonymous)

                HeartsRow(text: totalHeartsText)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

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
                MenuItemButton(icon: "questionmark.circle", title: "FAQ") {
                    onMenuItemTap(.faq)
                }
                MenuItemButton(icon: "gearshape.fill", title: "Settings") {
                    onMenuItemTap(.settings)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.loopedBackground)
        .clipShape(SideDrawerShape(radius: 44))
        .ignoresSafeArea(.all)
    }
    
    private var displayName: String {
        authViewModel.currentUser?.displayName ?? "Looped User"
    }
    
    private var totalHeartsText: String {
        return "Hearts not available"
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
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct AnonymousStatusPill: View {
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            Text("Anonymous Status: \(isOn ? "ON" : "OFF")")
                .font(.loopedSubBodyMedium)
                .foregroundColor(isOn ? .loopedSecondary : .loopedTextSecondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(isOn ? Color.loopedSecondary : Color.loopedTextSecondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct HeartsRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
            Text(text)
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextSecondary)
        }
    }
}

private struct SideDrawerShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .bottomLeft],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
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
                    LikedPostsFeedList(viewModel: likedViewModel)
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

private struct LikedPostsFeedList: View {
    @ObservedObject var viewModel: CollectionPostsViewModel
    @EnvironmentObject private var commentsManager: CommentsModalManager

    var body: some View {
        if viewModel.isLoading && viewModel.posts.isEmpty {
            ForEach(0..<6, id: \.self) { index in
                PostCardSkeleton(showsMedia: index % 3 != 0)

                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.loopedTextSecondary.opacity(0.1))
            }
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
                Image(systemName: "heart")
                    .font(.system(size: 48))
                    .foregroundColor(.loopedTextSecondary.opacity(0.5))
                Text("No liked posts yet")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextSecondary)
            }
            .padding(.top, 60)
        } else {
            ForEach(viewModel.posts) { post in
                PostCard(post: post)
                    .onAppear {
                        Task { await viewModel.loadMoreIfNeeded(currentPost: post) }
                    }

                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.loopedTextSecondary.opacity(0.1))
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
