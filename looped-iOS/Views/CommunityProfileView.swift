import SwiftUI
import UIKit

enum CommunityProfileTab: String, CaseIterable {
    case posts = "Posts"
    case hashtags = "Hashtags"
}

struct CommunityProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CommunityProfileViewModel
    @StateObject private var commentsManager = CommentsModalManager()
    @State private var selectedTab: CommunityProfileTab = .posts
    @State private var showVerificationFlow = false
    @State private var hasLoaded = false

    init(community: CommunityProfileData) {
        _viewModel = StateObject(wrappedValue: CommunityProfileViewModel(community: community))
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    headerContent
                    tabBar
                    tabContent
                    Color.clear.frame(height: 80)
                }
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .refreshable {
                await viewModel.refresh()
            }
            .task { await loadIfNeeded() }

            CommunityProfileHeader { dismiss() }
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
        .sheet(isPresented: $showVerificationFlow) {
            CommunityVerificationFlowView(
                community: viewModel.community
            ) {
                Task { await viewModel.loadVerification() }
            }
        }
        .alert(
            "Update Failed",
            isPresented: Binding(
                get: { viewModel.followErrorMessage != nil },
                set: { if !$0 { viewModel.followErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.followErrorMessage ?? "")
        }
    }

    private var headerContent: some View {
        VStack(spacing: 12) {
            CommunityProfileBanner(
                name: viewModel.community.name,
                imageUrl: viewModel.community.imageUrl
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Text("\(formattedMemberCount(viewModel.community.memberCount)) Members")
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedTextSecondary)

                    Spacer()

                    followButton
                }

                if let specializationLabel = viewModel.community.specializationLabel {
                    Text(specializationLabel)
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.loopedMutedBackground)
                        .clipShape(Capsule())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.community.kind != .specialization {
                    verificationPill
                }

                if viewModel.verificationError != nil && viewModel.community.kind != .specialization {
                    Text("Verification status unavailable.")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                }

                if !viewModel.community.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(viewModel.community.description)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private var followButton: some View {
        Button(action: {
            Task { await viewModel.toggleFollow() }
        }) {
            Text(viewModel.community.isFollowing ? "Following" : "Follow")
                .font(.loopedBodyMedium)
                .foregroundColor(viewModel.community.isFollowing ? .loopedTextPrimary : .white)
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
                .background(viewModel.community.isFollowing ? Color.loopedMutedBackground : Color.loopedPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(viewModel.isFollowActionInFlight)
        .opacity(viewModel.isFollowActionInFlight ? 0.7 : 1)
    }

    private var verificationPill: some View {
        Button(action: { showVerificationFlow = true }) {
            HStack(spacing: 8) {
                Image(systemName: verificationDisplay.icon)
                    .foregroundColor(verificationDisplay.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verificationDisplay.title)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextPrimary)

                    if let subtitle = verificationDisplay.subtitle {
                        Text(subtitle)
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.loopedMutedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(CommunityProfileTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(selectedTab == tab ? .loopedPrimary : .loopedTextSecondary)

                        Rectangle()
                            .fill(selectedTab == tab ? Color.loopedPrimary : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        if selectedTab == .posts {
            postsSection
        } else {
            hashtagsSection
        }
    }

    private var postsSection: some View {
        LazyVStack(spacing: 0) {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ForEach(0..<6, id: \.self) { index in
                    PostCardSkeleton(showsMedia: index % 3 != 0)

                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.loopedTextSecondary.opacity(0.1))
                }
            } else if viewModel.posts.isEmpty {
                Text("No posts yet.")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .padding(.top, 40)
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
                        .padding(.vertical, 16)
                }
            }

            if let errorMessage = viewModel.errorMessage, viewModel.posts.isEmpty {
                Text(errorMessage)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .padding(.top, 16)
            }
        }
    }

    private var hashtagsSection: some View {
        VStack(spacing: 12) {
            Text("Hashtags coming soon.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
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
                        CommentsView(post: post) {
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

    private var verificationDisplay: VerificationDisplay {
        guard let verification = viewModel.verification else {
            return VerificationDisplay(
                title: "Unverified",
                subtitle: "Tap to verify",
                icon: "exclamationmark.circle",
                color: .loopedSecondary
            )
        }
        if verification.isActive {
            let subtitle = verification.expiresAt.map { "Expires \(Self.expiryFormatter.string(from: $0))" }
            return VerificationDisplay(
                title: "Verified",
                subtitle: subtitle,
                icon: "checkmark.seal.fill",
                color: .loopedPrimary
            )
        }
        let subtitle = verification.expiresAt.map { "Expired \(Self.expiryFormatter.string(from: $0))" }
        return VerificationDisplay(
            title: "Unverified",
            subtitle: subtitle ?? "Tap to verify",
            icon: "exclamationmark.circle",
            color: .loopedSecondary
        )
    }

    private func formattedMemberCount(_ count: Int) -> String {
        let value = Double(count)
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000).replacingOccurrences(of: ".0", with: "")
        }
        if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000).replacingOccurrences(of: ".0", with: "")
        }
        return "\(count)"
    }

    private func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await viewModel.loadIfNeeded()
    }

    private struct VerificationDisplay {
        let title: String
        let subtitle: String?
        let icon: String
        let color: Color
    }

    private static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

struct CommunityProfileHeader: View {
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

struct CommunityProfileBanner: View {
    let name: String
    let imageUrl: String?

    var body: some View {
        VStack(spacing: 12) {
            if hasBannerImage {
                bannerImage
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Text(name)
                .font(.loopedBody24)
                .foregroundColor(bannerTextColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: hasBannerImage ? 0 : 120)
                .padding(.horizontal, hasBannerImage ? 0 : 16)
                .background(hasBannerImage ? Color.clear : Color.loopedMutedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
    }

    private var bannerTextColor: Color {
        if hasBannerImage {
            return .loopedTextPrimary
        }
        return .loopedPrimary
    }

    private var hasBannerImage: Bool {
        if let imageUrl, let url = URL(string: imageUrl), url.scheme != nil {
            return true
        }
        if let imageUrl, UIImage(named: imageUrl) != nil {
            return true
        }
        return false
    }

    private var bannerImage: some View {
        Group {
            if let imageUrl, let url = URL(string: imageUrl), url.scheme != nil {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Color.loopedMutedBackground
                    case .empty:
                        Color.loopedMutedBackground
                    @unknown default:
                        Color.loopedMutedBackground
                    }
                }
            } else if let imageUrl, let localImage = UIImage(named: imageUrl) {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.loopedBackground
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

#Preview {
    CommunityProfileView(
        community: CommunityProfileData(
            id: 1,
            name: "Finance",
            description: "Talk markets, careers, and everything in finance.",
            kind: .profession,
            specializationType: .unknown,
            memberCount: 1_000_000,
            imageUrl: nil,
            isFollowing: false
        )
    )
    .environmentObject(CommentsModalManager())
    .environmentObject(FeedViewModel())
    .environmentObject(AuthViewModel())
}
