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
    private let verificationService: CommunityVerificationServiceProtocol = CommunityVerificationService()

    var body: some View {
        GeometryReader { proxy in
            let verticalInset = max(proxy.size.height * 0.06, 20)
            VStack(alignment: .center, spacing: 0) {
                Spacer(minLength: verticalInset)

                // Profile Header Section
                VStack(alignment: .center, spacing: 12) {
                    // Profile Avatar
                    ProfileAvatarView(
                        imageURL: authViewModel.currentUser?.profileImageURL,
                        size: 72,
                        variant: isAnonymous ? .anonymous : .standard
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
                    MenuItemButton(icon: "text.bubble", title: "Posts") {
                        onMenuItemTap(.posts)
                    }
                    MenuItemButton(icon: "bubble.left.and.bubble.right", title: "Replies") {
                        onMenuItemTap(.replies)
                    }
                    MenuItemButton(icon: "heart", title: "Liked") {
                        onMenuItemTap(.liked)
                    }
                    MenuItemButton(icon: "bookmark", title: "Saved") {
                        onMenuItemTap(.saved)
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
        .overlay(alignment: .leading) {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.loopedClear,
                    Color.loopedBlack.opacity(0.05),
                    Color.loopedBlack.opacity(0.1),
                    Color.loopedBlack.opacity(0.2)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 20)
            .allowsHitTesting(false)
        }
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
        guard let likes = authViewModel.currentUser?.likesReceivedCount else {
            return "— likes"
        }
        guard likes > 0 else { return "No likes yet" }
        return "\(likes) " + (likes == 1 ? "like" : "likes")
    }
}

private extension MenuContent {
    func handleAnonToggle(isOn: Bool) async {
        guard isOn, !isEnrollingAnon else { return }
        isEnrollingAnon = true
        defer { isEnrollingAnon = false }
        do {
            let communityId = await AnonCommunityResolver.resolve(
                preferredCommunityId: authViewModel.currentUser?.displayCommunity?.id,
                preferredSpecializationId: authViewModel.currentUser?.displaySpecialization?.id,
                verificationService: verificationService
            )
            guard let communityId else {
                throw AnonServiceError.missingCommunityContext
            }
            AnonCommunityResolver.cacheSelectedCommunityId(communityId)
            _ = try await anonService.ensureIdentity(communityId: communityId)
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
                    .font(.loopedCustom(size: 20))
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
                .foregroundColor(.loopedError)
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
struct MyPostsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("anonymousMode") private var isAnonymous = false
    @StateObject private var commentsManager = CommentsModalManager()
    @StateObject private var loader = CurrentUserPostsLoader()

    var body: some View {
        ScrollView {
            if loader.isLoading && loader.viewModel == nil {
                ProgressView()
                    .padding(.top, 60)
            } else if let viewModel = loader.viewModel {
                CollectionPostsContent(
                    viewModel: viewModel,
                    emptyMessage: "No posts yet",
                    emptyIcon: "text.bubble"
                )
            } else if let error = loader.errorMessage {
                VStack(spacing: 12) {
                    Text(error)
                        .font(.loopedBody)
                        .foregroundColor(.loopedError)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadPosts() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                ProgressView()
                    .padding(.top, 60)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle("Posts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.loopedSecondary)
            }
        }
        .environmentObject(commentsManager)
        .task { await loadPosts() }
        .loopedPullToRefresh {
            if let viewModel = loader.viewModel {
                await viewModel.loadInitial()
            } else {
                await loadPosts()
            }
        }
        .onChange(of: isAnonymous) { _, _ in
            Task { await loadPosts() }
        }
    }

    private func loadPosts() async {
        await loader.load(userId: authViewModel.currentUser?.backendId)
    }
}

@MainActor
private final class CurrentUserPostsLoader: ObservableObject {
    @Published var viewModel: CollectionPostsViewModel?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let anonService: AnonService

    init(anonService: AnonService = .shared) {
        self.anonService = anonService
    }

    func load(userId: Int?) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if anonService.isAnonymousEnabled {
                let identity = try await anonService.ensureIdentity()
                viewModel = CollectionPostsViewModel(collection: .anon(profileId: identity.profileId))
            } else if let userId, userId > 0 {
                viewModel = CollectionPostsViewModel(collection: .user(userId: userId))
            } else {
                viewModel = nil
                errorMessage = "Couldn't load posts."
                return
            }

            await viewModel?.loadInitial()
        } catch {
            viewModel = nil
            errorMessage = error.localizedDescription
        }
    }
}

struct MyRepliesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var commentsManager = CommentsModalManager()
    @StateObject private var repliesViewModel = UserRepliesViewModel()

    var body: some View {
        ScrollView {
            UserRepliesList(viewModel: repliesViewModel)
                .padding(.top, 20)
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle("Replies")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.loopedSecondary)
            }
        }
        .environmentObject(commentsManager)
        .task {
            repliesViewModel.setUser(id: authViewModel.currentUser?.backendId)
            await repliesViewModel.loadInitial()
        }
        .loopedPullToRefresh {
            repliesViewModel.setUser(id: authViewModel.currentUser?.backendId)
            await repliesViewModel.loadInitial()
        }
    }
}

struct LikedPostsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var commentsManager = CommentsModalManager()
    @StateObject private var likedViewModel = CollectionPostsViewModel(collection: .liked)

    var body: some View {
        ScrollView {
            LikedPostsFeedList(viewModel: likedViewModel)
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle("Liked Posts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.loopedSecondary)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .environmentObject(commentsManager)
        .task {
            await likedViewModel.loadInitial()
        }
        .loopedPullToRefresh {
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
        ScrollView {
            CollectionPostsContent(
                viewModel: savedViewModel,
                emptyMessage: "No saved posts yet",
                emptyIcon: "bookmark"
            )
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle("Saved Posts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.loopedSecondary)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .environmentObject(commentsManager)
        .task {
            await savedViewModel.loadInitial()
        }
        .loopedPullToRefresh {
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
        LazyVStack(spacing: 0) {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView()
                    .padding(.top, 60)
            } else if let error = viewModel.errorMessage, viewModel.posts.isEmpty {
                VStack(spacing: 12) {
                    Text(error)
                        .font(.loopedBody)
                        .foregroundColor(.loopedError)
                    Button("Retry") {
                        Task { await viewModel.loadInitial() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else if viewModel.posts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: emptyIcon)
                        .font(.loopedCustom(size: 48))
                        .foregroundColor(.loopedTextSecondary.opacity(0.5))
                    Text(emptyMessage)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                ForEach(viewModel.posts) { post in
                    PostCard(
                        post: post,
                        showsCommunityLabel: true,
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
}

private struct LikedPostsFeedList: View {
    @ObservedObject var viewModel: CollectionPostsViewModel
    @EnvironmentObject private var commentsManager: CommentsModalManager

    var body: some View {
        LazyVStack(spacing: 0) {
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
                        .foregroundColor(.loopedError)
                    Button("Retry") {
                        Task { await viewModel.loadInitial() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else if viewModel.posts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "heart")
                        .font(.loopedCustom(size: 48))
                        .foregroundColor(.loopedTextSecondary.opacity(0.5))
                    Text("No likes yet")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                ForEach(viewModel.posts) { post in
                    PostCard(
                        post: post,
                        showsCommunityLabel: true,
                        onUpdate: { updated in
                            viewModel.updatePost(updated)
                        },
                        onDelete: { deleted in
                            viewModel.removePost(backendId: deleted.backendId)
                        }
                    )
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
}

struct PrivacyView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    private let contentPreferencesService: ContentPreferencesServiceProtocol = ContentPreferencesService()

    @State private var hideAnonymousPosts = false
    @State private var isLoading = false
    @State private var isUpdating = false
    @State private var skipToggleUpdate = false
    @State private var toastMessage: ToastMessage?
    @State private var showClearCacheAlert = false
    @State private var isClearingCache = false
    @State private var storageSnapshot: StorageSnapshot?
    @State private var isLoadingStorage = false
    @State private var showStorageDetails = false

    var body: some View {
        List {
            Section("Content") {
                HStack(spacing: 12) {
                    SettingsRowLabel(
                        icon: .system("eye.slash"),
                        title: "Hide anonymous posts",
                        subtitle: "Removes anonymous posts from your feed."
                    )

                    if isUpdating {
                        ProgressView()
                            .tint(.loopedSecondary)
                    } else {
                        Toggle("", isOn: $hideAnonymousPosts)
                            .labelsHidden()
                            .tint(.loopedSecondary)
                    }
                }
            }

            Section("Safety") {
                NavigationLink(destination: BlockedUsersView()) {
                    SettingsRowLabel(icon: .system("hand.raised.fill"), title: "Blocked users")
                }
            }

            Section("Storage") {
                Button {
                    Task {
                        await refreshStorageSnapshot()
                        if storageSnapshot != nil {
                            showStorageDetails = true
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        SettingsRowLabel(
                            icon: .system("internaldrive"),
                            title: "Storage used",
                            subtitle: storageSnapshot == nil ? "Tap to estimate storage usage." : "Tap for details."
                        )

                        Spacer(minLength: 0)

                        if isLoadingStorage {
                            ProgressView()
                                .tint(.loopedSecondary)
                        } else if let snapshot = storageSnapshot {
                            let total = snapshot.documentsBytes + snapshot.cachesBytes + snapshot.tmpBytes
                            Text(StorageDiagnostics.formatBytes(total))
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextSecondary)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.loopedCustom(.semibold, size: 14))
                                .foregroundColor(.loopedTextSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoadingStorage)

                Button {
                    showClearCacheAlert = true
                } label: {
                    HStack(spacing: 12) {
                        SettingsRowLabel(
                            icon: .system("trash"),
                            title: "Clear cached media",
                            subtitle: "Frees up storage used by downloaded media."
                        )

                        if isClearingCache {
                            ProgressView()
                                .tint(.loopedSecondary)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.loopedCustom(.semibold, size: 14))
                                .foregroundColor(.loopedTextSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isClearingCache)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toast($toastMessage)
        .task {
            await loadPreferences()
            await refreshStorageSnapshot()
        }
        .alert("Clear cached media?", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                Task { await clearCachedMedia() }
            }
        } message: {
            Text("This removes downloaded media and temporary upload files. It won’t delete any posts or messages.")
        }
        .alert("Storage used", isPresented: $showStorageDetails) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(storageDetailsMessage)
        }
        .onChange(of: hideAnonymousPosts) { oldValue, newValue in
            guard !skipToggleUpdate else { return }
            Task { await updateHideAnonymousPosts(from: oldValue, to: newValue) }
        }
    }

    private func clearCachedMedia() async {
        guard !isClearingCache else { return }
        isClearingCache = true
        defer { isClearingCache = false }

        await Task.detached(priority: .background) {
            URLCache.shared.removeAllCachedResponses()
            TemporaryMediaFile.cleanupOrphanedFiles(olderThan: 0)
            TemporaryMediaFile.enforceTemporaryDirectoryBudget(
                maxBytes: CacheHousekeeper.tmpBudgetBytes,
                minimumAge: CacheHousekeeper.tmpBudgetMinimumAge,
                includeUnowned: true
            )
        }.value

        toastMessage = ToastMessage(text: "Cleared cached media.", kind: .success)
        await refreshStorageSnapshot()
    }

    private func refreshStorageSnapshot() async {
        guard !isLoadingStorage else { return }
        isLoadingStorage = true
        defer { isLoadingStorage = false }
        storageSnapshot = await StorageDiagnostics.snapshot()
    }

    private var storageDetailsMessage: String {
        guard let snapshot = storageSnapshot else {
            return "Tap “Storage used” to estimate storage usage."
        }
        let total = snapshot.documentsBytes + snapshot.cachesBytes + snapshot.tmpBytes
        return [
            "Total: \(StorageDiagnostics.formatBytes(total))",
            "Documents: \(StorageDiagnostics.formatBytes(snapshot.documentsBytes))",
            "Caches: \(StorageDiagnostics.formatBytes(snapshot.cachesBytes))",
            "Temp: \(StorageDiagnostics.formatBytes(snapshot.tmpBytes))",
            "URLCache: \(StorageDiagnostics.formatBytes(Int64(snapshot.urlCacheDiskBytes))) disk, \(StorageDiagnostics.formatBytes(Int64(snapshot.urlCacheMemoryBytes))) memory"
        ].joined(separator: "\n")
    }

    private func loadPreferences() async {
        if let user = authViewModel.currentUser {
            hideAnonymousPosts = user.hideAnonymousPosts ?? false
        }

        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await contentPreferencesService.getPreferences()
            let resolvedValue = response.content.hideAnonymousPosts
            if hideAnonymousPosts != resolvedValue {
                skipToggleUpdate = true
                hideAnonymousPosts = resolvedValue
                skipToggleUpdate = false
            }
            if var user = authViewModel.currentUser {
                authViewModel.currentUser = user.updating(hideAnonymousPosts: resolvedValue)
            }
        } catch {
            toastMessage = ToastMessage(text: error.localizedDescription, kind: .error)
        }
    }

    private func updateHideAnonymousPosts(from oldValue: Bool, to newValue: Bool) async {
        guard oldValue != newValue, !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        do {
            let response = try await contentPreferencesService.updateHideAnonymousPosts(newValue)
            let resolvedValue = response.content.hideAnonymousPosts
            if resolvedValue != hideAnonymousPosts {
                skipToggleUpdate = true
                hideAnonymousPosts = resolvedValue
                skipToggleUpdate = false
            }
            if var user = authViewModel.currentUser {
                authViewModel.currentUser = user.updating(hideAnonymousPosts: resolvedValue)
            }
            toastMessage = ToastMessage(text: "Updated", kind: .success)
        } catch {
            skipToggleUpdate = true
            hideAnonymousPosts = oldValue
            skipToggleUpdate = false
            toastMessage = ToastMessage(text: error.localizedDescription, kind: .error)
        }
    }
}

struct DraftsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @StateObject private var draftStore = PostDraftStore()
    @State private var selectedDraft: PostDraft?
    @State private var toastMessage: ToastMessage?

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
                            .font(.loopedCustom(size: 48))
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
                .foregroundColor(.loopedSecondary)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .toast($toastMessage)
        .sheet(item: $selectedDraft, onDismiss: {
            draftStore.reload()
        }) { draft in
            CreatePostView(
                feedViewModel: feedViewModel,
                draftStore: draftStore,
                draft: draft,
                onPostCreated: {
                    selectedDraft = nil
                },
                onPostStatus: { message in
                    toastMessage = message
                }
            )
            .presentationDetents([.large])
        }
    }
}

struct AnalyticsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your activity")
                        .font(.loopedSubheadMedium)
                        .foregroundColor(.loopedTextPrimary)

                    AnalyticsStatRow(label: "Posts", value: authViewModel.currentUser?.postsCount)
                    AnalyticsStatRow(label: "Comments", value: authViewModel.currentUser?.commentsCount)
                    AnalyticsStatRow(label: "Likes", value: authViewModel.currentUser?.likesReceivedCount)
                    AnalyticsStatRow(label: "Followers", value: authViewModel.currentUser?.followerCount)
                    AnalyticsStatRow(label: "Following", value: authViewModel.currentUser?.followingCount)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color.loopedTextSecondary.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("More analytics coming soon.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 20)
            }
            .padding(.top, 16)
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AnalyticsStatRow: View {
    let label: String
    let value: Int?

    var body: some View {
        HStack {
            Text(label)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)
            Spacer()
            Text(value.map(String.init) ?? "—")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(.vertical, 6)
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
