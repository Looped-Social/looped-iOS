import Foundation

// MARK: - Mock Data Configuration
struct MockConfig {
    static let useMockData = false  // for prod set to false
    
    // Current mock user (simulates logged in user)
    static let currentUserId = UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!
    
    // Mock API delays (for realistic loading states)
    static let mockDelay: Double = 0.5 // seconds
}

// MARK: - Easy Mock Data Switching
// Usage in ViewModels:
// let service: FeedServiceProtocol = MockConfig.useMockData ? MockFeedService() : FeedService()
