# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Looped** is a workplace-verified social iOS app built with SwiftUI. It's a pseudonymous social platform where employees verify their employment and then post/message within their company's channels. Think "YikYak for any employer."

This is an early-stage MVP focusing on core functionality with a privacy-first approach (minimal data collection, pseudonymous by default) and mobile-first design philosophy.

## Repo Hygiene (Important)

- Ignore Xcode user/workspace state files (e.g. anything under `*.xcodeproj/**/xcuserdata/**` and `**/*.xcuserstate`) unless explicitly asked.
- Don’t try to “fix” or revert those files as part of feature work; they’re local-machine artifacts.

## Technical Stack

- **iOS Target**: 15+ minimum deployment target (currently configured for 18.5+)
- **Swift Version**: 5.7+
- **UI Framework**: SwiftUI + Combine
- **Architecture**: MVVM pattern (client-side only)
- **Backend**: Java API (separate repository/deployment)
- **Communication**: HTTP/WebSocket connections to Java backend
- **Real-time Features**: WebSocket connections to Java server
- **Testing**: Swift Testing framework (modern replacement for XCTest)
- **Concurrency**: Swift's modern async/await for network calls

## Architecture Overview

### Client-Server Separation
- **iOS App**: Pure client-side application - handles only UI, state management, and API communication
- **Java Backend**: Separate repository/deployment - handles all business logic, data persistence, authentication logic, and real-time WebSocket server
- **Communication**: iOS app makes HTTP requests and WebSocket connections to Java API endpoints
- **Data Flow**: iOS → Java API → Database (iOS never touches database directly)

### iOS App Responsibilities
- SwiftUI views and user interface
- Client-side state management via ViewModels
- HTTP/WebSocket client implementations
- Authentication token storage and management
- Input validation and error handling for UI
- Real-time UI updates from WebSocket messages

### Backend API Responsibilities  
- All business logic and data validation
- User authentication and authorization
- Database operations and data persistence
- WebSocket server for real-time features
- Push notification triggers
- Employment verification logic

## Development Commands

### Build & Run
- **Build and run**: `Cmd + R` in Xcode (User must perform builds - Claude cannot build projects)
- **Test**: `Cmd + U` in Xcode or use Test Navigator
- **Clean build**: `Cmd + Shift + K` in Xcode

**IMPORTANT**: Claude cannot build, run, or test iOS projects. Only the user can perform these actions in Xcode. Claude should ask the user to build/test when needed.

## Project Structure

Current structure is minimal template code. Implement features following this planned architecture:

```
├── Models/          # Client-side data structures (User, Post, Message, etc.)
├── Views/           # SwiftUI views (Feed, Messages, Profile, Settings)
├── ViewModels/      # Client-side state management and UI logic
├── Services/        # API clients, WebSocket connections, authentication token management
└── Protocols/       # Shared interfaces for API services and data contracts
```

## MVP Features

- **Company feed** with posts & reactions
- **Real-time messaging** between verified users
- **Push notifications** system
- **User profile** management
- **Settings** page
- **Anonymous posting** mode toggle
- **Employment verification** system

## Coding Standards & Architecture Patterns

### MVVM Guidelines (Client-Side)
- **Simple UI State**: Use `@State` for simple view-local state
- **Client State Management**: Use `@StateObject` ViewModels for UI state and API interaction
- **Data Flow**: ViewModels publish changes via `@Published` properties from API responses
- **Keep Views Lightweight**: API calls and data transformation belong in ViewModels, not Views
- **Stateless Client**: ViewModels coordinate with backend API, no local business logic

### SwiftUI Best Practices
- **Prefer structs** for views and data models
- **Use classes** only when needed (reference semantics, inheritance)
- **Protocol-oriented programming** for shared behavior via protocol extensions
- **Functional approaches** for data transformations

### Design System (Required)
- **Fonts**: Use only `Views/Shared/Core/LoopedFonts.swift` (no `.system`, `.headline`, `.body`, etc). Always check if a font token already exists before adding a new one.
- **Colors**: Use only `Views/Shared/Core/LoopedColors.swift` (no `Color.white/black/gray/red/green` or system colors).
- **Tokens first**: Always search for existing font/color tokens before adding new ones. If missing, add the token to the design system file (`LoopedFonts.swift` or `LoopedColors.swift`), and for colors also add an asset in `Assets.xcassets/Colors`.
- **Background/Contrast semantics**: `loopedBackground` is company white (light) / company black (dark). `loopedContrast` is the inverse.
- **Transparency**: Use `Color.loopedClear` only for true transparency (e.g., hit targets/overlays).
- **Reporting**: Call out any necessary exceptions in responses.

### State Management Patterns
- `@State`: View-local simple state
- `@StateObject`: ViewModel instances owned by view
- `@Published`: ViewModel properties that trigger UI updates
- `@ObservedObject`: ViewModels passed from parent views

### Service Layer Patterns (API Communication)
- **Protocol-based APIs**: Define service protocols for dependency injection and testing
- **HTTP Client**: RESTful API calls to Java backend endpoints
- **WebSocket Client**: Real-time connections to Java WebSocket server
- **Async/await**: Use modern Swift concurrency for all network calls
- **Error handling**: Consistent error handling for network and API errors
- **Authentication**: Token-based auth with token storage and refresh logic
- **No Local Storage**: Backend handles all data persistence, iOS manages only UI state

### Code Organization
- **Structs by default**: Use structs for data models and views
- **Protocol extensions**: Share behavior through protocol extensions
- **Dependency injection**: Use protocols to inject API services into ViewModels
- **Client-Server Separation**: iOS handles UI/UX, Java backend handles all business logic
- **API-First Design**: Model iOS data structures to match backend API contracts

## Development Context

### Current State
**IMPORTANT**: Project currently contains only Xcode template code:
- `loopedApp.swift`: Basic SwiftUI app entry point
- `ContentView.swift`: "Hello, world!" placeholder
- Empty test templates

### Privacy & Design Philosophy
- **Privacy-first**: Minimal data collection, pseudonymous by default
- **Mobile-first**: Optimized for iOS experience
- **Real-time social**: Live messaging and feed updates are core features
- **Company-focused**: Employment verification enables company-specific channels

### Key Implementation Priorities
1. **Real-time features** are core to user experience
2. **Employment verification** system is foundational
3. **Pseudonymous identity** while maintaining company verification
4. **Mobile-optimized** UI/UX patterns

## Testing Strategy

- **Unit Tests**: Swift Testing framework in `loopedTests/`
- **UI Tests**: XCTest framework in `loopedUITests/` 
- **ViewModel Testing**: Test UI state management and API interaction logic
- **Service Testing**: Mock HTTP/WebSocket services for reliable tests
- **No Backend Testing**: Java backend testing handled in separate repository
