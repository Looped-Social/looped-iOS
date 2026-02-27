import Foundation
import Testing
@testable import looped_iOS

@Suite
@MainActor
struct DeepLinkRouterTests {
    @Test
    func homeDeepLinkRoutesWithoutAuthentication() {
        let router = DeepLinkRouter.shared
        resetRouter(router)
        defer { resetRouter(router) }

        let handled = router.handleIncomingURL(URL(string: "looped://home")!)
        #expect(handled)
        #expect(router.pendingNavigation?.destination == .home)
        #expect(router.pendingNavigation?.pathType == .home)
        #expect(router.pendingNavigation?.resumedAfterLogin == false)

        if let request = router.pendingNavigation {
            router.consumeNavigation(request)
        }
    }

    @Test
    func messagesDeepLinkQueuesUntilAuthenticated() {
        let router = DeepLinkRouter.shared
        resetRouter(router)
        defer { resetRouter(router) }

        let handled = router.handleIncomingURL(URL(string: "looped://messages")!)
        #expect(handled)
        #expect(router.pendingNavigation == nil)

        router.setAuthenticationState(true)

        #expect(router.pendingNavigation?.destination == .messages)
        #expect(router.pendingNavigation?.pathType == .messages)
        #expect(router.pendingNavigation?.resumedAfterLogin == true)

        if let request = router.pendingNavigation {
            router.consumeNavigation(request)
        }
    }

    @Test
    func createPostDeepLinkRoutesWhenAuthenticated() {
        let router = DeepLinkRouter.shared
        resetRouter(router)
        defer { resetRouter(router) }
        router.setAuthenticationState(true)

        let handled = router.handleIncomingURL(URL(string: "looped://create-post")!)
        #expect(handled)
        #expect(router.pendingNavigation?.destination == .createPost)
        #expect(router.pendingNavigation?.pathType == .createPost)
        #expect(router.pendingNavigation?.resumedAfterLogin == false)

        if let request = router.pendingNavigation {
            router.consumeNavigation(request)
        }
    }

    @Test
    func profileDeepLinkRoutesWhenAuthenticated() {
        let router = DeepLinkRouter.shared
        resetRouter(router)
        defer { resetRouter(router) }
        router.setAuthenticationState(true)

        let handled = router.handleIncomingURL(URL(string: "looped://profile")!)
        #expect(handled)
        #expect(router.pendingNavigation?.destination == .profileTab)
        #expect(router.pendingNavigation?.pathType == .profileTab)
        #expect(router.pendingNavigation?.resumedAfterLogin == false)

        if let request = router.pendingNavigation {
            router.consumeNavigation(request)
        }
    }

    @Test
    func communityDeepLinkParsesCommunityId() {
        let router = DeepLinkRouter.shared
        resetRouter(router)
        defer { resetRouter(router) }
        router.setAuthenticationState(true)

        let handled = router.handleIncomingURL(URL(string: "looped://community/42")!)
        #expect(handled)
        #expect(router.pendingNavigation?.destination == .community(42))
        #expect(router.pendingNavigation?.pathType == .community)
        #expect(router.pendingNavigation?.resumedAfterLogin == false)

        if let request = router.pendingNavigation {
            router.consumeNavigation(request)
        }
    }

    @Test
    func universalCommunityDeepLinkParsesCommunityId() {
        let router = DeepLinkRouter.shared
        resetRouter(router)
        defer { resetRouter(router) }
        router.setAuthenticationState(true)

        let handled = router.handleIncomingURL(URL(string: "https://mylooped.app/c/142")!)
        #expect(handled)
        #expect(router.pendingNavigation?.destination == .community(142))
        #expect(router.pendingNavigation?.pathType == .community)
        #expect(router.pendingNavigation?.resumedAfterLogin == false)

        if let request = router.pendingNavigation {
            router.consumeNavigation(request)
        }
    }

    @Test
    func invalidUniversalCommunityDeepLinkFallsBackToHome() {
        let router = DeepLinkRouter.shared
        resetRouter(router)
        defer { resetRouter(router) }
        router.setAuthenticationState(true)

        let handled = router.handleIncomingURL(URL(string: "https://mylooped.app/c/not-a-number")!)
        #expect(handled)
        #expect(router.pendingNavigation?.destination == .home)
        #expect(router.pendingNavigation?.pathType == .community)
        #expect(router.pendingNavigation?.resumedAfterLogin == false)

        if let request = router.pendingNavigation {
            router.consumeNavigation(request)
        }
    }

    @Test
    func universalCommunityDeepLinkQueuesUntilAuthenticated() {
        let router = DeepLinkRouter.shared
        resetRouter(router)
        defer { resetRouter(router) }

        let handled = router.handleIncomingURL(URL(string: "https://mylooped.app/c/777")!)
        #expect(handled)
        #expect(router.pendingNavigation == nil)

        router.setAuthenticationState(true)

        #expect(router.pendingNavigation?.destination == .community(777))
        #expect(router.pendingNavigation?.pathType == .community)
        #expect(router.pendingNavigation?.resumedAfterLogin == true)

        if let request = router.pendingNavigation {
            router.consumeNavigation(request)
        }
    }

    @Test
    func feedDeepLinkRoutesToHome() {
        let router = DeepLinkRouter.shared
        resetRouter(router)
        defer { resetRouter(router) }
        router.setAuthenticationState(true)

        let handled = router.handleIncomingURL(URL(string: "looped://feed")!)
        #expect(handled)
        #expect(router.pendingNavigation?.destination == .home)
        #expect(router.pendingNavigation?.pathType == .home)

        if let request = router.pendingNavigation {
            router.consumeNavigation(request)
        }
    }

    @Test
    func feedTrendingDeepLinkRoutesToSearch() {
        let router = DeepLinkRouter.shared
        resetRouter(router)
        defer { resetRouter(router) }
        router.setAuthenticationState(true)

        let handled = router.handleIncomingURL(URL(string: "looped://feed?tab=trending&community_id=42")!)
        #expect(handled)
        #expect(router.pendingNavigation?.destination == .search)
        #expect(router.pendingNavigation?.pathType == .search)

        if let request = router.pendingNavigation {
            router.consumeNavigation(request)
        }
    }

    private func resetRouter(_ router: DeepLinkRouter) {
        router.setAuthenticationState(true)
        if let request = router.pendingNavigation {
            router.consumeNavigation(request)
        }
        router.setAuthenticationState(false)
        if let request = router.pendingNavigation {
            router.consumeNavigation(request)
        }
    }
}
