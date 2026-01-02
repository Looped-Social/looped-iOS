import SwiftUI
import UIKit

struct MenuContent: View {
    let onMenuItemTap: (MenuDestination) -> Void
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("anonymousMode") private var isAnonymous = false
    @State private var showAnonError = false
    @State private var anonErrorMessage = ""
    @State private var isEnrollingAnon = false
    private let anonService = AnonService.shared

    var body: some View {
        GeometryReader { proxy in
            let verticalInset = max(proxy.size.height * 0.06, 20)
            VStack(alignment: .center, spacing: 0) {
                Spacer(minLength: verticalInset)

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
                        .padding(.top, 16)

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

                Spacer(minLength: verticalInset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.loopedBackground)
        .clipShape(SideDrawerShape(radius: 44))
        .ignoresSafeArea(.all)
        .onChange(of: isAnonymous) { _, newValue in
            Task { await handleAnonToggle(isOn: newValue) }
        }
        .alert("Anonymous Mode Failed", isPresented: $showAnonError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(anonErrorMessage)
        }
    }
    
    private var displayName: String {
        if isAnonymous { return "Anonymous" }
        return authViewModel.currentUser?.displayName ?? "Looped User"
    }
    
    private var totalHeartsText: String {
        return "Hearts not available"
    }
}

private extension MenuContent {
    func handleAnonToggle(isOn: Bool) async {
        guard isOn, !isEnrollingAnon else { return }
        isEnrollingAnon = true
        defer { isEnrollingAnon = false }
        do {
            _ = try await anonService.ensureIdentity()
        } catch {
            anonErrorMessage = error.localizedDescription
            showAnonError = true
            isAnonymous = false
        }
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
        List {
            Section {
                LikedPostsFeedList(viewModel: likedViewModel)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle("Liked Posts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.loopedPrimary)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
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
        List {
            Section {
                CollectionPostsContent(viewModel: savedViewModel, emptyMessage: "No saved posts yet", emptyIcon: "bookmark")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle("Saved Posts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.loopedPrimary)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
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
                PostCard(
                    post: post,
                    onBookmarkToggle: { saved in
                        viewModel.handleBookmarkChange(for: post, isSaved: saved)
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
                PostCard(post: post, onDelete: { deleted in
                    viewModel.removePost(backendId: deleted.backendId)
                })
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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @StateObject private var draftStore = PostDraftStore()
    @State private var selectedDraft: PostDraft?

    private var drafts: [PostDraft] {
        draftStore.drafts
    }

    var body: some View {
        List {
            Section {
                Text("Drafts are saved locally so you can finish them later.")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            if drafts.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.loopedTextSecondary.opacity(0.5))
                        Text("No drafts yet")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                        Text("Start a post and save it as a draft to see it here.")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                Section {
                    ForEach(drafts) { draft in
                        DraftListRow(draft: draft) {
                            selectedDraft = draft
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            draftStore.delete(drafts[index])
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Drafts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.loopedPrimary)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .sheet(item: $selectedDraft, onDismiss: {
            draftStore.reload()
        }) { draft in
            CreatePostView(feedViewModel: feedViewModel, draft: draft, onPostCreated: {
                selectedDraft = nil
            })
        }
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

private struct DraftListRow: View {
    let draft: PostDraft
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(draftLabel)
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedTextSecondary)

                Spacer()

                Text(relativeTime)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            Text(draft.content)
                .font(.loopedBody)
                .foregroundColor(.loopedTextPrimary)
                .lineLimit(3)

            HStack {
                Text("\(draft.content.count) characters")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)

                Spacer()

                Button("Continue") {
                    onContinue()
                }
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedPrimary)
            }
        }
        .padding(.vertical, 4)
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: draft.updatedAt, relativeTo: Date())
    }

    private var draftLabel: String {
        if let name = draft.communityName, !name.isEmpty {
            return "Draft • \(name)"
        }
        return "Draft"
    }
}

// Preview intentionally omitted; MenuContent relies on live auth state.
