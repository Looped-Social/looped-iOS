import Foundation
import Combine
import UIKit
import AuthenticationServices
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

protocol AuthServiceProtocol {
    var authStateChanged: AnyPublisher<Bool, Never> { get }
    
    func login(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws
    func sendPasswordReset(email: String) async throws
    func signOut()
    func refreshToken() async throws
    var isAuthenticated: Bool { get }

    // Social sign-in
    func signInWithGoogle(presenting: UIViewController) async throws
    func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async throws

    // Link providers
    func linkWithGoogle(presenting: UIViewController) async throws
    func linkWithApple(presentationAnchor: ASPresentationAnchor) async throws
    func unlinkGoogle() async throws
    func unlinkApple() async throws

    #if canImport(FirebaseAuth)
    func sendMfaCode(resolver: MultiFactorResolver, hint: PhoneMultiFactorInfo) async throws -> String
    func resolveMfaSignIn(resolver: MultiFactorResolver, verificationId: String, verificationCode: String) async throws
    #endif
}

protocol FeedServiceProtocol {
    func fetchFeed(limit: Int, cursor: String?, communityId: Int?, mode: FeedMode) async throws -> FeedPage
    func fetchCommunityHashtagPosts(communityId: Int, limit: Int, cursor: String?) async throws -> FeedPage
    func fetchTrendingPosts(limit: Int, communityId: Int?) async throws -> [TrendingPost]
    func searchPosts(query: String, limit: Int, cursor: String?) async throws -> FeedPage
    func createPost(content: String, isAnonymous: Bool, communityId: Int, mediaAssetId: Int?, mediaAssetIds: [Int]?, poll: PollDraft?) async throws -> Post
    func updatePost(postId: Int, content: String, isAnonymous: Bool, communityId: Int?) async throws -> Post
    func reactToPost(postId: Int, communityId: Int?, reaction: ReactionType) async throws -> PostReactionResponse
    func unlikePost(postId: Int, communityId: Int?) async throws -> PostReactionResponse
    func sharePost(postId: Int) async throws -> PostShareResponse
    func repostPost(postId: Int) async throws -> PostRepostResponse
    func unrepostPost(postId: Int) async throws -> PostRepostResponse
    func fetchUserPosts(userId: Int, limit: Int, cursor: String?) async throws -> FeedPage
    func fetchHashtagPosts(hashtag: String, limit: Int, cursor: String?) async throws -> FeedPage
    func fetchPost(postId: Int) async throws -> Post
    func fetchLikedPosts(limit: Int, cursor: String?) async throws -> FeedPage
    func fetchSavedPosts(limit: Int, cursor: String?) async throws -> FeedPage
    func fetchRepostedPosts(limit: Int, cursor: String?) async throws -> FeedPage
    func fetchReposters(postId: Int, limit: Int, cursor: String?) async throws -> RepostersPage
    func fetchUserReposts(userId: Int, limit: Int, cursor: String?) async throws -> FeedPage
    func fetchMyReposts(limit: Int, cursor: String?) async throws -> FeedPage
    func fetchAnonReposts(anonProfileId: Int, limit: Int, cursor: String?) async throws -> FeedPage
    func fetchMyContent(limit: Int, cursor: String?, includePostPreview: Bool) async throws -> UserContentPage
    func fetchUserContent(userId: Int, limit: Int, cursor: String?, includePostPreview: Bool) async throws -> UserContentPage
    func fetchAnonContent(anonProfileId: Int, limit: Int, cursor: String?, includePostPreview: Bool) async throws -> UserContentPage
    func fetchAnonPosts(anonProfileId: Int, limit: Int, cursor: String?) async throws -> FeedPage
    func savePost(postId: Int, communityId: Int?) async throws -> Bool
    func removeSavedPost(postId: Int, communityId: Int?) async throws -> Bool
    func deletePost(postId: Int, communityId: Int?, asAnon: Bool) async throws -> PostDeleteResponse
}

struct PostReactionResponse {
    let postId: Int
    let likesCount: Int
}

struct PostShareResponse {
    let postId: Int
    let shareCount: Int
}

struct PostRepostResponse {
    let postId: Int
    let viewerHasReposted: Bool
}

struct PostDeleteResponse {
    let postId: Int
    let deleted: Bool
}

struct RepostersPage {
    let items: [RepostBannerUser]
    let nextCursor: String?
}

protocol PollsServiceProtocol {
    func vote(pollId: Int, selectedOptionIds: [Int], communityId: Int?) async throws -> Poll
}

protocol MessageServiceProtocol {
    func listConversations(cursor: String?) async throws -> ConversationPage
    func startConversation(with participantBackendId: Int) async throws -> Conversation
    func updateConversationPreferences(conversationId: Int, muted: Bool) async throws -> Bool
    func updateChannelPreferences(channelBackendId: Int, muted: Bool) async throws -> Bool
    func getConversationMessages(conversationId: Int, cursor: String?) async throws -> MessagePage
    func sendConversationMessage(conversationId: Int, content: String, attachments: [SendMessageAttachmentDTO]?) async throws -> Message
    func searchMessages(query: String, limit: Int, cursor: String?) async throws -> MessageSearchPage
    func getChannels(cursor: String?) async throws -> ChannelPage
    func createChannel(name: String, memberUserIds: [Int]) async throws -> Channel
    func updateChannel(channelBackendId: Int, name: String) async throws
    func updateChannelPhoto(channelBackendId: Int, photoMediaAssetId: Int?) async throws -> Channel
    func deleteChannel(channelBackendId: Int) async throws
    func getChannelMembers(channelBackendId: Int, cursor: String?) async throws -> ChannelMembersPage
    func addChannelMembers(channelBackendId: Int, userIds: [Int]) async throws -> Int
    func removeChannelMember(channelBackendId: Int, userId: Int) async throws
    func updateChannelMemberPermission(channelBackendId: Int, userId: Int, canManageMembers: Bool) async throws
    func getChannelMessages(channelBackendId: Int, cursor: String?) async throws -> MessagePage
    func sendChannelMessage(channelBackendId: Int, content: String, attachments: [SendMessageAttachmentDTO]?) async throws -> Message
    func fetchMessageRequests(cursor: String?) async throws -> MessageRequestPage
    func approveMessageRequest(requestId: Int) async throws
    func rejectMessageRequest(requestId: Int) async throws
}

extension MessageServiceProtocol {
    func sendConversationMessage(conversationId: Int, content: String) async throws -> Message {
        try await sendConversationMessage(conversationId: conversationId, content: content, attachments: nil)
    }

    func sendChannelMessage(channelBackendId: Int, content: String) async throws -> Message {
        try await sendChannelMessage(channelBackendId: channelBackendId, content: content, attachments: nil)
    }
}

struct MessageSearchPage {
    let items: [MessageSearchHit]
    let nextCursor: String?
}

struct MessageSearchHit: Identifiable {
    let id: String
    let type: MessageSearchHitType
    let conversation: Conversation?
    let channel: Channel?
    let matchedMessage: Message?

    let previewText: String
    let previewTimestamp: Date?
}

enum MessageSearchHitType: String {
    case conversation
    case channel
}

protocol UserServiceProtocol {
    func getIdentity() async throws -> IdentityResponseDTO
    func getCurrentUser() async throws -> User
    func getUser(by id: Int) async throws -> User
    func followUser(userId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> UserFollowActionResult
    func unfollowUser(userId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> UserFollowActionResult
    func followAnonProfile(anonProfileId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> AnonProfileFollowActionResult
    func unfollowAnonProfile(anonProfileId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> AnonProfileFollowActionResult
    func fetchMyShareLink() async throws -> UserShareLink
    func checkSlugAvailability(_ slug: String) async throws -> UserSlugAvailability
    func resolveUserId(fromSlug slug: String) async throws -> Int
    func updateMyShareLink(customSlug: String?) async throws -> UserShareLink
    func fetchUserFollowers(userId: Int, limit: Int, cursor: String?, query: String?) async throws -> UserFollowListPage
    func fetchUserFollowing(userId: Int, limit: Int, cursor: String?, query: String?) async throws -> UserFollowListPage
    func updateProfile(
        displayName: String?,
        bio: String?,
        isAnonymous: Bool,
        showFollowerCount: Bool?,
        messagePermission: MessagePermission?,
        profileMediaAssetId: Int?
    ) async throws -> User
    func updateIdentity(username: String, firstName: String, lastName: String, dateOfBirth: String) async throws -> User
    func updateDisplayCommunity(communityId: Int?) async throws -> User
    func updateDisplaySpecialization(specializationId: Int?) async throws -> User
    func verifyEmployment(verification: EmploymentVerification) async throws
    func deleteAccount(mode: DeleteAccountMode) async throws -> DeleteAccountResult
    func searchUsers(query: String, limit: Int, cursor: String?) async throws -> UserSearchPage
    func fetchUserComments(userId: Int, limit: Int, cursor: String?) async throws -> UserCommentsPage
    func fetchUserReplies(userId: Int, limit: Int, cursor: String?) async throws -> UserRepliesPage
    func checkUsernameAvailability(_ username: String) async throws -> UsernameAvailabilityResponseDTO
    func onboardUser(username: String, firstName: String, lastName: String, dateOfBirth: String) async throws -> User
    func updateOnboardingStep(_ step: RemoteOnboardingStep) async throws -> OnboardingStateDTO
    func markOnboardingInfoScreenViewed() async throws -> OnboardingStateV2DTO
    func setOnboardingV2Organization(orgId: Int) async throws -> OnboardingStateV2DTO
    func setOnboardingV2VerificationChoice(path: String) async throws -> OnboardingStateV2DTO
    func markOnboardingV2EmailVerificationSuccess() async throws -> OnboardingStateV2DTO
    func submitOnboardingV2Specialization(specializationId: Int) async throws -> OnboardingStateV2DTO
    func acknowledgeOnboardingV2SkipExplainer() async throws -> OnboardingStateV2DTO
    func acknowledgeOnboardingV2PhotoPendingExplainer() async throws -> OnboardingStateV2DTO
    func finalizeOnboardingV2() async throws -> OnboardingStateV2DTO
    func completeOnboardingV2AfterCommunityRequest() async throws -> OnboardingStateV2DTO
}

struct UserFollowActionResult {
    let userId: Int
    let following: Bool
}

struct AnonProfileFollowActionResult {
    let anonProfileId: Int
    let following: Bool
}

struct UserShareLink {
    let usernameSlug: String
    let customSlug: String?
    let activeSlug: String
    let canonicalUrl: String
}

struct UserSlugAvailability {
    let slug: String
    let available: Bool
    let ownedByMe: Bool
    let reserved: Bool
}

extension UserServiceProtocol {
    func resolveUserId(fromSlug slug: String) async throws -> Int {
        let page = try await searchUsers(query: slug, limit: 25, cursor: nil)
        let normalized = slug.lowercased()
        if let match = page.users.first(where: { user in
            user.username?.lowercased() == normalized || user.handle.lowercased() == normalized
        }) {
            return match.backendId
        }
        throw UserServiceError.userSlugNotFound(slug)
    }

    func updateProfile(
        displayName: String?,
        bio: String?,
        isAnonymous: Bool,
        showFollowerCount: Bool?,
        messagePermission: MessagePermission?
    ) async throws -> User {
        try await updateProfile(
            displayName: displayName,
            bio: bio,
            isAnonymous: isAnonymous,
            showFollowerCount: showFollowerCount,
            messagePermission: messagePermission,
            profileMediaAssetId: nil
        )
    }

    func followUser(userId: Int, asAnonymousActor: Bool) async throws -> UserFollowActionResult {
        try await followUser(userId: userId, asAnonymousActor: asAnonymousActor, communityId: nil)
    }

    func unfollowUser(userId: Int, asAnonymousActor: Bool) async throws -> UserFollowActionResult {
        try await unfollowUser(userId: userId, asAnonymousActor: asAnonymousActor, communityId: nil)
    }
}

protocol BlockServiceProtocol {
    func fetchBlockedUsers(limit: Int, cursor: String?) async throws -> BlockedUsersPage
    func blockUser(userId: Int) async throws -> BlockActionResult
    func unblockUser(userId: Int) async throws -> BlockActionResult
    func blockUser(userId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> BlockActionResult
    func unblockUser(userId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> BlockActionResult
    func blockPrincipal(principalId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> PrincipalBlockActionResult
    func unblockPrincipal(principalId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> PrincipalBlockActionResult
}

struct BlockActionResult {
    let userId: Int
    let blocked: Bool
}

struct PrincipalBlockActionResult {
    let principalId: Int
    let blocked: Bool
}

enum DeleteAccountMode: String {
    case hard
    case soft
}

struct DeleteAccountResult {
    let deletePending: Bool
}

protocol CommentsServiceProtocol {
    func fetchComments(postId: Int, communityId: Int?, limit: Int, cursor: String?) async throws -> CommentPage
    func fetchReplies(commentId: Int, communityId: Int?, limit: Int, cursor: String?) async throws -> CommentPage
    func createComment(postId: Int, communityId: Int?, content: String, parentId: Int?, mediaAssetId: Int?) async throws -> Comment
    func editComment(commentId: Int, communityId: Int?, content: String, asAnon: Bool) async throws -> Comment
    func deleteComment(commentId: Int, communityId: Int?, asAnon: Bool) async throws -> CommentDeleteResponse
    func likeComment(commentId: Int, communityId: Int?) async throws -> CommentLikeResponse
    func unlikeComment(commentId: Int, communityId: Int?) async throws -> CommentLikeResponse
}

extension CommentsServiceProtocol {
    func createComment(postId: Int, communityId: Int?, content: String, parentId: Int?) async throws -> Comment {
        try await createComment(postId: postId, communityId: communityId, content: content, parentId: parentId, mediaAssetId: nil)
    }
}

protocol CommunityServiceProtocol {
    func fetchFollowedCommunities(limit: Int, cursor: String?, order: CommunityFollowOrder) async throws -> CommunityPage
    func fetchRecommendedCommunities(kind: CommunitySearchKind?, limit: Int, cursor: String?) async throws -> SearchResultPage<CommunitySearchResult>
    func fetchCommunityDetails(communityId: Int) async throws -> CommunityProfileData
    func fetchCommunityDetailsDTO(communityId: Int, kind: CommunityKind) async throws -> CommunityDetailsDTO
    func fetchCommunityDomains(communityId: Int) async throws -> [String]
    func fetchPostableCommunities() async throws -> [CommunitySummary]
    func fetchJoinedSpecializations(type: CommunitySpecializationType?) async throws -> [DisplayCommunity]
    func fetchSpecializationJoinLimits(type: CommunitySpecializationType?) async throws -> [SpecializationJoinLimit]
    func searchCommunities(query: String, limit: Int, cursor: String?, kind: CommunitySearchKind?) async throws -> SearchResultPage<CommunitySearchResult>
    func followCommunity(id: Int) async throws
    func unfollowCommunity(id: Int) async throws
    func followSpecialization(id: Int) async throws
    func unfollowSpecialization(id: Int) async throws
    func joinSpecialization(id: Int) async throws
    func unjoinSpecialization(id: Int) async throws
    func fetchCommunityPermissions(communityId: Int) async throws -> CommunityPermissions
}

extension CommunityServiceProtocol {
    func fetchRecommendedCommunities(kind: CommunitySearchKind?, limit: Int) async throws -> [CommunitySearchResult] {
        let page = try await fetchRecommendedCommunities(kind: kind, limit: limit, cursor: nil)
        return page.items
    }
}

protocol CommunityVerificationServiceProtocol {
    func fetchCommunityVerifications() async throws -> [CommunityVerification]
    func startVerification(communityId: Int, method: CommunityVerificationMethod, email: String?) async throws -> CommunityVerificationStartResponse
    func finishVerification(communityId: Int, request: CommunityVerificationFinishRequest) async throws -> CommunityVerificationFinishResponse
    func unverifyCommunity(communityId: Int) async throws -> CommunityVerificationUnverifyResponse
}

protocol PhotoIdVerificationServiceProtocol {
    func start() async throws -> PhotoIdVerificationStartResponse
    func presign(uploadSessionId: String, kind: PhotoIdDocumentKind, contentType: String, sizeBytes: Int) async throws -> PhotoIdVerificationPresignResponse
    func uploadDocument(uploadSessionId: String, kind: PhotoIdDocumentKind, data: Data, contentType: String) async throws -> String
    func submit(uploadSessionId: String, selfieKey: String, idFrontKey: String, idBackKey: String?) async throws -> PhotoIdVerificationSubmitResponse
    func status() async throws -> PhotoIdVerificationStatusResponse
}

protocol DiscoveryServiceProtocol {
    func searchLoops(query: String, limit: Int, cursor: String?) async throws -> SearchResultPage<LoopDTO>
    func searchHashtags(query: String, limit: Int, cursor: String?) async throws -> SearchResultPage<HashtagDTO>
    func fetchRecommendedSpecializations(limit: Int) async throws -> RecommendedSpecializations
    func browseSpecializations(type: CommunitySpecializationType, limit: Int, cursor: String?) async throws -> SearchResultPage<CommunitySearchResult>
    func fetchMajorsIndex() async throws -> [SpecializationIndexItem]
    func fetchFieldsIndex() async throws -> [SpecializationIndexItem]
}

protocol NotificationServiceProtocol {
    func fetchNotifications(limit: Int, cursor: String?) async throws -> NotificationPage
    func markRead(notificationId: Int) async throws
    func dismiss(notificationId: Int) async throws
    func dismissAll() async throws -> Int
    func fetchPreferences() async throws -> NotificationPreferencesDTO
    func updatePreferences(_ update: NotificationPreferencesUpdateRequest) async throws -> NotificationPreferencesDTO
}

extension NotificationServiceProtocol {
    func fetchNotifications(limit: Int, cursor: String?, includeDismissed: Bool) async throws -> NotificationPage {
        _ = includeDismissed
        return try await fetchNotifications(limit: limit, cursor: cursor)
    }
}

protocol ContentPreferencesServiceProtocol {
    func getPreferences() async throws -> ContentPreferencesResponseDTO
    func updateHideAnonymousPosts(_ hideAnonymousPosts: Bool) async throws -> ContentPreferencesResponseDTO
}

protocol ModerationServiceProtocol {
    func createReport(targetType: String, targetId: Int, reason: String) async throws -> Int?
    func createAppeal(targetType: String, targetId: Int?, reason: String) async throws -> Int?
    func fetchViolations(limit: Int, cursor: String?) async throws -> ViolationsPage
    func fetchAppeals(status: String?) async throws -> [Appeal]
}

protocol MediaServiceProtocol {
    func uploadImage(data: Data, mimeType: String, width: Int, height: Int) async throws -> MediaAsset
    func uploadImage(data: Data, mimeType: String, width: Int, height: Int, actor: MediaUploadActor) async throws -> MediaAsset
    func uploadVideo(
        fileURL: URL,
        mimeType: String,
        width: Int,
        height: Int,
        durationSeconds: Int,
        actor: MediaUploadActor,
        thumbnailMediaAssetId: Int?
    ) async throws -> MediaAsset
    func resolvePublicMedia(ids: [Int]) async throws -> [MediaAsset]
}

enum MediaUploadActor: Equatable {
    case user
    case anon
}

extension MediaServiceProtocol {
    func uploadImage(data: Data, mimeType: String, width: Int, height: Int) async throws -> MediaAsset {
        try await uploadImage(data: data, mimeType: mimeType, width: width, height: height, actor: .user)
    }

    func uploadVideo(
        fileURL: URL,
        mimeType: String,
        width: Int,
        height: Int,
        durationSeconds: Int,
        actor: MediaUploadActor
    ) async throws -> MediaAsset {
        try await uploadVideo(
            fileURL: fileURL,
            mimeType: mimeType,
            width: width,
            height: height,
            durationSeconds: durationSeconds,
            actor: actor,
            thumbnailMediaAssetId: nil
        )
    }
}

protocol MessageMediaServiceProtocol {
    func uploadImage(data: Data, mimeType: String) async throws -> String
    func uploadVideo(fileURL: URL, mimeType: String) async throws -> String
    func resolve(keys: [String]) async throws -> [MessageMediaResolvedItem]
}

struct MessageMediaResolvedItem: Equatable {
    let key: String
    let downloadUrl: String
    let mimeType: String?
    let expiresAt: Date
}

protocol CommunityRequestServiceProtocol {
    func createCommunityRequest(
        kind: CommunityRequestKind,
        name: String,
        about: String,
        imageKey: String?,
        contactEmail: String?,
        notifyWhenAvailable: Bool
    ) async throws -> CommunityRequestSubmission
    func fetchCommunityRequests(status: CommunityRequestStatus?) async throws -> [CommunityRequest]
}

protocol DeviceServiceProtocol {
    func registerDevice(apnsToken: String) async throws
}

protocol WebSocketServiceProtocol {
    var messageReceived: AnyPublisher<Message, Never> { get }
    var connectionState: AnyPublisher<WebSocketConnectionState, Never> { get }
    
    func connect() async
    func disconnect()
    func joinChannel(_ channelId: UUID)
    func leaveChannel(_ channelId: UUID)
}

enum WebSocketConnectionState {
    case disconnected
    case connecting
    case connected
    case error(Error)
}
