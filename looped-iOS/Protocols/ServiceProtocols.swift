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
    func fetchTrendingPosts(limit: Int, communityId: Int?) async throws -> [TrendingPost]
    func searchPosts(query: String, limit: Int, cursor: String?) async throws -> FeedPage
    func createPost(content: String, isAnonymous: Bool, communityId: Int, mediaAssetId: Int?, poll: PollDraft?) async throws -> Post
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
    func fetchUserReposts(userId: Int, limit: Int, cursor: String?) async throws -> FeedPage
    func fetchUserContent(userId: Int, limit: Int, cursor: String?) async throws -> UserContentPage
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
    let repostCount: Int
    let viewerHasReposted: Bool
}

struct PostDeleteResponse {
    let postId: Int
    let deleted: Bool
}

protocol PollsServiceProtocol {
    func vote(pollId: Int, selectedOptionIds: [Int]) async throws -> Poll
}

protocol MessageServiceProtocol {
    func listConversations(cursor: String?) async throws -> ConversationPage
    func startConversation(with participantBackendId: Int) async throws -> Conversation
    func getConversationMessages(conversationId: Int, cursor: String?) async throws -> MessagePage
    func sendConversationMessage(conversationId: Int, content: String) async throws -> Message
    func searchMessages(query: String, limit: Int, cursor: String?) async throws -> MessageSearchPage
    func getChannels(cursor: String?) async throws -> ChannelPage
    func createChannel(name: String, memberUserIds: [Int]) async throws -> Channel
    func getChannelMembers(channelBackendId: Int, cursor: String?) async throws -> ChannelMembersPage
    func addChannelMembers(channelBackendId: Int, userIds: [Int]) async throws -> Int
    func removeChannelMember(channelBackendId: Int, userId: Int) async throws
    func updateChannelMemberPermission(channelBackendId: Int, userId: Int, canManageMembers: Bool) async throws
    func getChannelMessages(channelBackendId: Int, cursor: String?) async throws -> MessagePage
    func sendChannelMessage(channelBackendId: Int, content: String) async throws -> Message
    func fetchMessageRequests(cursor: String?) async throws -> MessageRequestPage
    func approveMessageRequest(requestId: Int) async throws
    func rejectMessageRequest(requestId: Int) async throws
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
    func deleteAccount(mode: DeleteAccountMode) async throws
    func searchUsers(query: String, limit: Int, cursor: String?) async throws -> UserSearchPage
    func fetchUserComments(userId: Int, limit: Int, cursor: String?) async throws -> UserCommentsPage
    func fetchUserReplies(userId: Int, limit: Int, cursor: String?) async throws -> UserRepliesPage
    func checkUsernameAvailability(_ username: String) async throws -> UsernameAvailabilityResponseDTO
    func onboardUser(username: String, firstName: String, lastName: String, dateOfBirth: String) async throws -> User
}

extension UserServiceProtocol {
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

protocol CommentsServiceProtocol {
    func fetchComments(postId: Int, communityId: Int?, limit: Int, cursor: String?) async throws -> CommentPage
    func fetchReplies(commentId: Int, communityId: Int?, limit: Int, cursor: String?) async throws -> CommentPage
    func createComment(postId: Int, communityId: Int?, content: String, parentId: Int?) async throws -> Comment
    func editComment(commentId: Int, communityId: Int?, content: String, asAnon: Bool) async throws -> Comment
    func deleteComment(commentId: Int, communityId: Int?, asAnon: Bool) async throws -> CommentDeleteResponse
    func likeComment(commentId: Int, communityId: Int?) async throws -> CommentLikeResponse
    func unlikeComment(commentId: Int, communityId: Int?) async throws -> CommentLikeResponse
}

protocol CommunityServiceProtocol {
    func fetchFollowedCommunities(limit: Int, cursor: String?, order: CommunityFollowOrder) async throws -> CommunityPage
    func fetchRecommendedCommunities(kind: CommunitySearchKind?, limit: Int) async throws -> [CommunitySearchResult]
    func fetchCommunityDetails(communityId: Int) async throws -> CommunityProfileData
    func fetchCommunityDomains(communityId: Int) async throws -> [String]
    func searchCommunities(query: String, limit: Int, cursor: String?, kind: CommunitySearchKind?) async throws -> SearchResultPage<CommunitySearchResult>
    func fetchTopProfessionCommunities(limit: Int) async throws -> [CommunitySearchResult]
    func followCommunity(id: Int) async throws
    func unfollowCommunity(id: Int) async throws
    func fetchCommunityPermissions(communityId: Int) async throws -> CommunityPermissions
}

protocol CommunityVerificationServiceProtocol {
    func fetchCommunityVerifications() async throws -> [CommunityVerification]
    func startVerification(communityId: Int, method: CommunityVerificationMethod, email: String?) async throws -> CommunityVerificationStartResponse
    func finishVerification(communityId: Int, request: CommunityVerificationFinishRequest) async throws -> CommunityVerificationFinishResponse
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
}

protocol NotificationServiceProtocol {
    func fetchNotifications(limit: Int, cursor: String?) async throws -> NotificationPage
    func markRead(notificationId: Int) async throws
    func fetchPreferences() async throws -> NotificationPreferencesDTO
    func updatePreferences(_ update: NotificationPreferencesUpdateRequest) async throws -> NotificationPreferencesDTO
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
}

protocol CommunityRequestServiceProtocol {
    func createCommunityRequest(kind: CommunityRequestKind, name: String, about: String, imageKey: String?) async throws -> CommunityRequestSubmission
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
