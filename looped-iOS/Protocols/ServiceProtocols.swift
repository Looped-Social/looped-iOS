import Foundation
import Combine
import UIKit
import AuthenticationServices

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
}

protocol FeedServiceProtocol {
    func fetchFeed(limit: Int, cursor: String?, communityId: Int?) async throws -> FeedPage
    func fetchTrendingPosts(limit: Int, communityId: Int?) async throws -> [TrendingPost]
    func createPost(content: String, isAnonymous: Bool, communityId: Int) async throws -> Post
    func reactToPost(postId: Int, reaction: ReactionType) async throws -> PostReactionResponse
    func fetchUserPosts(userId: Int, limit: Int, cursor: String?) async throws -> FeedPage
    func fetchHashtagPosts(hashtag: String, limit: Int, cursor: String?) async throws -> FeedPage
    func fetchLikedPosts(limit: Int, cursor: String?) async throws -> FeedPage
    func fetchSavedPosts(limit: Int, cursor: String?) async throws -> FeedPage
    func savePost(postId: Int) async throws -> Bool
    func removeSavedPost(postId: Int) async throws -> Bool
}

struct PostReactionResponse {
    let postId: Int
    let likesCount: Int
}

protocol MessageServiceProtocol {
    func listConversations(cursor: String?) async throws -> ConversationPage
    func startConversation(with participantBackendId: Int) async throws -> Conversation
    func getConversationMessages(conversationId: Int, cursor: String?) async throws -> MessagePage
    func sendConversationMessage(conversationId: Int, content: String) async throws -> Message
    func getChannels(cursor: String?) async throws -> ChannelPage
    func getChannelMessages(channelBackendId: Int, cursor: String?) async throws -> MessagePage
    func sendChannelMessage(channelBackendId: Int, content: String) async throws -> Message
    func fetchMessageRequests(cursor: String?) async throws -> MessageRequestPage
    func approveMessageRequest(requestId: Int) async throws
    func rejectMessageRequest(requestId: Int) async throws
}

protocol UserServiceProtocol {
    func getIdentity() async throws -> IdentityResponseDTO
    func getCurrentUser() async throws -> User
    func getUser(by id: Int) async throws -> User
    func updateProfile(displayName: String?, bio: String?, isAnonymous: Bool, showFollowerCount: Bool?) async throws -> User
    func updateIdentity(username: String, firstName: String, lastName: String, dateOfBirth: String) async throws -> User
    func verifyEmployment(verification: EmploymentVerification) async throws
    func deleteAccount(mode: DeleteAccountMode) async throws
    func searchUsers(query: String, limit: Int, cursor: String?) async throws -> UserSearchPage
    func fetchUserComments(userId: Int, limit: Int, cursor: String?) async throws -> UserCommentsPage
    func checkUsernameAvailability(_ username: String) async throws -> UsernameAvailabilityResponseDTO
    func onboardUser(username: String, firstName: String, lastName: String, dateOfBirth: String) async throws -> User
}

enum DeleteAccountMode: String {
    case hard
    case soft
}

protocol CommentsServiceProtocol {
    func fetchComments(postId: Int, limit: Int, cursor: String?) async throws -> CommentPage
    func fetchReplies(commentId: Int, limit: Int, cursor: String?) async throws -> CommentPage
    func createComment(postId: Int, content: String, parentId: Int?) async throws -> Comment
    func likeComment(commentId: Int) async throws -> CommentLikeResponse
}

protocol CommunityServiceProtocol {
    func fetchFollowedCommunities(limit: Int, cursor: String?) async throws -> CommunityPage
    func fetchRecommendedCommunities(limit: Int) async throws -> [CommunitySearchResult]
    func searchCommunities(query: String, limit: Int, cursor: String?) async throws -> SearchResultPage<CommunitySearchResult>
    func fetchTopProfessionCommunities(limit: Int) async throws -> [CommunitySearchResult]
    func followCommunity(id: Int) async throws
    func unfollowCommunity(id: Int) async throws
}

protocol DiscoveryServiceProtocol {
    func searchLoops(query: String, limit: Int, cursor: String?) async throws -> SearchResultPage<LoopDTO>
    func searchHashtags(query: String, limit: Int, cursor: String?) async throws -> SearchResultPage<HashtagDTO>
}

protocol NotificationServiceProtocol {
    func fetchNotifications(limit: Int, cursor: String?) async throws -> NotificationPage
    func markRead(notificationId: Int) async throws
    func fetchPreferences() async throws -> NotificationPreferencesDTO
    func updatePreferences(_ update: NotificationPreferencesUpdateRequest) async throws -> NotificationPreferencesDTO
}

protocol ModerationServiceProtocol {
    func createReport(targetType: String, targetId: Int, reason: String) async throws -> Int?
    func createAppeal(targetType: String, targetId: Int?, reason: String) async throws -> Int?
    func fetchViolations(limit: Int, cursor: String?) async throws -> ViolationsPage
    func fetchAppeals(status: String?) async throws -> [Appeal]
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
