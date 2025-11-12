import Foundation
import Combine
import UIKit
import AuthenticationServices

protocol AuthServiceProtocol {
    var authStateChanged: AnyPublisher<Bool, Never> { get }
    
    func login(email: String, password: String) async throws
    func signUp(email: String, password: String, username: String, company: String) async throws
    func signOut()
    func refreshToken() async throws
    var isAuthenticated: Bool { get }

    // Social sign-in
    func signInWithGoogle(presenting: UIViewController) async throws
    func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async throws
}

protocol FeedServiceProtocol {
    func getPosts() async throws -> [Post]
    func createPost(content: String, isAnonymous: Bool) async throws -> Post
    func reactToPost(postId: UUID, reaction: ReactionType) async throws
}

protocol MessageServiceProtocol {
    func getChannels() async throws -> [Channel]
    func getMessages(channelId: UUID) async throws -> [Message]
    func sendMessage(content: String, channelId: UUID) async throws -> Message
    func sendDirectMessage(content: String, receiverId: UUID) async throws -> Message
}

protocol UserServiceProtocol {
    func getCurrentUser() async throws -> User
    func updateProfile(displayName: String?, bio: String?, isAnonymous: Bool) async throws -> User
    func verifyEmployment(verification: EmploymentVerification) async throws
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
