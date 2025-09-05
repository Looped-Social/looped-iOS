# Looped iOS App Architecture

## Overview

Looped is a workplace-verified social iOS app built with SwiftUI following MVVM architecture. The app is designed as a **pure client** that communicates with a separate Java backend server via HTTP APIs and WebSocket connections.

## Architecture Pattern: MVVM (Model-View-ViewModel)

### What is MVVM?

MVVM separates the app into three layers:

- **Model**: Data structures and business logic
- **View**: UI components (SwiftUI views)  
- **ViewModel**: Mediates between Views and Models, handles UI state

### Why MVVM for iOS?

1. **SwiftUI Integration**: `@StateObject` and `@Published` work perfectly with MVVM
2. **Testability**: ViewModels can be unit tested without UI
3. **Separation of Concerns**: UI logic separate from business logic
4. **Reactive Programming**: Combine framework enables reactive data flow

### MVVM Implementation in Looped

```swift
// View: SwiftUI component
struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel() // ViewModel ownership
    
    var body: some View {
        List {
            ForEach(viewModel.posts) { post in // Reactive UI updates
                PostRowView(post: post)
            }
        }
        .task { await viewModel.loadPosts() } // View triggers ViewModel actions
    }
}

// ViewModel: UI state management
@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = [] // Published state triggers UI updates
    
    func loadPosts() async {
        // Coordinates with Service layer
        posts = try await feedService.getPosts()
    }
}

// Model: Data structures from API
struct Post: Codable, Identifiable {
    let id: UUID
    let content: String
    let reactionCount: Int
}
```

## Client-Server Architecture

### iOS App Responsibilities (Client-Side Only)
- ✅ SwiftUI user interface
- ✅ Client-side state management via ViewModels  
- ✅ HTTP/WebSocket client implementations
- ✅ Authentication token storage (Keychain)
- ✅ Input validation for UI (basic field validation)
- ✅ Real-time UI updates from WebSocket messages

### Java Backend Responsibilities (Server-Side)
- ❌ All business logic and data validation
- ❌ User authentication and authorization  
- ❌ Database operations and data persistence
- ❌ WebSocket server for real-time features
- ❌ Push notification triggers
- ❌ Employment verification logic
- ❌ Feed algorithms and post ranking
- ❌ Message routing and channel management

### API Communication Flow

```
iOS App ←→ HTTP/WebSocket ←→ Java Backend ←→ Database

1. iOS makes API call with JWT token
2. Java backend validates token & business logic
3. Java backend queries/updates database
4. Java backend returns response to iOS
5. iOS updates UI with response data
```

## WebSocket Implementation

### Why WebSockets for iOS?

Unlike web apps that are limited to HTTP, iOS apps can maintain persistent connections for real-time features. WebSockets provide:

1. **Instant Message Delivery**: No polling delay
2. **Battery Efficiency**: Single persistent connection vs repeated HTTP requests
3. **Bidirectional Communication**: Server can push updates to client
4. **Lower Latency**: No HTTP request/response overhead

### Real-time Features Using WebSockets

```swift
class WebSocketService: WebSocketServiceProtocol {
    private var webSocketTask: URLSessionWebSocketTask?
    
    func connect() async {
        // Connect to Java WebSocket server
        let url = URL(string: "wss://api.looped.app/ws")!
        webSocketTask = urlSession?.webSocketTask(with: request)
        startListening() // Listen for incoming messages
    }
    
    func joinChannel(_ channelId: UUID) {
        // Tell server to start sending channel messages
        sendMessage(WebSocketMessage(type: "join_channel", payload: ["channelId": channelId]))
    }
}
```

### Real-time Features in Looped

1. **Live Chat Messages**: Messages appear instantly without refresh
2. **Feed Updates**: New posts stream to feed in real-time
3. **Typing Indicators**: "User is typing..." in channels
4. **Online Presence**: See who's active in company channels
5. **Live Reactions**: Post reactions update immediately
6. **Push Notifications**: Server triggers iOS push notifications

### WebSocket Message Flow

```
User A sends message → Java Backend → WebSocket Server → User B's iOS app → UI Update
```

## Do Other iOS Apps Use WebSockets?

### Apps That Use WebSockets:
- **Instagram**: Live comments, story reactions, DMs
- **WhatsApp**: Real-time messaging, typing indicators
- **Discord**: Voice/text chat, presence updates  
- **Slack**: Real-time messaging, notifications
- **Twitter**: Live tweet updates, trending topics
- **TikTok**: Live comments, reactions during streams
- **Zoom**: Real-time video/audio data

### Apps That Use Alternatives:
- **Facebook Feed**: Mostly HTTP polling + push notifications
- **LinkedIn**: HTTP requests + push notifications  
- **Email Apps**: Push notifications + periodic sync

### WebSocket vs Alternatives for Social Apps

| Feature | WebSocket | HTTP Polling | Push Notifications |
|---------|-----------|--------------|-------------------|
| Real-time messaging | ✅ Instant | ❌ 3-5s delay | ❌ Only when app closed |
| Battery usage | ✅ Efficient | ❌ High | ✅ Very efficient |
| Live reactions | ✅ Instant | ❌ Delayed | ❌ Too frequent |
| Typing indicators | ✅ Smooth | ❌ Choppy | ❌ Not applicable |
| Server load | ✅ Lower | ❌ Higher | ✅ Lowest |

## Project Structure

```
├── Models/                    # Data structures matching Java API
│   ├── User.swift            # User data model
│   ├── Post.swift            # Post & reaction models  
│   ├── Message.swift         # Message & channel models
│   └── AuthModels.swift      # Authentication request/response models
├── Views/                    # SwiftUI UI components
│   ├── FeedView.swift        # Company feed interface
│   ├── MessagesView.swift    # Chat and messaging UI
│   ├── ProfileView.swift     # User profile & settings
│   └── AuthView.swift        # Login/signup forms
├── ViewModels/               # MVVM state management
│   ├── FeedViewModel.swift   # Feed UI state & API coordination
│   ├── MessagesViewModel.swift # Chat UI state & WebSocket handling
│   ├── ProfileViewModel.swift # Profile UI state
│   └── AuthViewModel.swift   # Authentication UI state
├── Services/                 # API communication layer
│   ├── APIClient.swift       # HTTP client with JWT auth
│   ├── AuthService.swift     # Authentication API calls
│   ├── TokenStorage.swift    # Secure token storage (Keychain)
│   ├── FeedService.swift     # Feed API endpoints
│   ├── MessageService.swift  # Messaging API endpoints  
│   ├── UserService.swift     # User profile API endpoints
│   └── WebSocketService.swift # Real-time WebSocket client
├── Protocols/                # Service interfaces for dependency injection
│   └── ServiceProtocols.swift # Protocol definitions for testing
└── ContentView.swift         # Main app navigation (Auth → TabView)
```

## Data Flow Examples

### 1. User Login Flow
```
1. User enters email/password in AuthView
2. AuthView triggers AuthViewModel.login()
3. AuthViewModel calls AuthService.login()
4. AuthService sends POST /auth/login to Java backend
5. Java backend validates credentials against database
6. Java backend returns JWT token
7. iOS stores token in Keychain via TokenStorage
8. AuthViewModel publishes authentication state change
9. ContentView observes state change and shows MainTabView
```

### 2. Real-time Message Flow
```
1. User A types message in ChatView
2. ChatView calls ChatViewModel.sendMessage()
3. ChatViewModel calls MessageService.sendMessage()
4. MessageService sends POST /messages to Java backend
5. Java backend saves message to database
6. Java backend sends message via WebSocket to all channel members
7. User B's WebSocketService receives message
8. WebSocketService publishes message to ChatViewModel
9. ChatViewModel updates @Published messages array
10. User B's ChatView automatically updates with new message
```

### 3. Feed Update Flow
```
1. User creates new post via FeedView
2. FeedViewModel calls FeedService.createPost()
3. Java backend saves post and broadcasts to company WebSocket rooms
4. All company members receive real-time post via WebSocket
5. FeedViewModel receives post and updates @Published posts array
6. All users see new post appear in feed instantly
```

## Key Design Decisions

### 1. Protocol-Based Services
```swift
protocol FeedServiceProtocol {
    func getPosts() async throws -> [Post]
}

class FeedService: FeedServiceProtocol {
    // Implementation
}
```
**Benefits**: Dependency injection, easy testing with mocks

### 2. Async/Await for API Calls
```swift
func loadPosts() async {
    do {
        let posts = try await feedService.getPosts()
        self.posts = posts
    } catch {
        self.errorMessage = error.localizedDescription
    }
}
```
**Benefits**: Modern Swift concurrency, no callback hell

### 3. Combine for Reactive Updates
```swift
@Published var posts: [Post] = [] // Automatically triggers UI updates

webSocketService.messageReceived
    .sink { message in
        self.messages.append(message)
    }
```
**Benefits**: Reactive programming, automatic UI updates

### 4. Secure Token Storage
```swift
class TokenStorage {
    var token: String? {
        get { getFromKeychain(key: tokenKey) }
        set { saveToKeychain(key: tokenKey, value: newValue) }
    }
}
```
**Benefits**: Secure storage, automatic token management

## Testing Strategy

### Unit Tests
- **ViewModels**: Test state changes and API coordination
- **Services**: Test API calls with mocked responses
- **Models**: Test data parsing and validation

### Integration Tests
- **API Integration**: Test against staging Java backend
- **WebSocket Integration**: Test real-time message flow

### UI Tests
- **Authentication Flow**: Login/signup user journeys
- **Core Features**: Feed browsing, messaging, profile management

## Performance Considerations

### 1. Memory Management
- Use `@StateObject` for ViewModel ownership
- Use `@ObservedObject` for passed ViewModels
- Properly cancel Combine subscriptions

### 2. Network Efficiency
- Single WebSocket connection for all real-time features
- HTTP request caching where appropriate
- Pagination for large lists (feed, messages)

### 3. Battery Optimization
- WebSocket connection management (connect/disconnect based on app state)
- Background app refresh handling
- Efficient UI updates (only when data actually changes)

## Security Implementation

### 1. Authentication
- JWT tokens stored securely in iOS Keychain
- Automatic token refresh before expiration
- Secure transmission over HTTPS/WSS

### 2. Input Validation
- Client-side validation for UX (immediate feedback)
- Server-side validation for security (never trust client)
- Sanitized display of user-generated content

### 3. WebSocket Security
- WSS (WebSocket Secure) connections only
- JWT authentication for WebSocket connections
- Message validation and sanitization

This architecture provides a scalable, maintainable, and performant foundation for Looped's real-time social features while maintaining clear separation between client UI and server business logic.