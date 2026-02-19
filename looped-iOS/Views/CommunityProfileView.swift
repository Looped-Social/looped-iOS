import SwiftUI
import UIKit

enum CommunityProfileTab: String, CaseIterable {
    case posts = "Posts"
    case hashtags = "Hashtags"
}

struct CommunityProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.loopedIsTabBarVisible) private var isTabBarVisible
    @Environment(\.loopedSetTabBarVisible) private var setTabBarVisible
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel: CommunityProfileViewModel
    @StateObject private var hashtagPostsViewModel: CommunityHashtagPostsViewModel
    @StateObject private var commentsManager = CommentsModalManager()
    @State private var selectedTab: CommunityProfileTab = .posts
    @State private var verificationTargetCommunity: CommunityProfileData?
    @State private var specializationJoinInfoSheet: SpecializationJoinInfoSheetState?
    @State private var showSpecializationJoinConfirmation = false
    @State private var showSpecializationLeaveConfirmation = false
    @State private var hasLoaded = false
    @State private var canPop: Bool?
    @State private var isAtTop = true
    @State private var specializationInfoCachedTabBarVisible: Bool?

    init(community: CommunityProfileData) {
        _viewModel = StateObject(wrappedValue: CommunityProfileViewModel(community: community))
        _hashtagPostsViewModel = StateObject(wrappedValue: CommunityHashtagPostsViewModel(communityId: community.id))
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
                .background(
                    GeometryReader { geo in
                        Color.loopedClear
                            .onChange(of: geo.frame(in: .global).minY) { _, newValue in
                                let atTop = newValue >= -20
                                if atTop != isAtTop {
                                    isAtTop = atTop
                                }
                            }
                    }
                )
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .loopedPullToRefresh(isAtTop: isAtTop) {
                if selectedTab == .hashtags {
                    await hashtagPostsViewModel.refresh()
                } else {
                    await viewModel.refresh()
                }
            }
            .task { await loadIfNeeded() }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if canPop == false {
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
        .sheet(item: $verificationTargetCommunity) { community in
            CommunityVerificationFlowView(community: community) { _ in
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
        .overlay {
            LoopedBottomDrawer(
                isPresented: specializationJoinInfoSheet != nil,
                onDismiss: { specializationJoinInfoSheet = nil }
            ) {
                if let info = specializationJoinInfoSheet {
                    SpecializationJoinInfoSheetView(
                        title: info.title,
                        message: info.message
                    )
                }
            }
        }
        .onChange(of: specializationJoinInfoSheet != nil) { _, isPresented in
            if isPresented {
                if specializationInfoCachedTabBarVisible == nil {
                    specializationInfoCachedTabBarVisible = isTabBarVisible
                }
                setTabBarVisible(false)
                return
            }

            if let cached = specializationInfoCachedTabBarVisible {
                setTabBarVisible(cached)
            }
            specializationInfoCachedTabBarVisible = nil
        }
        .onDisappear {
            if let cached = specializationInfoCachedTabBarVisible {
                setTabBarVisible(cached)
            }
            specializationInfoCachedTabBarVisible = nil
        }
        .loopedHashtagNavigationHost()
        .loopedMentionNavigationHost()
    }

    private var headerContent: some View {
        VStack(spacing: 12) {
            CommunityProfileBanner(
                name: viewModel.community.name,
                imageUrl: viewModel.community.imageUrl
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(communityTypeTitle)
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedContrast)

                        HStack(spacing: 4) {
                            Text(formattedMemberCount(viewModel.community.memberCount))
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedContrast)
                            Text("Members")
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedTextSecondary)
                        }
                    }

                    Spacer()

                    actionButtons
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
            FollowPillButtonLabel(
                title: viewModel.community.isFollowing ? "Following" : "Follow",
                isFollowing: viewModel.community.isFollowing,
                size: .regular
            )
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
        Button(action: { verificationTargetCommunity = viewModel.community }) {
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

                if viewModel.isLoadingVerification {
                    ProgressView()
                        .tint(.loopedSecondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.loopedSymbol(.semibold, size: 13))
                        .foregroundColor(.loopedTextSecondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.loopedMutedBackground.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.loopedTextSecondary.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(viewModel.isLoadingVerification)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity((viewModel.isFollowActionInFlight || viewModel.isJoinActionInFlight || viewModel.isLoadingVerification) ? 0.7 : 1)
    }

    private var specializationJoinPill: some View {
        HStack(spacing: 10) {
            Button(action: handleSpecializationJoinTap) {
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

                    if viewModel.isJoinActionInFlight {
                        ProgressView()
                            .tint(.loopedSecondary)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.loopedSymbol(.semibold, size: 13))
                            .foregroundColor(.loopedTextSecondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.loopedMutedBackground.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.loopedTextSecondary.opacity(0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSpecializationJoinActionDisabled)

            Button(action: { presentSpecializationJoinInfoSheet(emphasizeVerification: false) }) {
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
        .alert("Leave \(specializationJoinDisplay.label)?", isPresented: $showSpecializationLeaveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                Task { await viewModel.toggleJoin() }
            }
        } message: {
            Text(specializationLeaveConfirmationText())
        }
        .alert("Join \(specializationJoinDisplay.label)?", isPresented: $showSpecializationJoinConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Join") {
                Task { await viewModel.toggleJoin() }
            }
        } message: {
            Text(specializationJoinConfirmationText())
        }
    }

    private func handleSpecializationJoinTap() {
        if viewModel.community.isJoined {
            showSpecializationLeaveConfirmation = true
            return
        }

        let joinLimit = viewModel.community.joinLimit
        if joinLimit?.requiresVerificationForJoin == true {
            presentSpecializationJoinInfoSheet(emphasizeVerification: true)
            return
        }

        guard joinLimit?.canJoin != false else {
            presentSpecializationJoinInfoSheet(emphasizeVerification: false)
            return
        }

        showSpecializationJoinConfirmation = true
    }

    private var isSpecializationJoinActionDisabled: Bool {
        guard viewModel.community.kind == .specialization else { return true }
        if viewModel.isJoinActionInFlight || viewModel.isFollowActionInFlight { return true }
        guard !viewModel.community.isJoined else { return false }
        guard let joinLimit = viewModel.community.joinLimit else { return false }
        if joinLimit.requiresVerificationForJoin { return false }
        return !joinLimit.canJoin
    }

    private var tabBar: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Color.loopedTextSecondary.opacity(0.12))
                .frame(height: 1)

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
                    LoopedInlineLoadingIndicator()
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
        LazyVStack(spacing: 0) {
            if hashtagPostsViewModel.isLoading && hashtagPostsViewModel.posts.isEmpty {
                ForEach(0..<6, id: \.self) { index in
                    PostCardSkeleton(showsMedia: index % 3 != 0)

                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.loopedTextSecondary.opacity(0.1))
                }
            } else if hashtagPostsViewModel.posts.isEmpty {
                VStack(spacing: 12) {
                    Text("No posts with hashtags yet.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)

                    Text("Add a #hashtag to get started.")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ForEach(hashtagPostsViewModel.posts) { post in
                    PostCard(
                        post: post,
                        showsCommunityLabel: true,
                        onUpdate: { updated in
                            hashtagPostsViewModel.updatePost(updated)
                        },
                        onDelete: { deleted in
                            hashtagPostsViewModel.removePost(backendId: deleted.backendId)
                        }
                    )
                        .onAppear {
                            Task { await hashtagPostsViewModel.loadMoreIfNeeded(currentPost: post) }
                        }

                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.loopedTextSecondary.opacity(0.1))
                }

                if hashtagPostsViewModel.isLoadingMore {
                    LoopedInlineLoadingIndicator()
                }
            }

            if let errorMessage = hashtagPostsViewModel.errorMessage, hashtagPostsViewModel.posts.isEmpty {
                Text(errorMessage)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .padding(.top, 16)
            }
        }
        .task {
            await hashtagPostsViewModel.loadIfNeeded()
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

        switch verification.status {
        case .active:
            return VerificationDisplay(
                title: "Verified",
                subtitle: expiryText(for: verification, inactivePrefix: nil),
                icon: "checkmark.seal.fill",
                color: .loopedPrimary
            )
        case .pending:
            return VerificationDisplay(
                title: "Pending",
                subtitle: "Awaiting approval",
                icon: "clock.fill",
                color: .loopedSecondary
            )
        case .rejected:
            return VerificationDisplay(
                title: "Rejected",
                subtitle: "Tap to verify again",
                icon: "xmark.octagon.fill",
                color: .loopedError
            )
        case .expired:
            return VerificationDisplay(
                title: "Expired",
                subtitle: expiryText(for: verification, inactivePrefix: "Expired") ?? "Tap to verify",
                icon: "exclamationmark.circle",
                color: .loopedSecondary
            )
        case .unknown:
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
    }

    private func expiryText(for verification: CommunityVerification, inactivePrefix: String?) -> String? {
        guard verification.verified || verification.status == .expired else { return nil }
        guard let expiresAt = verification.expiresAt else {
            if let inactivePrefix {
                return inactivePrefix
            }
            return "Never expires"
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

    private var communityTypeTitle: String {
        switch viewModel.community.kind {
        case .company:
            return "Workplace"
        case .school:
            return "School"
        case .specialization:
            switch viewModel.community.specializationType {
            case .major:
                return "Major"
            case .field:
                return "Field"
            case .unknown:
                return "Specialization"
            }
        case .unknown:
            return "Community"
        }
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
    }

    private var specializationJoinDisplay: SpecializationJoinDisplay {
        let label = viewModel.community.specializationLabel ?? "Specialization"
        let joinLimit = viewModel.community.joinLimit
        let subtitle = specializationJoinSubtitle(joinLimit: joinLimit)

        if viewModel.community.isJoined {
            return SpecializationJoinDisplay(
                label: label,
                title: "Joined",
                subtitle: subtitle,
                icon: "person.crop.circle.badge.checkmark",
                color: .loopedPrimary
            )
        }
        if joinLimit?.requiresVerificationForJoin == true {
            return SpecializationJoinDisplay(
                label: label,
                title: "Not Verified Yet",
                subtitle: subtitle,
                icon: "lock.fill",
                color: .loopedSecondary
            )
        }
        if joinLimit?.canJoin == false {
            let title = joinLimit?.cooldownActive == true ? "Cooldown Active" : "Join Limit Reached"
            let icon = joinLimit?.cooldownActive == true ? "clock.fill" : "nosign"
            return SpecializationJoinDisplay(
                label: label,
                title: title,
                subtitle: subtitle,
                icon: icon,
                color: .loopedTextSecondary
            )
        }
        return SpecializationJoinDisplay(
            label: label,
            title: "Join \(label)",
            subtitle: subtitle,
            icon: "person.crop.circle.badge.plus",
            color: .loopedSecondary
        )
    }

    private func specializationJoinSubtitle(joinLimit: SpecializationJoinLimit?) -> String? {
        guard let joinLimit else {
            return viewModel.community.isJoined ? "Tap to leave" : "Tap to join"
        }

        if joinLimit.requiresVerificationForJoin {
            let required = joinLimit.requiredVerificationKind?.displayName.lowercased() ?? "company or school"
            return "Verify one \(required) first."
        }

        if joinLimit.cooldownActive, let cooldownEndsAt = joinLimit.cooldownEndsAt {
            return "Resets \(Self.expiryFormatter.string(from: cooldownEndsAt))"
        }

        if !joinLimit.canJoin {
            return joinLimit.cooldownActive ? "Cooldown active" : "No joins left"
        }

        let remaining = max(0, joinLimit.remaining)
        return "\(remaining)/\(joinLimit.limit) joins left"
    }

    private func specializationJoinInfoText(joinLimit: SpecializationJoinLimit?, label: String) -> String {
        guard let joinLimit else {
            return """
            Joining a \(label.lowercased()) helps personalize your experience.
            You may be limited in how often you can change.
            """
        }

        if joinLimit.requiresVerificationForJoin {
            let required = joinLimit.requiredVerificationKind?.displayName.lowercased() ?? "company or school"
            var lines: [String] = []
            lines.append("You're not verified in a \(required) community yet.")
            lines.append("Verify in at least one \(required) first to unlock joining \(joinLimit.pluralLabel.lowercased()).")
            if joinLimit.cooldownMonths > 0 {
                lines.append("You get \(joinLimit.limit) joins every \(joinLimit.cooldownMonths) months, so leaving and rejoining still counts in that window.")
            } else {
                lines.append("You get up to \(joinLimit.limit) total joins in your current window.")
            }
            return lines.joined(separator: "\n")
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
            lines.append("If you leave a \(label.lowercased()), that still uses a join in the same window, so choose carefully.")
        } else {
            lines.append("You've used all joins in this window. Wait for the reset before changing your \(joinLimit.pluralLabel.lowercased()).")
        }
        return lines.joined(separator: "\n")
    }

    private func presentSpecializationJoinInfoSheet(emphasizeVerification: Bool) {
        let label = viewModel.community.specializationLabel ?? "Specialization"
        let joinLimit = viewModel.community.joinLimit
        let title: String

        if viewModel.community.isJoined {
            title = "About \(label) Joins"
        } else if emphasizeVerification || joinLimit?.requiresVerificationForJoin == true {
            title = "Verify to Join \(label)"
        } else if joinLimit?.canJoin == false {
            title = "Join Limits for \(label)"
        } else {
            title = "About Joining \(label)"
        }

        specializationJoinInfoSheet = SpecializationJoinInfoSheetState(
            title: title,
            message: specializationJoinInfoText(joinLimit: joinLimit, label: label)
        )
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

    private func specializationJoinConfirmationText() -> String {
        let label = specializationJoinDisplay.label.lowercased()
        guard let joinLimit = viewModel.community.joinLimit else {
            return "Joining this \(label) counts toward your limited join changes. Are you sure you want to continue?"
        }

        let remaining = max(0, joinLimit.remaining)
        let joinedAfterConfirm = joinLimit.joinedCount + 1
        var parts: [String] = []
        if remaining <= 1 {
            parts.append("This is your last available join right now.")
        } else {
            parts.append("You have \(remaining)/\(joinLimit.limit) joins left.")
        }
        parts.append("If you join now, you’ll be at \(joinedAfterConfirm)/\(joinLimit.limit).")

        if let cooldownEndsAt = joinLimit.cooldownEndsAt {
            parts.append("Changes reset on \(Self.expiryFormatter.string(from: cooldownEndsAt)).")
        } else if joinLimit.cooldownMonths > 0 {
            parts.append("Changes reset every \(joinLimit.cooldownMonths) months.")
        }

        parts.append("Join this \(label)?")
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
        case .field:
            singular = "field"
        case .unknown:
            singular = "specialization"
        }
        return count == 1 ? singular : "\(singular)s"
    }

    private struct SpecializationJoinInfoSheetState: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private struct SpecializationJoinInfoSheetView: View {
        let title: String
        let message: String

        var body: some View {
            VStack(spacing: 8) {
                Text(title)
                    .font(.loopedHeadlineScaled)
                    .foregroundColor(.loopedTextPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.loopedSubheadlineScaled)
                    .foregroundColor(.loopedTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}

struct CommunityProfileBanner: View {
    @Environment(\.colorScheme) private var colorScheme

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
                        bannerBackdropColor
                    case .empty:
                        bannerBackdropColor
                    @unknown default:
                        bannerBackdropColor
                    }
                }
            } else {
                bannerBackdropColor
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bannerBackdropColor)
    }

    private var bannerBackdropColor: Color {
        colorScheme == .dark ? .loopedWhite : .loopedBackground
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
            kind: .company,
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
