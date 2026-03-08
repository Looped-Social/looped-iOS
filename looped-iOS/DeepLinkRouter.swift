import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

enum DeepLinkFailureReason: String {
    case parseError = "parse_error"
    case unauthorized
    case notFound = "not_found"
    case unavailable
    case networkError = "network_error"
}

enum DeepLinkPathType: String {
    case home
    case messages
    case search
    case profileTab = "profile_tab"
    case createPost = "create_post"
    case community
    case post
    case profile
    case comment
    case user
    case announcement
    case conversation
    case channel
    case unsupported
}

enum DeepLinkDestination: Equatable {
    case messages
    case search
    case profileTab
    case createPost
    case community(Int)
    case post(Int)
    case profileSlug(String)
    case comment(Int, postId: Int?)
    case user(Int, isAnonymous: Bool)
    case announcement
    case conversation(Int)
    case channel(Int)
    case home

    var routedName: String {
        switch self {
        case .messages:
            return "messages"
        case .search:
            return "search"
        case .profileTab:
            return "profile_tab"
        case .createPost:
            return "create_post"
        case .community:
            return "community"
        case .post:
            return "post"
        case .profileSlug:
            return "profile_slug"
        case .comment:
            return "comment"
        case .user:
            return "user"
        case .announcement:
            return "announcement"
        case .conversation:
            return "conversation"
        case .channel:
            return "channel"
        case .home:
            return "home"
        }
    }

    var requiresAuthentication: Bool {
        switch self {
        case .home:
            return false
        case .messages, .search, .profileTab, .createPost, .community:
            return true
        default:
            return true
        }
    }
}

struct DeepLinkNavigationRequest: Identifiable, Equatable {
    let id = UUID()
    let destination: DeepLinkDestination
    let originalURL: URL
    let fallbackURL: URL?
    let pathType: DeepLinkPathType
    let resumedAfterLogin: Bool
}

@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    @Published private(set) var pendingNavigation: DeepLinkNavigationRequest?

    private var queuedDeepLink: QueuedDeepLink?
    private var isAuthenticated = false
    private var didBecomeActive = false
    private var lastFingerprint = ""
    private var lastHandledAt = Date.distantPast

    private let allowedUniversalHosts: Set<String> = [
        "looped-social.com",
        "www.looped-social.com"
    ]
    private let duplicateWindow: TimeInterval = 1.2

    private init() {}

    func markDidBecomeActive() {
        didBecomeActive = true
    }

    func setAuthenticationState(_ authenticated: Bool) {
        let changed = isAuthenticated != authenticated
        isAuthenticated = authenticated

        guard changed, authenticated, let queuedDeepLink else { return }
        self.queuedDeepLink = nil
        route(
            destination: queuedDeepLink.destination,
            url: queuedDeepLink.url,
            pathType: queuedDeepLink.pathType,
            resumedAfterLogin: true,
            fallbackURL: queuedDeepLink.fallbackURL
        )
    }

    @discardableResult
    func handleUserActivity(_ userActivity: NSUserActivity) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            return handleIncomingURL(url)
        }

        if let spotlightURL = SpotlightPostRoute.deepLinkURL(from: userActivity) {
            return handleIncomingURL(spotlightURL)
        }

        return false
    }

    @discardableResult
    func handleIncomingURL(_ url: URL, fallbackURL: URL? = nil) -> Bool {
        guard let parsed = parse(url) else { return false }

        emit(
            "deeplink_received",
            [
                "url": url.absoluteString,
                "path_type": parsed.pathType.rawValue,
                "app_state": currentAppState().rawValue
            ]
        )

        if isDuplicate(url) {
            return true
        }

        if let failureReason = parsed.failureReason {
            emit(
                "deeplink_failed",
                [
                    "url": url.absoluteString,
                    "path_type": parsed.pathType.rawValue,
                    "reason": failureReason.rawValue
                ]
            )
        }

        if parsed.destination.requiresAuthentication, !isAuthenticated {
            queuedDeepLink = QueuedDeepLink(
                url: url,
                destination: parsed.destination,
                pathType: parsed.pathType,
                fallbackURL: fallbackURL
            )
            emit(
                "deeplink_failed",
                [
                    "url": url.absoluteString,
                    "path_type": parsed.pathType.rawValue,
                    "reason": DeepLinkFailureReason.unauthorized.rawValue
                ]
            )
            return true
        }

        route(
            destination: parsed.destination,
            url: url,
            pathType: parsed.pathType,
            resumedAfterLogin: false,
            fallbackURL: fallbackURL
        )
        return true
    }

    func consumeNavigation(_ request: DeepLinkNavigationRequest) {
        guard pendingNavigation?.id == request.id else { return }
        pendingNavigation = nil
    }

    func reportNavigationFailure(for request: DeepLinkNavigationRequest, reason: DeepLinkFailureReason) {
        emit(
            "deeplink_failed",
            [
                "url": request.originalURL.absoluteString,
                "path_type": request.pathType.rawValue,
                "reason": reason.rawValue
            ]
        )
    }

    private func route(
        destination: DeepLinkDestination,
        url: URL,
        pathType: DeepLinkPathType,
        resumedAfterLogin: Bool,
        fallbackURL: URL?
    ) {
        let request = DeepLinkNavigationRequest(
            destination: destination,
            originalURL: url,
            fallbackURL: fallbackURL,
            pathType: pathType,
            resumedAfterLogin: resumedAfterLogin
        )
        pendingNavigation = request

        emit(
            "deeplink_routed",
            [
                "url": url.absoluteString,
                "path_type": pathType.rawValue,
                "destination": destination.routedName
            ]
        )

        emit(
            "deeplink_resumed_after_login",
            [
                "url": url.absoluteString,
                "resumed": resumedAfterLogin ? "true" : "false"
            ]
        )
    }

    private func parse(_ url: URL) -> ParsedDeepLink? {
        let scheme = (url.scheme ?? "").lowercased()

        if scheme == "https" {
            let host = (url.host ?? "").lowercased()
            guard allowedUniversalHosts.contains(host) else { return nil }
            return parseUniversal(url)
        }

        if scheme == "looped" {
            return parseLegacy(url)
        }

        return nil
    }

    private func parseUniversal(_ url: URL) -> ParsedDeepLink {
        let encodedPath = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
        let encodedSegments = encodedPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        guard let first = encodedSegments.first?.lowercased() else {
            return ParsedDeepLink(destination: .home, pathType: .unsupported)
        }

        switch first {
        case "p":
            guard encodedSegments.count > 1 else {
                return ParsedDeepLink(destination: .home, pathType: .post, failureReason: .parseError)
            }
            guard let postId = Int(encodedSegments[1]), postId > 0 else {
                return ParsedDeepLink(destination: .home, pathType: .post, failureReason: .parseError)
            }
            return ParsedDeepLink(destination: .post(postId), pathType: .post)

        case "c":
            guard encodedSegments.count > 1 else {
                return ParsedDeepLink(destination: .home, pathType: .community, failureReason: .parseError)
            }
            guard let communityId = Int(encodedSegments[1]), communityId > 0 else {
                return ParsedDeepLink(destination: .home, pathType: .community, failureReason: .parseError)
            }
            return ParsedDeepLink(destination: .community(communityId), pathType: .community)

        case "u":
            guard encodedSegments.count > 1 else {
                return ParsedDeepLink(destination: .home, pathType: .profile, failureReason: .parseError)
            }
            let rawSlug = encodedSegments[1]
            let slug = rawSlug.removingPercentEncoding ?? rawSlug
            guard !slug.isEmpty else {
                return ParsedDeepLink(destination: .home, pathType: .profile, failureReason: .parseError)
            }
            return ParsedDeepLink(destination: .profileSlug(slug), pathType: .profile)

        case "create-post", "create_post", "new-post", "new_post":
            return ParsedDeepLink(destination: .createPost, pathType: .createPost)

        default:
            return ParsedDeepLink(destination: .home, pathType: .unsupported)
        }
    }

    private func parseLegacy(_ url: URL) -> ParsedDeepLink {
        let host = (url.host ?? "").lowercased()
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let idValue = pathComponents.first.flatMap(Int.init)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let postId = components?.queryItems?.first(where: { $0.name == "post_id" })?.value.flatMap(Int.init)
        let tab = components?.queryItems?.first(where: { $0.name == "tab" })?.value?.lowercased()
        let isAnonymous = components?.queryItems?.first(where: { $0.name == "anon" })?.value == "true"

        switch host {
        case "home":
            return ParsedDeepLink(destination: .home, pathType: .home)
        case "feed":
            // Backend may use looped://feed for highlights or looped://feed?tab=trending for trending fallback.
            if tab == "trending" {
                return ParsedDeepLink(destination: .search, pathType: .search)
            }
            return ParsedDeepLink(destination: .home, pathType: .home)
        case "messages":
            return ParsedDeepLink(destination: .messages, pathType: .messages)
        case "search":
            return ParsedDeepLink(destination: .search, pathType: .search)
        case "profile":
            return ParsedDeepLink(destination: .profileTab, pathType: .profileTab)
        case "create-post", "create_post", "new-post", "new_post":
            return ParsedDeepLink(destination: .createPost, pathType: .createPost)
        case "community":
            if let idValue {
                return ParsedDeepLink(destination: .community(idValue), pathType: .community)
            }
            return ParsedDeepLink(destination: .home, pathType: .community, failureReason: .parseError)
        case "post":
            if let idValue {
                return ParsedDeepLink(destination: .post(idValue), pathType: .post)
            }
            return ParsedDeepLink(destination: .home, pathType: .post, failureReason: .parseError)
        case "comment":
            if let idValue {
                return ParsedDeepLink(destination: .comment(idValue, postId: postId), pathType: .comment)
            }
            return ParsedDeepLink(destination: .home, pathType: .comment, failureReason: .parseError)
        case "user":
            if let idValue {
                return ParsedDeepLink(destination: .user(idValue, isAnonymous: isAnonymous), pathType: .user)
            }
            return ParsedDeepLink(destination: .home, pathType: .user, failureReason: .parseError)
        case "announcement":
            if idValue != nil {
                return ParsedDeepLink(destination: .announcement, pathType: .announcement)
            }
            return ParsedDeepLink(destination: .home, pathType: .announcement, failureReason: .parseError)
        case "conversations":
            if let idValue {
                return ParsedDeepLink(destination: .conversation(idValue), pathType: .conversation)
            }
            return ParsedDeepLink(destination: .home, pathType: .conversation, failureReason: .parseError)
        case "channels":
            if let idValue {
                return ParsedDeepLink(destination: .channel(idValue), pathType: .channel)
            }
            return ParsedDeepLink(destination: .home, pathType: .channel, failureReason: .parseError)
        default:
            return ParsedDeepLink(destination: .home, pathType: .unsupported)
        }
    }

    private func currentAppState() -> DeepLinkAppState {
        if !didBecomeActive {
            return .cold
        }

        #if canImport(UIKit)
        switch UIApplication.shared.applicationState {
        case .active:
            return .foreground
        case .inactive, .background:
            return .warm
        @unknown default:
            return .warm
        }
        #else
        return .foreground
        #endif
    }

    private func isDuplicate(_ url: URL) -> Bool {
        let now = Date()
        let fingerprint = url.absoluteString
        defer {
            lastFingerprint = fingerprint
            lastHandledAt = now
        }
        guard lastFingerprint == fingerprint else { return false }
        return now.timeIntervalSince(lastHandledAt) <= duplicateWindow
    }

    private func emit(_ event: String, _ fields: [String: String]) {
        let body = fields
            .map { key, value in "\(key)=\(value.replacingOccurrences(of: " ", with: "_"))" }
            .sorted()
            .joined(separator: " ")
        print("LOOPED_DEEPLINK \(event) \(body)")
    }
}

private struct ParsedDeepLink {
    let destination: DeepLinkDestination
    let pathType: DeepLinkPathType
    let failureReason: DeepLinkFailureReason?

    init(destination: DeepLinkDestination, pathType: DeepLinkPathType, failureReason: DeepLinkFailureReason? = nil) {
        self.destination = destination
        self.pathType = pathType
        self.failureReason = failureReason
    }
}

private struct QueuedDeepLink {
    let url: URL
    let destination: DeepLinkDestination
    let pathType: DeepLinkPathType
    let fallbackURL: URL?
}

private enum DeepLinkAppState: String {
    case cold
    case warm
    case foreground
}
