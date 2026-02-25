import Foundation
@testable import looped_iOS

struct TestError: Error, LocalizedError, Equatable {
    let message: String

    var errorDescription: String? { message }

    static func unimplemented(_ function: String = #function) -> TestError {
        TestError(message: "Unimplemented mock path: \(function)")
    }
}

enum TestDefaults {
    static func makeSuite(_ name: String = UUID().uuidString) -> UserDefaults {
        let suiteName = "looped.tests.\(name)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return .standard
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    static func clear(_ defaults: UserDefaults) {
        guard let suiteName = defaults.volatileDomainNames.first(where: { $0.hasPrefix("looped.tests.") }) else {
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
    }
}

enum TestFixtures {
    static func user(
        backendId: Int,
        handle: String? = nil,
        displayName: String? = nil,
        followerCount: Int? = nil,
        viewerHasBlocked: Bool? = nil,
        viewerBlockedBy: Bool? = nil
    ) -> User {
        User(
            id: UUID.fromBackendId(backendId),
            backendId: backendId,
            username: handle ?? "user\(backendId)",
            displayName: displayName ?? "User \(backendId)",
            firstName: "User",
            lastName: "\(backendId)",
            dateOfBirth: "1990-01-01",
            handle: handle ?? "user\(backendId)",
            companyId: 1,
            companyName: "Looped",
            bio: nil,
            profileImageURL: nil,
            isVerified: true,
            isAnonymous: false,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            followerCount: followerCount,
            followingCount: 0,
            postsCount: 0,
            commentsCount: 0,
            likesReceivedCount: 0,
            showFollowerCount: true,
            hideAnonymousPosts: false,
            messagePermission: .all,
            viewerHasBlocked: viewerHasBlocked,
            viewerBlockedBy: viewerBlockedBy,
            displayCommunity: nil,
            displaySpecialization: nil
        )
    }

    static func userDTO(
        id: Int,
        handle: String? = nil,
        displayName: String? = nil
    ) -> UserDTO {
        UserDTO(
            id: id,
            handle: handle ?? "user\(id)",
            username: handle ?? "user\(id)",
            displayName: displayName ?? "User \(id)",
            firstName: "User",
            lastName: "\(id)",
            dateOfBirth: "1990-01-01",
            companyId: 1,
            bio: nil,
            verification: VerificationDTO(method: "email", verified: true, verifiedAt: nil),
            profile: nil,
            stats: nil,
            displayCommunity: nil,
            displaySpecialization: nil,
            profileImageUrl: nil,
            showFollowerCount: true,
            hideAnonymousPosts: false,
            messagePermission: .all,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    static func identityDTO(
        provisioned: Bool,
        onboardingComplete: Bool?,
        onboardingStep: RemoteOnboardingStep?,
        user: UserDTO?,
        onboardingStageV2: String? = nil,
        onboardingContext: OnboardingContextV2DTO? = nil,
        profileCompletion: ProfileCompletionDTO? = nil
    ) -> IdentityResponseDTO {
        IdentityResponseDTO(
            sub: "sub-1",
            iss: "iss",
            aud: ["aud"],
            email: "user@example.com",
            provisioned: provisioned,
            user: user,
            onboardingComplete: onboardingComplete,
            onboardingStep: onboardingStep,
            onboardingStageV2: onboardingStageV2,
            onboardingContext: onboardingContext,
            profileCompletion: profileCompletion
        )
    }

    static func followListItem(entityId: Int, kind: UserFollowListItemKind) -> UserFollowListItem {
        let kindValue: String = kind == .anon ? "anon" : "user"
        let anonId = kind == .anon ? entityId : 0
        let userId = kind == .user ? entityId : 0
        let json = """
        {
          "principalId": \(kind == .anon ? -entityId : entityId),
          "kind": "\(kindValue)",
          "userId": \(userId),
          "anonProfileId": \(anonId),
          "id": \(entityId),
          "handle": "user\(entityId)",
          "displayName": "User \(entityId)",
          "profileImageUrl": null,
          "companyId": 1,
          "isAnonymous": \(kind == .anon ? "true" : "false")
        }
        """

        let dto = try! JSONDecoder().decode(UserFollowListItemDTO.self, from: Data(json.utf8))
        return UserFollowListItem(dto: dto)
    }

    static func post(
        backendId: Int,
        content: String = "Post \(UUID().uuidString.prefix(4))",
        createdAt: Date = Date(),
        communityId: Int? = 1
    ) -> Post {
        Post(
            id: UUID.fromBackendId(backendId),
            backendId: backendId,
            authorBackendId: 10,
            authorPrincipalId: 10,
            anonProfileId: nil,
            content: content,
            authorId: UUID.fromBackendId(10),
            authorDisplayName: "Author",
            authorHandle: "author",
            company: "Looped",
            communityId: communityId,
            communityName: "General",
            communityShortName: "Gen",
            communityKind: .company,
            isAnonymous: false,
            reactionCount: 0,
            commentsCount: 0,
            shareCount: 0,
            userReaction: nil,
            attachments: nil,
            isSaved: false,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    static func feedPage(posts: [Post], nextCursor: String? = nil) -> FeedPage {
        FeedPage(posts: posts, nextCursor: nextCursor, feedRequestId: nil)
    }

    static func communitySearchResult(
        id: Int,
        name: String,
        kind: CommunityKind,
        memberCount: Int
    ) -> CommunitySearchResult {
        CommunitySearchResult(
            id: id,
            name: name,
            shortName: nil,
            description: "",
            kind: kind,
            memberCount: memberCount,
            imageUrl: nil,
            icon: nil,
            isFollowing: false,
            isJoined: false
        )
    }

    static func conversation(
        backendId: Int,
        userName: String = "User \(Int.random(in: 1...1000))",
        unreadCount: Int = 0,
        lastMessage: String = "Hello",
        lastMessageTimestamp: Date = Date(),
        isMuted: Bool = false,
        isGroup: Bool = false
    ) -> Conversation {
        Conversation(
            id: UUID.fromBackendId(backendId),
            backendId: backendId,
            userId: UUID.fromBackendId(backendId + 1000),
            backendUserId: backendId + 1000,
            userName: userName,
            userProfileImageUrl: nil,
            lastMessage: lastMessage,
            lastMessageTimestamp: lastMessageTimestamp,
            unreadCount: unreadCount,
            isMuted: isMuted,
            hasTypingIndicator: false,
            hasSpecialStatus: false,
            isOnline: false,
            isGroup: isGroup,
            memberIds: nil
        )
    }

    static func channel(
        backendId: Int,
        name: String = "Channel",
        memberCount: Int = 3,
        isPublic: Bool = true
    ) -> Channel {
        Channel(
            id: UUID.fromBackendId(backendId),
            backendId: backendId,
            name: name,
            photoUrl: nil,
            company: "Looped",
            memberCount: memberCount,
            isPublic: isPublic,
            createdAt: Date(),
            ownerUserId: 1,
            viewerCanManageMembers: true
        )
    }

    static func messageRequest(
        backendId: Int,
        senderBackendId: Int? = nil,
        senderName: String? = "Sender",
        conversationBackendId: Int? = nil,
        channelBackendId: Int? = nil,
        isGroup: Bool = false,
        status: MessageRequestStatus = .pending
    ) -> MessageRequest {
        MessageRequest(
            id: UUID.fromBackendId(backendId),
            backendId: backendId,
            senderBackendId: senderBackendId,
            senderName: senderName,
            senderHandle: senderName?.lowercased(),
            senderProfileImageUrl: nil,
            previewText: "preview",
            previewAttachments: [],
            previewCreatedAt: Date(),
            status: status,
            conversationBackendId: conversationBackendId,
            channelBackendId: channelBackendId,
            isGroup: isGroup
        )
    }

    static func messageSearchConversationHit(
        id: String,
        conversation: Conversation,
        previewText: String = "Matched"
    ) -> MessageSearchHit {
        MessageSearchHit(
            id: id,
            type: .conversation,
            conversation: conversation,
            channel: nil,
            matchedMessage: nil,
            previewText: previewText,
            previewTimestamp: Date()
        )
    }

    static func messageSearchChannelHit(
        id: String,
        channel: Channel,
        previewText: String = "Matched"
    ) -> MessageSearchHit {
        MessageSearchHit(
            id: id,
            type: .channel,
            conversation: nil,
            channel: channel,
            matchedMessage: nil,
            previewText: previewText,
            previewTimestamp: Date()
        )
    }

    static func blockedUser(principalId: Int, backendId: Int) -> BlockedUser {
        BlockedUser(
            dto: BlockedUserDTO(
                principalId: principalId,
                id: backendId,
                kind: "user",
                handle: "user\(backendId)",
                displayName: "User \(backendId)",
                profileImageUrl: nil,
                companyId: 1,
                isAnonymous: false
            )
        )
    }

    static func notificationPreferences(allEnabled: Bool = true) -> NotificationPreferencesDTO {
        let decoder = JSONDecoder()
        let defaultTypes = try? decoder.decode(NotificationTypePreferencesDTO.self, from: Data("{}".utf8))
        var types = defaultTypes ?? zeroedTypes()
        NotificationPreferenceType.allCases.forEach { types.set(allEnabled, for: $0) }
        let channel = NotificationChannelDTO(enabled: allEnabled, types: types)
        return NotificationPreferencesDTO(
            channels: NotificationChannelsDTO(inApp: channel, push: channel, email: channel)
        )
    }

    private static func zeroedTypes() -> NotificationTypePreferencesDTO {
        var types = try! JSONDecoder().decode(NotificationTypePreferencesDTO.self, from: Data("{}".utf8))
        NotificationPreferenceType.allCases.forEach { types.set(false, for: $0) }
        return types
    }
}
