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
    @State private var showSpecializationJoinInfo = false
    @State private var showSpecializationLeaveConfirmation = false
    @State private var hasLoaded = false
    @State private var canPop = false

    init(community: CommunityProfileData) {
        _viewModel = StateObject(wrappedValue: CommunityProfileViewModel(community: community))
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    headerContent
                        .padding(.top, 12)
                    tabBar
                    tabContent
                    Color.loopedClear.frame(height: 80)
                }
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .refreshable {
                await viewModel.refresh()
            }
            .task { await loadIfNeeded() }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if !canPop {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.loopedCustom(.semibold, size: 16))
                            .foregroundColor(.loopedTextSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }
        }
        .background(NavigationCanPopReader(canPop: $canPop))
        .environmentObject(commentsManager)
        .overlay(
            Group {
                if commentsManager.isPresented, let post = commentsManager.currentPost {
                    CommentsNavigationHost(post: post) {
                        commentsManager.dismissComments()
                    }
                    .environmentObject(commentsManager)
                    .transition(.move(edge: .trailing))
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

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text("\(formattedMemberCount(viewModel.community.memberCount)) Members")
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedTextSecondary)

                    Spacer()

                    actionButtons
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

                if viewModel.community.kind == .specialization {
                    specializationJoinPill
                } else {
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
        return Button(action: {
            Task { await viewModel.toggleFollow() }
        }) {
            Text(viewModel.community.isFollowing ? "Following" : "Follow")
                .font(.loopedBodyStrong)
                .foregroundColor(viewModel.community.isFollowing ? .loopedTextPrimary : .loopedWhite)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
                .background(
                    viewModel.community.isFollowing ? Color.loopedMutedBackground : Color.loopedPrimary
                )
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(viewModel.isFollowActionInFlight || viewModel.isJoinActionInFlight)
        .opacity((viewModel.isFollowActionInFlight || viewModel.isJoinActionInFlight) ? 0.7 : 1)
    }

    @ViewBuilder
    private var actionButtons: some View {
        followButton
    }

    private var verificationPill: some View {
        Button(action: { showVerificationFlow = true }) {
            HStack(spacing: 8) {
                Image(systemName: verificationDisplay.icon)
                    .foregroundColor(verificationDisplay.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verificationDisplay.title)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    if let subtitle = verificationDisplay.subtitle {
                        Text(subtitle)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var specializationJoinPill: some View {
        HStack(spacing: 10) {
            Button(action: {
                if viewModel.community.isJoined {
                    showSpecializationLeaveConfirmation = true
                } else {
                    Task { await viewModel.toggleJoin() }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: specializationJoinDisplay.icon)
                        .foregroundColor(specializationJoinDisplay.color)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(specializationJoinDisplay.title)
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextPrimary)

                        if let subtitle = specializationJoinDisplay.subtitle {
                            Text(subtitle)
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedTextSecondary)
                        }
                    }

                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isJoinActionInFlight || viewModel.isFollowActionInFlight)

            Button(action: { showSpecializationJoinInfo = true }) {
                Image(systemName: "questionmark.circle")
                    .font(.loopedCustom(.semibold, size: 14))
                    .foregroundColor(.loopedTextSecondary)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("About specialization joining")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity((viewModel.isJoinActionInFlight || viewModel.isFollowActionInFlight) ? 0.7 : 1)
        .alert("About \(specializationJoinDisplay.label)", isPresented: $showSpecializationJoinInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(specializationJoinDisplay.infoText)
        }
        .alert("Leave \(specializationJoinDisplay.label)?", isPresented: $showSpecializationLeaveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                Task { await viewModel.toggleJoin() }
            }
        } message: {
            Text(specializationLeaveConfirmationText())
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(CommunityProfileTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(selectedTab == tab ? .loopedSubBodyBold : .loopedSubBodyMedium)
                            .foregroundColor(selectedTab == tab ? .loopedPrimary : .loopedTextSecondary)

                        Rectangle()
                            .fill(selectedTab == tab ? Color.loopedPrimary : Color.loopedClear)
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
            return VerificationDisplay(
                title: "Verified",
                subtitle: expiryText(for: verification, inactivePrefix: nil),
                icon: "checkmark.seal.fill",
                color: .loopedPrimary
            )
        }
        return VerificationDisplay(
            title: "Unverified",
            subtitle: expiryText(for: verification, inactivePrefix: "Expired") ?? "Tap to verify",
            icon: "exclamationmark.circle",
            color: .loopedSecondary
        )
    }

    private func expiryText(for verification: CommunityVerification, inactivePrefix: String?) -> String? {
        guard verification.verified else { return nil }
        guard let expiresAt = verification.expiresAt else {
            return inactivePrefix == nil ? "Never expires" : nil
        }
        let dateText = Self.expiryFormatter.string(from: expiresAt)
        if let inactivePrefix {
            return "\(inactivePrefix) \(dateText)"
        }
        return "Expires \(dateText)"
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

    private struct SpecializationJoinDisplay {
        let label: String
        let title: String
        let subtitle: String?
        let icon: String
        let color: Color
        let infoText: String
    }

    private var specializationJoinDisplay: SpecializationJoinDisplay {
        let label = viewModel.community.specializationLabel ?? "Specialization"
        let joinLimit = viewModel.community.joinLimit
        let subtitle = specializationJoinSubtitle(joinLimit: joinLimit)
        let infoText = specializationJoinInfoText(joinLimit: joinLimit, label: label)

        if viewModel.community.isJoined {
            return SpecializationJoinDisplay(
                label: label,
                title: "Joined",
                subtitle: subtitle,
                icon: "person.crop.circle.badge.checkmark",
                color: .loopedPrimary,
                infoText: infoText
            )
        }
        return SpecializationJoinDisplay(
            label: label,
            title: "Join \(label)",
            subtitle: subtitle,
            icon: "person.crop.circle.badge.plus",
            color: .loopedSecondary,
            infoText: infoText
        )
    }

    private func specializationJoinSubtitle(joinLimit: SpecializationJoinLimit?) -> String? {
        guard let joinLimit else {
            return viewModel.community.isJoined ? "Tap to leave" : "Tap to join"
        }

        let remaining = max(0, joinLimit.canJoin ? joinLimit.remaining : 0)
        let specializationLabel = Self.specializationLabel(for: joinLimit.specializationType, count: remaining)
        return "You can join \(remaining) more \(specializationLabel) left"
    }

    private func specializationJoinInfoText(joinLimit: SpecializationJoinLimit?, label: String) -> String {
        guard let joinLimit else {
            return """
            Joining a \(label.lowercased()) helps personalize your experience.
            You may be limited in how often you can change.
            """
        }

        let remaining = max(0, joinLimit.canJoin ? joinLimit.remaining : 0)
        var lines: [String] = []
        lines.append("You have \(remaining)/\(joinLimit.limit) joins left.")

        if let cooldownEndsAt = joinLimit.cooldownEndsAt {
            lines.append("It resets on \(Self.expiryFormatter.string(from: cooldownEndsAt)).")
        } else if joinLimit.cooldownMonths > 0 {
            lines.append("It resets every \(joinLimit.cooldownMonths) months.")
        }

        if joinLimit.canJoin {
            lines.append("After you use your joins, you’ll need to wait until it resets to change your \(joinLimit.pluralLabel.lowercased()).")
        } else {
            lines.append("To change your \(joinLimit.pluralLabel.lowercased()), you’ll need to wait until it resets.")
        }
        return lines.joined(separator: "\n")
    }

    private func specializationLeaveConfirmationText() -> String {
        let label = viewModel.community.specializationLabel ?? "Specialization"
        guard let joinLimit = viewModel.community.joinLimit else {
            return "You can re-join later, but changes may be limited (for example, every 6 months)."
        }

        var parts: [String] = []
        parts.append("You can re-join later, but changes may be limited.")
        parts.append("Joined \(joinLimit.joinedCount)/\(joinLimit.limit) \(joinLimit.pluralLabel.lowercased()).")

        if joinLimit.cooldownActive, let cooldownEndsAt = joinLimit.cooldownEndsAt {
            let dateText = Self.expiryFormatter.string(from: cooldownEndsAt)
            parts.append("Resets \(dateText).")
        } else {
            parts.append("\(joinLimit.remaining)/\(joinLimit.limit) joins left.")
        }

        if joinLimit.cooldownMonths > 0 {
            parts.append("Window: \(joinLimit.cooldownMonths) months.")
        }

        if label.lowercased() != joinLimit.pluralLabel.lowercased() {
            parts.append("(\(label))")
        }

        return parts.joined(separator: " ")
    }

    private static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "M/d/yyyy"
        return formatter
    }()

    private static func specializationLabel(for type: CommunitySpecializationType, count: Int) -> String {
        let singular: String
        switch type {
        case .major:
            singular = "major"
        case .department:
            singular = "department"
        case .unknown:
            singular = "specialization"
        }
        return count == 1 ? singular : "\(singular)s"
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
                .font(hasBannerImage ? .loopedBody24 : .loopedHeaderStrong)
                .foregroundColor(bannerTextColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: hasBannerImage ? 0 : 120)
                .padding(.horizontal, hasBannerImage ? 0 : 16)
                .background(hasBannerImage ? Color.loopedClear : Color.loopedBackground)
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
        localBannerImage != nil || remoteBannerURL != nil
    }

    private var bannerImage: some View {
        Group {
            if let localBannerImage {
                Image(uiImage: localBannerImage)
                    .resizable()
                    .scaledToFit()
            } else if let remoteBannerURL {
                AsyncImage(url: remoteBannerURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        Color.loopedBackground
                    case .empty:
                        Color.loopedBackground
                    @unknown default:
                        Color.loopedBackground
                    }
                }
            } else {
                Color.loopedBackground
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground)
    }

    private var localBannerImage: UIImage? {
        guard let value = imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return UIImage(named: value)
    }

    private var remoteBannerURL: URL? {
        guard localBannerImage == nil else { return nil }
        return URL.loopedMediaURL(from: imageUrl)
    }
}

#Preview {
    CommunityProfileView(
        community: CommunityProfileData(
            id: 1,
            name: "Finance",
            shortName: nil,
            description: "Talk markets, careers, and everything in finance.",
            kind: .profession,
            specializationType: .unknown,
            memberCount: 1_000_000,
            imageUrl: nil,
            isFollowing: false,
            isJoined: false
        )
    )
    .environmentObject(CommentsModalManager())
    .environmentObject(FeedViewModel())
    .environmentObject(AuthViewModel())
}
