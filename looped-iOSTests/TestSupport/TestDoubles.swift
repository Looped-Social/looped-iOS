import Foundation
import Combine
@testable import looped_iOS
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
typealias AppUser = looped_iOS.User

private func unimplemented<T>(_ function: String = #function) throws -> T {
    throw TestError.unimplemented(function)
}

final class MockFeedService: FeedServiceProtocol {
    var fetchFeedCalls: [(limit: Int, cursor: String?, communityId: Int?, mode: FeedMode)] = []
    var fetchFeedHandler: ((Int, String?, Int?, FeedMode) async throws -> FeedPage)?
    var fetchTrendingPostsCalls: [(limit: Int, communityId: Int?)] = []
    var fetchTrendingPostsHandler: ((Int, Int?) async throws -> [TrendingPost])?

    var searchPostsCalls: [(query: String, limit: Int, cursor: String?)] = []
    var searchPostsHandler: ((String, Int, String?) async throws -> FeedPage)?
    var fetchMyContentCalls: [(limit: Int, cursor: String?, includePostPreview: Bool)] = []
    var fetchMyContentHandler: ((Int, String?, Bool) async throws -> UserContentPage)?
    var fetchUserContentCalls: [(userId: Int, limit: Int, cursor: String?, includePostPreview: Bool)] = []
    var fetchUserContentHandler: ((Int, Int, String?, Bool) async throws -> UserContentPage)?
    var fetchAnonContentCalls: [(anonProfileId: Int, limit: Int, cursor: String?, includePostPreview: Bool)] = []
    var fetchAnonContentHandler: ((Int, Int, String?, Bool) async throws -> UserContentPage)?
    var createPostCalls: [(content: String, isAnonymous: Bool, communityId: Int, mediaAssetId: Int?, mediaAssetIds: [Int]?, poll: PollDraft?)] = []
    var createPostHandler: ((String, Bool, Int, Int?, [Int]?, PollDraft?) async throws -> Post)?
    var updatePostCalls: [(postId: Int, content: String, isAnonymous: Bool, communityId: Int?, removeMedia: Bool)] = []
    var updatePostHandler: ((Int, String, Bool, Int?, Bool) async throws -> Post)?

    func fetchFeed(limit: Int, cursor: String?, communityId: Int?, mode: FeedMode) async throws -> FeedPage {
        fetchFeedCalls.append((limit, cursor, communityId, mode))
        if let handler = fetchFeedHandler {
            return try await handler(limit, cursor, communityId, mode)
        }
        throw TestError.unimplemented(#function)
    }

    func fetchCommunityHashtagPosts(communityId: Int, limit: Int, cursor: String?) async throws -> FeedPage {
        try unimplemented(#function)
    }

    func fetchTrendingPosts(limit: Int, communityId: Int?) async throws -> [TrendingPost] {
        fetchTrendingPostsCalls.append((limit, communityId))
        if let handler = fetchTrendingPostsHandler {
            return try await handler(limit, communityId)
        }
        throw TestError.unimplemented(#function)
    }

    func searchPosts(query: String, limit: Int, cursor: String?) async throws -> FeedPage {
        searchPostsCalls.append((query, limit, cursor))
        if let handler = searchPostsHandler {
            return try await handler(query, limit, cursor)
        }
        throw TestError.unimplemented(#function)
    }

    func createPost(content: String, isAnonymous: Bool, communityId: Int, mediaAssetId: Int?, mediaAssetIds: [Int]?, poll: PollDraft?) async throws -> Post {
        createPostCalls.append((content, isAnonymous, communityId, mediaAssetId, mediaAssetIds, poll))
        if let handler = createPostHandler {
            return try await handler(content, isAnonymous, communityId, mediaAssetId, mediaAssetIds, poll)
        }
        throw TestError.unimplemented(#function)
    }

    func updatePost(postId: Int, content: String, isAnonymous: Bool, communityId: Int?, removeMedia: Bool) async throws -> Post {
        updatePostCalls.append((postId, content, isAnonymous, communityId, removeMedia))
        if let handler = updatePostHandler {
            return try await handler(postId, content, isAnonymous, communityId, removeMedia)
        }
        throw TestError.unimplemented(#function)
    }

    func reactToPost(postId: Int, communityId: Int?, reaction: ReactionType) async throws -> PostReactionResponse {
        try unimplemented(#function)
    }

    func unlikePost(postId: Int, communityId: Int?) async throws -> PostReactionResponse {
        try unimplemented(#function)
    }

    func sharePost(postId: Int) async throws -> PostShareResponse {
        try unimplemented(#function)
    }

    func repostPost(postId: Int) async throws -> PostRepostResponse {
        try unimplemented(#function)
    }

    func unrepostPost(postId: Int) async throws -> PostRepostResponse {
        try unimplemented(#function)
    }

    func fetchUserPosts(userId: Int, limit: Int, cursor: String?) async throws -> FeedPage {
        try unimplemented(#function)
    }

    func fetchHashtagPosts(hashtag: String, limit: Int, cursor: String?) async throws -> FeedPage {
        try unimplemented(#function)
    }

    func fetchPost(postId: Int) async throws -> Post {
        try unimplemented(#function)
    }

    func fetchLikedPosts(limit: Int, cursor: String?) async throws -> FeedPage {
        try unimplemented(#function)
    }

    func fetchSavedPosts(limit: Int, cursor: String?) async throws -> FeedPage {
        try unimplemented(#function)
    }

    func fetchRepostedPosts(limit: Int, cursor: String?) async throws -> FeedPage {
        try unimplemented(#function)
    }

    func fetchReposters(postId: Int, limit: Int, cursor: String?) async throws -> RepostersPage {
        try unimplemented(#function)
    }

    func fetchUserReposts(userId: Int, limit: Int, cursor: String?) async throws -> FeedPage {
        try unimplemented(#function)
    }

    func fetchMyReposts(limit: Int, cursor: String?) async throws -> FeedPage {
        try unimplemented(#function)
    }

    func fetchAnonReposts(anonProfileId: Int, limit: Int, cursor: String?) async throws -> FeedPage {
        try unimplemented(#function)
    }

    func fetchMyContent(limit: Int, cursor: String?, includePostPreview: Bool) async throws -> UserContentPage {
        fetchMyContentCalls.append((limit, cursor, includePostPreview))
        if let handler = fetchMyContentHandler {
            return try await handler(limit, cursor, includePostPreview)
        }
        throw TestError.unimplemented(#function)
    }

    func fetchUserContent(userId: Int, limit: Int, cursor: String?, includePostPreview: Bool) async throws -> UserContentPage {
        fetchUserContentCalls.append((userId, limit, cursor, includePostPreview))
        if let handler = fetchUserContentHandler {
            return try await handler(userId, limit, cursor, includePostPreview)
        }
        throw TestError.unimplemented(#function)
    }

    func fetchAnonContent(anonProfileId: Int, limit: Int, cursor: String?, includePostPreview: Bool) async throws -> UserContentPage {
        fetchAnonContentCalls.append((anonProfileId, limit, cursor, includePostPreview))
        if let handler = fetchAnonContentHandler {
            return try await handler(anonProfileId, limit, cursor, includePostPreview)
        }
        throw TestError.unimplemented(#function)
    }

    func fetchAnonPosts(anonProfileId: Int, limit: Int, cursor: String?) async throws -> FeedPage {
        try unimplemented(#function)
    }

    func savePost(postId: Int, communityId: Int?) async throws -> Bool {
        try unimplemented(#function)
    }

    func removeSavedPost(postId: Int, communityId: Int?) async throws -> Bool {
        try unimplemented(#function)
    }

    func deletePost(postId: Int, communityId: Int?, asAnon: Bool) async throws -> PostDeleteResponse {
        try unimplemented(#function)
    }
}

final class MockCommunityService: CommunityServiceProtocol {
    var fetchFollowedCommunitiesCalls: [(limit: Int, cursor: String?, order: CommunityFollowOrder)] = []
    var fetchFollowedCommunitiesHandler: ((Int, String?, CommunityFollowOrder) async throws -> CommunityPage)?

    var fetchRecommendedCalls: [(kind: CommunitySearchKind?, limit: Int, cursor: String?)] = []
    var fetchRecommendedHandler: ((CommunitySearchKind?, Int, String?) async throws -> SearchResultPage<CommunitySearchResult>)?

    var searchCommunitiesCalls: [(query: String, limit: Int, cursor: String?, kind: CommunitySearchKind?)] = []
    var searchCommunitiesHandler: ((String, Int, String?, CommunitySearchKind?) async throws -> SearchResultPage<CommunitySearchResult>)?

    var fetchCommunityDomainsCalls: [Int] = []
    var fetchCommunityDomainsHandler: ((Int) async throws -> [String])?

    var fetchCommunityDetailsDTOCalls: [(communityId: Int, kind: CommunityKind)] = []
    var fetchCommunityDetailsDTOHandler: ((Int, CommunityKind) async throws -> CommunityDetailsDTO)?

    var fetchSpecializationJoinLimitsCalls: [CommunitySpecializationType?] = []
    var fetchSpecializationJoinLimitsHandler: ((CommunitySpecializationType?) async throws -> [SpecializationJoinLimit])?

    func fetchFollowedCommunities(limit: Int, cursor: String?, order: CommunityFollowOrder) async throws -> CommunityPage {
        fetchFollowedCommunitiesCalls.append((limit, cursor, order))
        if let handler = fetchFollowedCommunitiesHandler {
            return try await handler(limit, cursor, order)
        }
        throw TestError.unimplemented(#function)
    }

    func fetchRecommendedCommunities(kind: CommunitySearchKind?, limit: Int, cursor: String?) async throws -> SearchResultPage<CommunitySearchResult> {
        fetchRecommendedCalls.append((kind, limit, cursor))
        if let handler = fetchRecommendedHandler {
            return try await handler(kind, limit, cursor)
        }
        throw TestError.unimplemented(#function)
    }

    func fetchCommunityDetails(communityId: Int) async throws -> CommunityProfileData {
        try unimplemented(#function)
    }

    func fetchCommunityDetailsDTO(communityId: Int, kind: CommunityKind) async throws -> CommunityDetailsDTO {
        fetchCommunityDetailsDTOCalls.append((communityId, kind))
        if let handler = fetchCommunityDetailsDTOHandler {
            return try await handler(communityId, kind)
        }
        throw TestError.unimplemented(#function)
    }

    func fetchCommunityDomains(communityId: Int) async throws -> [String] {
        fetchCommunityDomainsCalls.append(communityId)
        if let handler = fetchCommunityDomainsHandler {
            return try await handler(communityId)
        }
        throw TestError.unimplemented(#function)
    }

    func fetchPostableCommunities() async throws -> [CommunitySummary] {
        try unimplemented(#function)
    }

    func fetchJoinedSpecializations(type: CommunitySpecializationType?) async throws -> [DisplayCommunity] {
        try unimplemented(#function)
    }

    func fetchSpecializationJoinLimits(type: CommunitySpecializationType?) async throws -> [SpecializationJoinLimit] {
        fetchSpecializationJoinLimitsCalls.append(type)
        if let handler = fetchSpecializationJoinLimitsHandler {
            return try await handler(type)
        }
        throw TestError.unimplemented(#function)
    }

    func searchCommunities(query: String, limit: Int, cursor: String?, kind: CommunitySearchKind?) async throws -> SearchResultPage<CommunitySearchResult> {
        searchCommunitiesCalls.append((query, limit, cursor, kind))
        if let handler = searchCommunitiesHandler {
            return try await handler(query, limit, cursor, kind)
        }
        throw TestError.unimplemented(#function)
    }

    func followCommunity(id: Int) async throws {
        throw TestError.unimplemented(#function)
    }

    func unfollowCommunity(id: Int) async throws {
        throw TestError.unimplemented(#function)
    }

    func followSpecialization(id: Int) async throws {
        throw TestError.unimplemented(#function)
    }

    func unfollowSpecialization(id: Int) async throws {
        throw TestError.unimplemented(#function)
    }

    func joinSpecialization(id: Int) async throws {
        throw TestError.unimplemented(#function)
    }

    func unjoinSpecialization(id: Int) async throws {
        throw TestError.unimplemented(#function)
    }

    func fetchCommunityPermissions(communityId: Int) async throws -> CommunityPermissions {
        try unimplemented(#function)
    }
}

final class MockDiscoveryService: DiscoveryServiceProtocol {
    var searchLoopsCalls: [(query: String, limit: Int, cursor: String?)] = []
    var searchLoopsHandler: ((String, Int, String?) async throws -> SearchResultPage<LoopDTO>)?

    var searchHashtagsCalls: [(query: String, limit: Int, cursor: String?)] = []
    var searchHashtagsHandler: ((String, Int, String?) async throws -> SearchResultPage<HashtagDTO>)?

    var fetchRecommendedSpecializationsCalls: [Int] = []
    var fetchRecommendedSpecializationsHandler: ((Int) async throws -> RecommendedSpecializations)?

    var browseSpecializationsCalls: [(type: CommunitySpecializationType, limit: Int, cursor: String?)] = []
    var browseSpecializationsHandler: ((CommunitySpecializationType, Int, String?) async throws -> SearchResultPage<CommunitySearchResult>)?

    var fetchMajorsIndexCallCount = 0
    var fetchMajorsIndexHandler: (() async throws -> [SpecializationIndexItem])?

    var fetchFieldsIndexCallCount = 0
    var fetchFieldsIndexHandler: (() async throws -> [SpecializationIndexItem])?

    func searchLoops(query: String, limit: Int, cursor: String?) async throws -> SearchResultPage<LoopDTO> {
        searchLoopsCalls.append((query, limit, cursor))
        if let handler = searchLoopsHandler {
            return try await handler(query, limit, cursor)
        }
        throw TestError.unimplemented(#function)
    }

    func searchHashtags(query: String, limit: Int, cursor: String?) async throws -> SearchResultPage<HashtagDTO> {
        searchHashtagsCalls.append((query, limit, cursor))
        if let handler = searchHashtagsHandler {
            return try await handler(query, limit, cursor)
        }
        throw TestError.unimplemented(#function)
    }

    func fetchRecommendedSpecializations(limit: Int) async throws -> RecommendedSpecializations {
        fetchRecommendedSpecializationsCalls.append(limit)
        if let handler = fetchRecommendedSpecializationsHandler {
            return try await handler(limit)
        }
        throw TestError.unimplemented(#function)
    }

    func browseSpecializations(type: CommunitySpecializationType, limit: Int, cursor: String?) async throws -> SearchResultPage<CommunitySearchResult> {
        browseSpecializationsCalls.append((type, limit, cursor))
        if let handler = browseSpecializationsHandler {
            return try await handler(type, limit, cursor)
        }
        throw TestError.unimplemented(#function)
    }

    func fetchMajorsIndex() async throws -> [SpecializationIndexItem] {
        fetchMajorsIndexCallCount += 1
        if let handler = fetchMajorsIndexHandler {
            return try await handler()
        }
        throw TestError.unimplemented(#function)
    }

    func fetchFieldsIndex() async throws -> [SpecializationIndexItem] {
        fetchFieldsIndexCallCount += 1
        if let handler = fetchFieldsIndexHandler {
            return try await handler()
        }
        throw TestError.unimplemented(#function)
    }
}

final class MockPeopleRecommendationService: PeopleRecommendationServiceProtocol {
    var fetchRailsCalls: [(surface: PeopleRecommendationSurface, communityId: Int?, rails: [PeopleRecommendationRail]?, limitPerRail: Int?)] = []
    var fetchRailsHandler: ((PeopleRecommendationSurface, Int?, [PeopleRecommendationRail]?, Int?) async throws -> PeopleRecommendationRailsBundle)?

    var fetchRailCalls: [(rail: PeopleRecommendationRail, surface: PeopleRecommendationSurface, communityId: Int?, limit: Int?, cursor: String?)] = []
    var fetchRailHandler: ((PeopleRecommendationRail, PeopleRecommendationSurface, Int?, Int?, String?) async throws -> PeopleRecommendationRailPage)?

    var sendFeedbackCalls: [[PeopleRecommendationFeedbackEvent]] = []
    var sendFeedbackHandler: (([PeopleRecommendationFeedbackEvent]) async throws -> PeopleRecommendationFeedbackResponse)?

    func fetchRails(
        surface: PeopleRecommendationSurface,
        communityId: Int?,
        rails: [PeopleRecommendationRail]?,
        limitPerRail: Int?
    ) async throws -> PeopleRecommendationRailsBundle {
        fetchRailsCalls.append((surface, communityId, rails, limitPerRail))
        if let handler = fetchRailsHandler {
            return try await handler(surface, communityId, rails, limitPerRail)
        }
        throw TestError.unimplemented(#function)
    }

    func fetchRail(
        rail: PeopleRecommendationRail,
        surface: PeopleRecommendationSurface,
        communityId: Int?,
        limit: Int?,
        cursor: String?
    ) async throws -> PeopleRecommendationRailPage {
        fetchRailCalls.append((rail, surface, communityId, limit, cursor))
        if let handler = fetchRailHandler {
            return try await handler(rail, surface, communityId, limit, cursor)
        }
        throw TestError.unimplemented(#function)
    }

    func sendFeedback(events: [PeopleRecommendationFeedbackEvent]) async throws -> PeopleRecommendationFeedbackResponse {
        sendFeedbackCalls.append(events)
        if let handler = sendFeedbackHandler {
            return try await handler(events)
        }
        throw TestError.unimplemented(#function)
    }
}

final class MockCommunityVerificationService: CommunityVerificationServiceProtocol {
    var fetchCommunityVerificationsCallCount = 0
    var fetchCommunityVerificationsHandler: (() async throws -> [CommunityVerification])?

    var startVerificationCalls: [(communityId: Int, method: CommunityVerificationMethod, email: String?)] = []
    var startVerificationHandler: ((Int, CommunityVerificationMethod, String?) async throws -> CommunityVerificationStartResponse)?

    var finishVerificationCalls: [(communityId: Int, request: CommunityVerificationFinishRequest)] = []
    var finishVerificationHandler: ((Int, CommunityVerificationFinishRequest) async throws -> CommunityVerificationFinishResponse)?

    var unverifyCommunityCalls: [Int] = []
    var unverifyCommunityHandler: ((Int) async throws -> CommunityVerificationUnverifyResponse)?

    func fetchCommunityVerifications() async throws -> [CommunityVerification] {
        fetchCommunityVerificationsCallCount += 1
        if let handler = fetchCommunityVerificationsHandler {
            return try await handler()
        }
        throw TestError.unimplemented(#function)
    }

    func startVerification(
        communityId: Int,
        method: CommunityVerificationMethod,
        email: String?
    ) async throws -> CommunityVerificationStartResponse {
        startVerificationCalls.append((communityId, method, email))
        if let handler = startVerificationHandler {
            return try await handler(communityId, method, email)
        }
        throw TestError.unimplemented(#function)
    }

    func finishVerification(
        communityId: Int,
        request: CommunityVerificationFinishRequest
    ) async throws -> CommunityVerificationFinishResponse {
        finishVerificationCalls.append((communityId, request))
        if let handler = finishVerificationHandler {
            return try await handler(communityId, request)
        }
        throw TestError.unimplemented(#function)
    }

    func unverifyCommunity(communityId: Int) async throws -> CommunityVerificationUnverifyResponse {
        unverifyCommunityCalls.append(communityId)
        if let handler = unverifyCommunityHandler {
            return try await handler(communityId)
        }
        throw TestError.unimplemented(#function)
    }
}

final class MockMessageService: MessageServiceProtocol {
    var listConversationsCalls: [String?] = []
    var listConversationsHandler: ((String?) async throws -> ConversationPage)?

    var fetchMessageRequestsCalls: [String?] = []
    var fetchMessageRequestsHandler: ((String?) async throws -> MessageRequestPage)?

    var getChannelsCalls: [String?] = []
    var getChannelsHandler: ((String?) async throws -> ChannelPage)?

    var approveRequestCalls: [Int] = []
    var approveRequestHandler: ((Int) async throws -> Void)?

    var rejectRequestCalls: [Int] = []
    var rejectRequestHandler: ((Int) async throws -> Void)?

    var searchMessagesCalls: [(query: String, limit: Int, cursor: String?)] = []
    var searchMessagesHandler: ((String, Int, String?) async throws -> MessageSearchPage)?

    var startConversationCalls: [Int] = []
    var startConversationHandler: ((Int) async throws -> Conversation)?

    func listConversations(cursor: String?) async throws -> ConversationPage {
        listConversationsCalls.append(cursor)
        if let handler = listConversationsHandler {
            return try await handler(cursor)
        }
        throw TestError.unimplemented(#function)
    }

    func startConversation(with participantBackendId: Int) async throws -> Conversation {
        startConversationCalls.append(participantBackendId)
        if let handler = startConversationHandler {
            return try await handler(participantBackendId)
        }
        throw TestError.unimplemented(#function)
    }

    func updateConversationPreferences(conversationId: Int, muted: Bool) async throws -> Bool {
        try unimplemented(#function)
    }

    func updateChannelPreferences(channelBackendId: Int, muted: Bool) async throws -> Bool {
        try unimplemented(#function)
    }

    func getConversationMessages(conversationId: Int, cursor: String?) async throws -> MessagePage {
        try unimplemented(#function)
    }

    func sendConversationMessage(conversationId: Int, content: String, attachments: [SendMessageAttachmentDTO]?) async throws -> Message {
        try unimplemented(#function)
    }

    func searchMessages(query: String, limit: Int, cursor: String?) async throws -> MessageSearchPage {
        searchMessagesCalls.append((query, limit, cursor))
        if let handler = searchMessagesHandler {
            return try await handler(query, limit, cursor)
        }
        throw TestError.unimplemented(#function)
    }

    func getChannels(cursor: String?) async throws -> ChannelPage {
        getChannelsCalls.append(cursor)
        if let handler = getChannelsHandler {
            return try await handler(cursor)
        }
        throw TestError.unimplemented(#function)
    }

    func createChannel(name: String, memberUserIds: [Int]) async throws -> Channel {
        try unimplemented(#function)
    }

    func updateChannel(channelBackendId: Int, name: String) async throws {
        throw TestError.unimplemented(#function)
    }

    func updateChannelPhoto(channelBackendId: Int, photoMediaAssetId: Int?) async throws -> Channel {
        try unimplemented(#function)
    }

    func deleteChannel(channelBackendId: Int) async throws {
        throw TestError.unimplemented(#function)
    }

    func getChannelMembers(channelBackendId: Int, cursor: String?) async throws -> ChannelMembersPage {
        try unimplemented(#function)
    }

    func addChannelMembers(channelBackendId: Int, userIds: [Int]) async throws -> Int {
        try unimplemented(#function)
    }

    func removeChannelMember(channelBackendId: Int, userId: Int) async throws {
        throw TestError.unimplemented(#function)
    }

    func updateChannelMemberPermission(channelBackendId: Int, userId: Int, canManageMembers: Bool) async throws {
        throw TestError.unimplemented(#function)
    }

    func getChannelMessages(channelBackendId: Int, cursor: String?) async throws -> MessagePage {
        try unimplemented(#function)
    }

    func sendChannelMessage(channelBackendId: Int, content: String, attachments: [SendMessageAttachmentDTO]?) async throws -> Message {
        try unimplemented(#function)
    }

    func fetchMessageRequests(cursor: String?) async throws -> MessageRequestPage {
        fetchMessageRequestsCalls.append(cursor)
        if let handler = fetchMessageRequestsHandler {
            return try await handler(cursor)
        }
        throw TestError.unimplemented(#function)
    }

    func approveMessageRequest(requestId: Int) async throws {
        approveRequestCalls.append(requestId)
        if let handler = approveRequestHandler {
            try await handler(requestId)
            return
        }
        throw TestError.unimplemented(#function)
    }

    func rejectMessageRequest(requestId: Int) async throws {
        rejectRequestCalls.append(requestId)
        if let handler = rejectRequestHandler {
            try await handler(requestId)
            return
        }
        throw TestError.unimplemented(#function)
    }
}

final class MockBlockService: BlockServiceProtocol {
    var fetchBlockedUsersCalls: [(limit: Int, cursor: String?)] = []
    var fetchBlockedUsersHandler: ((Int, String?) async throws -> BlockedUsersPage)?

    var unblockPrincipalCalls: [(principalId: Int, asAnonymousActor: Bool, communityId: Int?)] = []
    var unblockPrincipalHandler: ((Int, Bool, Int?) async throws -> PrincipalBlockActionResult)?

    func fetchBlockedUsers(limit: Int, cursor: String?) async throws -> BlockedUsersPage {
        fetchBlockedUsersCalls.append((limit, cursor))
        if let handler = fetchBlockedUsersHandler {
            return try await handler(limit, cursor)
        }
        throw TestError.unimplemented(#function)
    }

    func blockUser(userId: Int) async throws -> BlockActionResult {
        try unimplemented(#function)
    }

    func unblockUser(userId: Int) async throws -> BlockActionResult {
        try unimplemented(#function)
    }

    func blockUser(userId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> BlockActionResult {
        try unimplemented(#function)
    }

    func unblockUser(userId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> BlockActionResult {
        try unimplemented(#function)
    }

    func blockPrincipal(principalId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> PrincipalBlockActionResult {
        try unimplemented(#function)
    }

    func unblockPrincipal(principalId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> PrincipalBlockActionResult {
        unblockPrincipalCalls.append((principalId, asAnonymousActor, communityId))
        if let handler = unblockPrincipalHandler {
            return try await handler(principalId, asAnonymousActor, communityId)
        }
        throw TestError.unimplemented(#function)
    }
}

final class MockNotificationService: NotificationServiceProtocol {
    var fetchPreferencesCallCount = 0
    var fetchPreferencesHandler: (() async throws -> NotificationPreferencesDTO)?

    var updateRequests: [NotificationPreferencesUpdateRequest] = []
    var updatePreferencesHandler: ((NotificationPreferencesUpdateRequest) async throws -> NotificationPreferencesDTO)?
    var dismissCalls: [Int] = []
    var dismissHandler: ((Int) async throws -> Void)?
    var dismissAllCallCount = 0
    var dismissAllHandler: (() async throws -> Int)?

    func fetchNotifications(limit: Int, cursor: String?) async throws -> NotificationPage {
        try unimplemented(#function)
    }

    func markRead(notificationId: Int) async throws {
        throw TestError.unimplemented(#function)
    }

    func dismiss(notificationId: Int) async throws {
        dismissCalls.append(notificationId)
        if let handler = dismissHandler {
            try await handler(notificationId)
            return
        }
        throw TestError.unimplemented(#function)
    }

    func dismissAll() async throws -> Int {
        dismissAllCallCount += 1
        if let handler = dismissAllHandler {
            return try await handler()
        }
        throw TestError.unimplemented(#function)
    }

    func fetchPreferences() async throws -> NotificationPreferencesDTO {
        fetchPreferencesCallCount += 1
        if let handler = fetchPreferencesHandler {
            return try await handler()
        }
        throw TestError.unimplemented(#function)
    }

    func updatePreferences(_ update: NotificationPreferencesUpdateRequest) async throws -> NotificationPreferencesDTO {
        updateRequests.append(update)
        if let handler = updatePreferencesHandler {
            return try await handler(update)
        }
        throw TestError.unimplemented(#function)
    }
}

final class MockAuthService: AuthServiceProtocol {
    private let authStateSubject = PassthroughSubject<Bool, Never>()

    var authStateChanged: AnyPublisher<Bool, Never> {
        authStateSubject.eraseToAnyPublisher()
    }

    var isAuthenticated: Bool = false

    var loginCalls: [(email: String, password: String)] = []
    var loginHandler: ((String, String) async throws -> Void)?

    var signUpCalls: [(email: String, password: String)] = []
    var signUpHandler: ((String, String) async throws -> Void)?

    var sendPasswordResetCalls: [String] = []
    var sendPasswordResetHandler: ((String) async throws -> Void)?

    var signOutCallCount = 0
    var refreshTokenCallCount = 0

    func emitAuthState(_ isAuthenticated: Bool) {
        self.isAuthenticated = isAuthenticated
        authStateSubject.send(isAuthenticated)
    }

    func login(email: String, password: String) async throws {
        loginCalls.append((email, password))
        if let handler = loginHandler {
            try await handler(email, password)
            return
        }
        throw TestError.unimplemented(#function)
    }

    func signUp(email: String, password: String) async throws {
        signUpCalls.append((email, password))
        if let handler = signUpHandler {
            try await handler(email, password)
            return
        }
        throw TestError.unimplemented(#function)
    }

    func sendPasswordReset(email: String) async throws {
        sendPasswordResetCalls.append(email)
        if let handler = sendPasswordResetHandler {
            try await handler(email)
            return
        }
        throw TestError.unimplemented(#function)
    }

    func signOut() {
        signOutCallCount += 1
        isAuthenticated = false
    }

    func refreshToken() async throws {
        refreshTokenCallCount += 1
    }

    func signInWithGoogle(presenting: UIViewController) async throws {
        throw TestError.unimplemented(#function)
    }

    func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws {
        throw TestError.unimplemented(#function)
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async throws {
        throw TestError.unimplemented(#function)
    }

    func linkWithGoogle(presenting: UIViewController) async throws {
        throw TestError.unimplemented(#function)
    }

    func linkWithApple(presentationAnchor: ASPresentationAnchor) async throws {
        throw TestError.unimplemented(#function)
    }

    func unlinkGoogle() async throws {
        throw TestError.unimplemented(#function)
    }

    func unlinkApple() async throws {
        throw TestError.unimplemented(#function)
    }

    #if canImport(FirebaseAuth)
    func sendMfaCode(resolver: MultiFactorResolver, hint: PhoneMultiFactorInfo) async throws -> String {
        throw TestError.unimplemented(#function)
    }

    func resolveMfaSignIn(resolver: MultiFactorResolver, verificationId: String, verificationCode: String) async throws {
        throw TestError.unimplemented(#function)
    }
    #endif
}

final class MockDeviceService: DeviceServiceProtocol {
    var registerCalls: [String] = []
    var registerHandler: ((String) async throws -> Void)?

    func registerDevice(apnsToken: String) async throws {
        registerCalls.append(apnsToken)
        if let handler = registerHandler {
            try await handler(apnsToken)
        }
    }
}

final class MockMediaService: MediaServiceProtocol {
    func uploadImage(data: Data, mimeType: String, width: Int, height: Int, actor: MediaUploadActor) async throws -> MediaAsset {
        throw TestError.unimplemented(#function)
    }

    func uploadVideo(
        fileURL: URL,
        mimeType: String,
        width: Int,
        height: Int,
        durationSeconds: Int,
        actor: MediaUploadActor,
        thumbnailMediaAssetId: Int?
    ) async throws -> MediaAsset {
        throw TestError.unimplemented(#function)
    }

    func resolvePublicMedia(ids: [Int]) async throws -> [MediaAsset] {
        throw TestError.unimplemented(#function)
    }
}

final class MockUserService: UserServiceProtocol {
    var getIdentityCallCount = 0
    var getIdentityHandler: (() async throws -> IdentityResponseDTO)?

    var getCurrentUserCallCount = 0
    var getCurrentUserHandler: (() async throws -> AppUser)?

    var getUserCalls: [Int] = []
    var getUserHandler: ((Int) async throws -> AppUser)?

    var followUserCalls: [(userId: Int, asAnonymousActor: Bool, communityId: Int?)] = []
    var followUserHandler: ((Int, Bool, Int?) async throws -> UserFollowActionResult)?

    var unfollowUserCalls: [(userId: Int, asAnonymousActor: Bool, communityId: Int?)] = []
    var unfollowUserHandler: ((Int, Bool, Int?) async throws -> UserFollowActionResult)?

    var followAnonCalls: [(anonProfileId: Int, asAnonymousActor: Bool, communityId: Int?)] = []
    var followAnonHandler: ((Int, Bool, Int?) async throws -> AnonProfileFollowActionResult)?

    var unfollowAnonCalls: [(anonProfileId: Int, asAnonymousActor: Bool, communityId: Int?)] = []
    var unfollowAnonHandler: ((Int, Bool, Int?) async throws -> AnonProfileFollowActionResult)?

    var fetchUserFollowingCalls: [(userId: Int, limit: Int, cursor: String?, query: String?)] = []
    var fetchUserFollowingHandler: ((Int, Int, String?, String?) async throws -> UserFollowListPage)?
    var searchUsersCalls: [(query: String, limit: Int, cursor: String?)] = []
    var searchUsersHandler: ((String, Int, String?) async throws -> UserSearchPage)?

    var updateOnboardingStepCalls: [RemoteOnboardingStep] = []
    var updateOnboardingStepHandler: ((RemoteOnboardingStep) async throws -> OnboardingStateDTO)?
    var dismissProfileCompletionPromptCallCount = 0
    var dismissProfileCompletionPromptHandler: (() async throws -> ProfileCompletionDTO?)?
    var markOnboardingInfoScreenViewedCallCount = 0
    var markOnboardingInfoScreenViewedHandler: (() async throws -> OnboardingStateV2DTO)?
    var setOnboardingV2OrganizationCalls: [Int] = []
    var setOnboardingV2OrganizationHandler: ((Int) async throws -> OnboardingStateV2DTO)?
    var setOnboardingV2VerificationChoiceCalls: [String] = []
    var setOnboardingV2VerificationChoiceHandler: ((String) async throws -> OnboardingStateV2DTO)?
    var markOnboardingV2EmailVerificationSuccessCallCount = 0
    var markOnboardingV2EmailVerificationSuccessHandler: (() async throws -> OnboardingStateV2DTO)?
    var submitOnboardingV2SpecializationCalls: [Int] = []
    var submitOnboardingV2SpecializationHandler: ((Int) async throws -> OnboardingStateV2DTO)?
    var acknowledgeOnboardingV2SkipExplainerCallCount = 0
    var acknowledgeOnboardingV2SkipExplainerHandler: (() async throws -> OnboardingStateV2DTO)?
    var acknowledgeOnboardingV2PhotoPendingExplainerCallCount = 0
    var acknowledgeOnboardingV2PhotoPendingExplainerHandler: (() async throws -> OnboardingStateV2DTO)?
    var finalizeOnboardingV2CallCount = 0
    var finalizeOnboardingV2Handler: (() async throws -> OnboardingStateV2DTO)?
    var completeOnboardingV2AfterCommunityRequestCallCount = 0
    var completeOnboardingV2AfterCommunityRequestHandler: (() async throws -> OnboardingStateV2DTO)?

    func getIdentity() async throws -> IdentityResponseDTO {
        getIdentityCallCount += 1
        if let handler = getIdentityHandler {
            return try await handler()
        }
        throw TestError.unimplemented(#function)
    }

    func getCurrentUser() async throws -> AppUser {
        getCurrentUserCallCount += 1
        if let handler = getCurrentUserHandler {
            return try await handler()
        }
        throw TestError.unimplemented(#function)
    }

    func getUser(by id: Int) async throws -> AppUser {
        getUserCalls.append(id)
        if let handler = getUserHandler {
            return try await handler(id)
        }
        throw TestError.unimplemented(#function)
    }

    func followUser(userId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> UserFollowActionResult {
        followUserCalls.append((userId, asAnonymousActor, communityId))
        if let handler = followUserHandler {
            return try await handler(userId, asAnonymousActor, communityId)
        }
        throw TestError.unimplemented(#function)
    }

    func unfollowUser(userId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> UserFollowActionResult {
        unfollowUserCalls.append((userId, asAnonymousActor, communityId))
        if let handler = unfollowUserHandler {
            return try await handler(userId, asAnonymousActor, communityId)
        }
        throw TestError.unimplemented(#function)
    }

    func followAnonProfile(anonProfileId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> AnonProfileFollowActionResult {
        followAnonCalls.append((anonProfileId, asAnonymousActor, communityId))
        if let handler = followAnonHandler {
            return try await handler(anonProfileId, asAnonymousActor, communityId)
        }
        throw TestError.unimplemented(#function)
    }

    func unfollowAnonProfile(anonProfileId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> AnonProfileFollowActionResult {
        unfollowAnonCalls.append((anonProfileId, asAnonymousActor, communityId))
        if let handler = unfollowAnonHandler {
            return try await handler(anonProfileId, asAnonymousActor, communityId)
        }
        throw TestError.unimplemented(#function)
    }

    func fetchMyShareLink() async throws -> UserShareLink { throw TestError.unimplemented(#function) }
    func checkSlugAvailability(_ slug: String) async throws -> UserSlugAvailability { throw TestError.unimplemented(#function) }
    func resolveUserId(fromSlug slug: String) async throws -> Int { throw TestError.unimplemented(#function) }
    func updateMyShareLink(customSlug: String?) async throws -> UserShareLink { throw TestError.unimplemented(#function) }
    func fetchUserFollowers(userId: Int, limit: Int, cursor: String?, query: String?) async throws -> UserFollowListPage { throw TestError.unimplemented(#function) }

    func fetchUserFollowing(userId: Int, limit: Int, cursor: String?, query: String?) async throws -> UserFollowListPage {
        fetchUserFollowingCalls.append((userId, limit, cursor, query))
        if let handler = fetchUserFollowingHandler {
            return try await handler(userId, limit, cursor, query)
        }
        throw TestError.unimplemented(#function)
    }

    func updateProfile(
        displayName: String?,
        bio: String?,
        isAnonymous: Bool,
        showFollowerCount: Bool?,
        messagePermission: MessagePermission?,
        profileMediaAssetId: Int?
    ) async throws -> AppUser { throw TestError.unimplemented(#function) }

    func updateIdentity(username: String, firstName: String, lastName: String, dateOfBirth: String) async throws -> AppUser {
        throw TestError.unimplemented(#function)
    }

    func updateDisplayCommunity(communityId: Int?) async throws -> AppUser { throw TestError.unimplemented(#function) }
    func updateDisplaySpecialization(specializationId: Int?) async throws -> AppUser { throw TestError.unimplemented(#function) }
    func verifyEmployment(verification: EmploymentVerification) async throws { throw TestError.unimplemented(#function) }
    func deleteAccount(mode: DeleteAccountMode) async throws -> DeleteAccountResult { throw TestError.unimplemented(#function) }
    func searchUsers(query: String, limit: Int, cursor: String?) async throws -> UserSearchPage {
        searchUsersCalls.append((query, limit, cursor))
        if let handler = searchUsersHandler {
            return try await handler(query, limit, cursor)
        }
        throw TestError.unimplemented(#function)
    }
    func fetchUserComments(userId: Int, limit: Int, cursor: String?) async throws -> UserCommentsPage { throw TestError.unimplemented(#function) }
    func fetchUserReplies(userId: Int, limit: Int, cursor: String?) async throws -> UserRepliesPage { throw TestError.unimplemented(#function) }
    func checkUsernameAvailability(_ username: String) async throws -> UsernameAvailabilityResponseDTO { throw TestError.unimplemented(#function) }
    func onboardUser(username: String, firstName: String, lastName: String, dateOfBirth: String) async throws -> AppUser { throw TestError.unimplemented(#function) }

    func updateOnboardingStep(_ step: RemoteOnboardingStep) async throws -> OnboardingStateDTO {
        updateOnboardingStepCalls.append(step)
        if let handler = updateOnboardingStepHandler {
            return try await handler(step)
        }
        throw TestError.unimplemented(#function)
    }

    func dismissProfileCompletionPrompt() async throws -> ProfileCompletionDTO? {
        dismissProfileCompletionPromptCallCount += 1
        if let handler = dismissProfileCompletionPromptHandler {
            return try await handler()
        }
        throw TestError.unimplemented(#function)
    }

    func markOnboardingInfoScreenViewed() async throws -> OnboardingStateV2DTO {
        markOnboardingInfoScreenViewedCallCount += 1
        if let handler = markOnboardingInfoScreenViewedHandler {
            return try await handler()
        }
        throw TestError.unimplemented(#function)
    }

    func setOnboardingV2Organization(orgId: Int) async throws -> OnboardingStateV2DTO {
        setOnboardingV2OrganizationCalls.append(orgId)
        if let handler = setOnboardingV2OrganizationHandler {
            return try await handler(orgId)
        }
        throw TestError.unimplemented(#function)
    }

    func setOnboardingV2VerificationChoice(path: String) async throws -> OnboardingStateV2DTO {
        setOnboardingV2VerificationChoiceCalls.append(path)
        if let handler = setOnboardingV2VerificationChoiceHandler {
            return try await handler(path)
        }
        throw TestError.unimplemented(#function)
    }

    func markOnboardingV2EmailVerificationSuccess() async throws -> OnboardingStateV2DTO {
        markOnboardingV2EmailVerificationSuccessCallCount += 1
        if let handler = markOnboardingV2EmailVerificationSuccessHandler {
            return try await handler()
        }
        throw TestError.unimplemented(#function)
    }

    func submitOnboardingV2Specialization(specializationId: Int) async throws -> OnboardingStateV2DTO {
        submitOnboardingV2SpecializationCalls.append(specializationId)
        if let handler = submitOnboardingV2SpecializationHandler {
            return try await handler(specializationId)
        }
        throw TestError.unimplemented(#function)
    }

    func acknowledgeOnboardingV2SkipExplainer() async throws -> OnboardingStateV2DTO {
        acknowledgeOnboardingV2SkipExplainerCallCount += 1
        if let handler = acknowledgeOnboardingV2SkipExplainerHandler {
            return try await handler()
        }
        throw TestError.unimplemented(#function)
    }

    func acknowledgeOnboardingV2PhotoPendingExplainer() async throws -> OnboardingStateV2DTO {
        acknowledgeOnboardingV2PhotoPendingExplainerCallCount += 1
        if let handler = acknowledgeOnboardingV2PhotoPendingExplainerHandler {
            return try await handler()
        }
        throw TestError.unimplemented(#function)
    }

    func finalizeOnboardingV2() async throws -> OnboardingStateV2DTO {
        finalizeOnboardingV2CallCount += 1
        if let handler = finalizeOnboardingV2Handler {
            return try await handler()
        }
        throw TestError.unimplemented(#function)
    }

    func completeOnboardingV2AfterCommunityRequest() async throws -> OnboardingStateV2DTO {
        completeOnboardingV2AfterCommunityRequestCallCount += 1
        if let handler = completeOnboardingV2AfterCommunityRequestHandler {
            return try await handler()
        }
        throw TestError.unimplemented(#function)
    }
}
