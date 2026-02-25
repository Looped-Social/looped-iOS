import SwiftUI

struct PeopleRecommendationRailSection: View {
    @Environment(\.colorScheme) private var colorScheme

    let rail: PeopleRecommendationRailPage
    let isLoadingMore: Bool
    let canConnect: (PeopleRecommendationItem) -> Bool
    let isConnecting: (Int) -> Bool
    let onProfileTap: (PeopleRecommendationItem) -> Void
    let onConnectTap: (PeopleRecommendationItem) -> Void
    let onHideTap: (PeopleRecommendationItem) -> Void
    let onLessLikeThisTap: (PeopleRecommendationItem) -> Void
    let onItemAppear: (PeopleRecommendationItem) -> Void
    let onItemDisappear: (PeopleRecommendationItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(rail.title)
                    .font(.loopedSubheadMedium)
                    .foregroundColor(.loopedTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(rail.items) { item in
                        PeopleRecommendationCard(
                            item: item,
                            fallbackReasonText: fallbackReasonText(for: item),
                            canConnect: canConnect(item),
                            isConnecting: isConnecting(item.user.id),
                            onProfileTap: {
                                onProfileTap(item)
                            },
                            onConnectTap: {
                                onConnectTap(item)
                            },
                            onHideTap: {
                                onHideTap(item)
                            },
                            onLessLikeThisTap: {
                                onLessLikeThisTap(item)
                            }
                        )
                        .onAppear {
                            onItemAppear(item)
                        }
                        .onDisappear {
                            onItemDisappear(item)
                        }
                    }

                    if isLoadingMore {
                        loadingCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .tint(.loopedPrimary)
            Text("Loading")
                .font(.loopedSmallText)
                .foregroundColor(.loopedTextSecondary)
            Spacer()
        }
        .frame(width: 160, height: 248)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.loopedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    Color.loopedWhite.opacity(colorScheme == .dark ? 0.2 : 0.78),
                    lineWidth: 0.85
                )
                .blendMode(.overlay)
        )
        .shadow(
            color: Color.loopedBlack.opacity(colorScheme == .dark ? 0.12 : 0.06),
            radius: colorScheme == .dark ? 7 : 4,
            x: 0,
            y: colorScheme == .dark ? 4 : 2
        )
        .shadow(
            color: Color.loopedBlack.opacity(colorScheme == .dark ? 0.05 : 0.025),
            radius: 2,
            x: 0,
            y: 1
        )
    }

    private func fallbackReasonText(for item: PeopleRecommendationItem) -> String? {
        guard let communityLabel = fallbackCommunityLabel(for: item) else { return nil }
        return "Verified in \(communityLabel)"
    }

    private func fallbackCommunityLabel(for item: PeopleRecommendationItem) -> String? {
        if let itemCommunityName = normalizedCommunityName(item.user.community?.name) {
            return itemCommunityName
        }
        if let railCommunityName = normalizedCommunityName(rail.community?.name) {
            return railCommunityName
        }
        if let titleDerivedLabel = normalizedCommunityName(communityNameFromRailTitle()) {
            return titleDerivedLabel
        }
        return nil
    }

    private func communityNameFromRailTitle() -> String? {
        let prefix = "People in "
        guard rail.title.hasPrefix(prefix) else { return nil }
        let suffix = String(rail.title.dropFirst(prefix.count))
        return suffix
    }

    private func normalizedCommunityName(_ rawValue: String?) -> String? {
        let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct PeopleRecommendationCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let item: PeopleRecommendationItem
    let fallbackReasonText: String?
    let canConnect: Bool
    let isConnecting: Bool
    let onProfileTap: () -> Void
    let onConnectTap: () -> Void
    let onHideTap: () -> Void
    let onLessLikeThisTap: () -> Void

    @State private var isProfileOpen = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Menu {
                    if item.actions.canHide {
                        Button("Hide", action: onHideTap)
                    }
                    if item.actions.canLessLikeThis {
                        Button("Less like this", action: onLessLikeThisTap)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.loopedSymbol(.semibold, size: 12))
                        .foregroundColor(.loopedTextSecondary)
                        .frame(width: 24, height: 24)
                        .background(Color.loopedMutedBackground.opacity(0.7))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            ProfileAvatarView(imageURL: item.user.avatarURL, size: 70)
                .overlay(
                    Circle()
                        .stroke(Color.loopedMutedBackground.opacity(0.35), lineWidth: 1)
                )
                .padding(.top, 4)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                Text(item.user.displayName)
                    .font(.loopedCustom(.semibold, size: 17))
                    .foregroundColor(.loopedTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text("@\(item.user.handle)")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            if let reasonText {
                HStack(spacing: 5) {
                    Image(systemName: reasonIconName)
                        .font(.loopedSymbol(.medium, size: reasonIconSize))
                        .foregroundColor(reasonIconColor)
                    Text(reasonText)
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }

            Spacer(minLength: 0)

            Button(action: onConnectTap) {
                FollowPillButtonLabel(
                    title: followButtonTitle,
                    isFollowing: isFollowingVisualState,
                    size: .compact,
                    fillWidth: true,
                    isEnabled: true,
                    showsLoadingIndicator: isConnecting
                )
            }
            .buttonStyle(.plain)
            .disabled(!canConnect || isConnecting)
            .frame(maxWidth: .infinity)
            .padding(.top, 0)
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(width: 160, height: 248)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(cardFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    Color.loopedWhite.opacity(colorScheme == .dark ? 0.2 : 0.78),
                    lineWidth: 0.85
                )
                .blendMode(.overlay)
        )
        .shadow(
            color: Color.loopedBlack.opacity(colorScheme == .dark ? 0.12 : 0.06),
            radius: colorScheme == .dark ? 7 : 4,
            x: 0,
            y: colorScheme == .dark ? 4 : 2
        )
        .shadow(
            color: Color.loopedBlack.opacity(colorScheme == .dark ? 0.05 : 0.025),
            radius: 2,
            x: 0,
            y: 1
        )
        .background(
            NavigationLink(isActive: $isProfileOpen) {
                UserProfileView(userId: item.user.id)
            } label: {
                EmptyView()
            }
            .hidden()
        )
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .onTapGesture {
            onProfileTap()
            isProfileOpen = true
        }
    }

    private var reasonText: String? {
        if let selectedReason, !isSuppressedReason(selectedReason) {
            return selectedReason.text
        }

        return fallbackReasonText
    }

    private var reasonIconName: String {
        if let selectedReason, !isSuppressedReason(selectedReason) {
            let code = selectedReason.code.uppercased()
            if code.contains("MUTUAL") { return "person.2.fill" }
            if code.contains("COMMUNITY") { return "checkmark.seal.fill" }
            if code.contains("DISCOVERY") { return "sparkles" }
        }
        if fallbackReasonText != nil {
            return "checkmark.seal.fill"
        }
        return "person.crop.circle.badge.checkmark"
    }

    private var reasonIconColor: Color {
        if reasonIconName == "checkmark.seal.fill" {
            return .loopedVerifiedBadge
        }
        return .loopedTextSecondary
    }

    private var reasonIconSize: CGFloat {
        reasonIconName == "checkmark.seal.fill" ? 15 : 10
    }

    private var selectedReason: PeopleRecommendationReason? {
        if let mutual = item.reasons.first(where: { reason in
            reason.code.uppercased().contains("MUTUAL")
        }) {
            return mutual
        }
        if let community = item.reasons.first(where: { reason in
            reason.code.uppercased().contains("COMMUNITY")
        }) {
            return community
        }
        if let nonSuppressed = item.reasons.first(where: { reason in
            !isSuppressedReason(reason)
        }) {
            return nonSuppressed
        }
        return item.reasons.first
    }

    private var cardFillColor: Color {
        .loopedBackground
    }

    private var followButtonTitle: String {
        canConnect ? (isConnecting ? "Following" : "Follow") : "Following"
    }

    private var isFollowingVisualState: Bool {
        (!canConnect) || (isConnecting && canConnect)
    }

    private func isSuppressedReason(_ reason: PeopleRecommendationReason) -> Bool {
        let normalizedCode = reason.code.uppercased()
        let normalizedText = reason.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return normalizedCode.contains("DISCOVERY") || normalizedText.contains("SUGGESTED FOR YOU")
    }
}
