import Foundation
import Combine
import UIKit
import AuthenticationServices

// MARK: - Mock Auth Service
class MockAuthService: AuthServiceProtocol {
    
    @Published private var _isAuthenticated = false
    
    var authStateChanged: AnyPublisher<Bool, Never> {
        $_isAuthenticated.eraseToAnyPublisher()
    }
    
    var isAuthenticated: Bool {
        _isAuthenticated
    }
    
    func login(email: String, password: String) async throws {
        // Simulate API delay
        try await Task.sleep(for: .seconds(MockConfig.mockDelay))
        
        // Simple mock validation
        if email.isEmpty || password.isEmpty {
            throw AuthError.invalidCredentials
        }
        
        // Always succeed for demo purposes
        _isAuthenticated = true
    }
    
    func signUp(email: String, password: String, username: String, company: String) async throws {
        // Simulate API delay
        try await Task.sleep(for: .seconds(MockConfig.mockDelay))
        
        // Simple mock validation
        if email.isEmpty || password.isEmpty || username.isEmpty || company.isEmpty {
            throw AuthError.invalidCredentials
        }
        
        // Always succeed for demo purposes
        _isAuthenticated = true
    }
    
    func signOut() {
        _isAuthenticated = false
    }
    
    func refreshToken() async throws {
        // Mock refresh - always succeeds
        try await Task.sleep(for: .seconds(0.2))
    }

    func signInWithGoogle(presenting: UIViewController) async throws {
        // Simulate Google sign-in success
        try await Task.sleep(for: .seconds(0.5))
        _isAuthenticated = true
    }

    func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws {
        // Simulate Apple sign-in success
        try await Task.sleep(for: .seconds(0.5))
        _isAuthenticated = true
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async throws {
        // Simulate Apple sign-in with credential
        try await Task.sleep(for: .seconds(0.5))
        _isAuthenticated = true
    }
}

// MARK: - Mock Feed Service
class MockFeedService: FeedServiceProtocol {
    
    func getPosts() async throws -> [Post] {
        // Simulate API delay
        try await Task.sleep(for: .seconds(MockConfig.mockDelay))
        
        // Return mock posts sorted by most recent
        return MockPosts.getRecentPosts()
    }
    
    func createPost(content: String, isAnonymous: Bool) async throws -> Post {
        // Simulate API delay
        try await Task.sleep(for: .seconds(MockConfig.mockDelay))
        
        // Create and return new post
        return MockPosts.createPost(content: content, isAnonymous: isAnonymous)
    }
    
    func reactToPost(postId: UUID, reaction: ReactionType) async throws {
        // Simulate API delay
        try await Task.sleep(for: .seconds(0.3))
        
        // In a real app, this would update the backend
        // For mock data, we can simulate the reaction
        let _ = MockPosts.addReaction(to: postId, reaction: reaction)
    }
}

// MARK: - Mock Message Service
class MockMessageService: MessageServiceProtocol {
    
    func getChannels() async throws -> [Channel] {
        // Simulate API delay
        try await Task.sleep(for: .seconds(MockConfig.mockDelay))
        
        return MockMessages.channels
    }
    
    func getMessages(channelId: UUID) async throws -> [Message] {
        // Simulate API delay
        try await Task.sleep(for: .seconds(MockConfig.mockDelay))
        
        return MockMessages.getMessagesForChannel(channelId)
    }
    
    func sendMessage(content: String, channelId: UUID) async throws -> Message {
        // Simulate API delay
        try await Task.sleep(for: .seconds(0.5))
        
        return MockMessages.sendMessage(content: content, to: channelId)
    }
    
    func sendDirectMessage(content: String, receiverId: UUID) async throws -> Message {
        // Simulate API delay
        try await Task.sleep(for: .seconds(0.5))
        
        return MockMessages.sendDirectMessage(content: content, to: receiverId)
    }
}

// MARK: - Mock User Service
class MockUserService: UserServiceProtocol {
    
    func getCurrentUser() async throws -> User {
        // Simulate API delay
        try await Task.sleep(for: .seconds(MockConfig.mockDelay))
        
        return MockUsers.currentUser
    }
    
    func updateProfile(displayName: String?, bio: String?, isAnonymous: Bool) async throws -> User {
        // Simulate API delay
        try await Task.sleep(for: .seconds(MockConfig.mockDelay))

        // Create updated user with new values
        return User(
            id: MockUsers.currentUser.id,
            username: MockUsers.currentUser.username,
            displayName: displayName,
            handle: MockUsers.currentUser.handle,
            company: MockUsers.currentUser.company,
            bio: bio,
            profileImageURL: MockUsers.currentUser.profileImageURL,
            isVerified: MockUsers.currentUser.isVerified,
            isAnonymous: isAnonymous,
            createdAt: MockUsers.currentUser.createdAt,
            updatedAt: Date()
        )
    }
    
    func verifyEmployment(verification: EmploymentVerification) async throws {
        // Simulate API delay for employment verification
        try await Task.sleep(for: .seconds(2.0))
        
        // Mock verification always succeeds
    }
}

// MARK: - Mock WebSocket Service
class MockWebSocketService: NSObject, WebSocketServiceProtocol {
    
    @Published private var _connectionState: WebSocketConnectionState = .disconnected
    private let _messageReceived = PassthroughSubject<Message, Never>()
    
    var connectionState: AnyPublisher<WebSocketConnectionState, Never> {
        $_connectionState.eraseToAnyPublisher()
    }
    
    var messageReceived: AnyPublisher<Message, Never> {
        _messageReceived.eraseToAnyPublisher()
    }
    
    private var simulationTimer: Timer?
    
    func connect() async {
        _connectionState = .connecting
        
        // Simulate connection delay
        try? await Task.sleep(for: .seconds(1.0))
        _connectionState = .connected
        
        // Start simulating incoming messages
        startMessageSimulation()
    }
    
    func disconnect() {
        _connectionState = .disconnected
        simulationTimer?.invalidate()
        simulationTimer = nil
    }
    
    func joinChannel(_ channelId: UUID) {
        // Mock joining channel - no actual implementation needed
        print("Mock: Joined channel \(channelId)")
    }
    
    func leaveChannel(_ channelId: UUID) {
        // Mock leaving channel - no actual implementation needed
        print("Mock: Left channel \(channelId)")
    }
    
    // MARK: - Private Methods
    private func startMessageSimulation() {
        // Simulate random incoming messages every 10-30 seconds
        simulationTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 10...30), repeats: false) { [weak self] _ in
            self?.simulateIncomingMessage()
            self?.startMessageSimulation() // Schedule next message
        }
    }
    
    private func simulateIncomingMessage() {
        // Create a random mock message from a colleague
        let randomColleague = MockUsers.getRandomColleague()
        let randomChannel = MockMessages.channels.randomElement()!
        
        let simulatedMessage = Message(
            id: UUID(),
            content: generateRandomMessage(),
            senderId: randomColleague.id,
            senderDisplayName: randomColleague.displayName,
            receiverId: nil,
            channelId: randomChannel.id,
            messageType: .channel,
            isRead: false,
            attachments: nil,
            createdAt: Date()
        )
        
        _messageReceived.send(simulatedMessage)
    }
    
    private func generateRandomMessage() -> String {
        let messages = [
            "Anyone up for coffee? ☕️",
            "Great job on the presentation today!",
            "The weather is perfect for a walking meeting",
            "Quick question about the project timeline",
            "Thanks for the help with debugging earlier",
            "Don't forget about the team lunch tomorrow",
            "Has anyone seen my water bottle? I left it somewhere...",
            "The new feature is looking really good! 🚀",
            "Can someone review my PR when you get a chance?",
            "Happy Friday everyone! 🎉"
        ]
        return messages.randomElement()!
    }
}
