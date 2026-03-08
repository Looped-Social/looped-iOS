//
//  ContentView.swift
//  looped-iOS
//
//  Created by William Millen on 9/5/25.
//

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif


enum MenuDestination: Identifiable {
    case posts
    case replies
    case liked
    case saved
    case drafts
    case analytics
    case faq
    case settings

    var id: String {
        switch self {
        case .posts: return "posts"
        case .replies: return "replies"
        case .liked: return "liked"
        case .saved: return "saved"
        case .drafts: return "drafts"
        case .analytics: return "analytics"
        case .faq: return "faq"
        case .settings: return "settings"
        }
    }
}

struct ContentView: View {
    private static let migrationNoticeKey = "workplace_fields_migration_v1"

    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var feedViewModel = FeedViewModel()
    @State private var keepBootstrapVisible = false
    @State private var showNotificationPermissionPrompt = false
    @State private var showProfileCompletionPrompt = false
    @State private var showMinimumSupportedVersionPrompt = false
    @State private var minimumSupportedVersionPromptMessage = ""
    @State private var minimumSupportedVersionPromptValue = ""
    @State private var minimumSupportedVersionUpdateUrl: URL?
    @State private var showFirstPostCongrats = false
    @State private var firstPostCongratsPostId: Int?
    @State private var globalToastMessage: ToastMessage?
    @State private var presentedUserNotice: UserNotice?
    @State private var inFlightUserNoticeAction: UserNoticeAckAction?
    @AppStorage("showAccountDeletedAlert") private var showAccountDeletedAlert = false
    @AppStorage("showAccountDeletionPendingAlert") private var showAccountDeletionPendingAlert = false
    @AppStorage("showAccountDeactivatedAlert") private var showAccountDeactivatedAlert = false
    @AppStorage("showProviderDisconnectStatusAlert") private var showProviderDisconnectStatusAlert = false
    @AppStorage("providerDisconnectStatusMessage") private var providerDisconnectStatusMessage = ""
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("preferCommunityShortNames") private var preferCommunityShortNames = true
    @AppStorage("defaultProfileImageUrl") private var defaultProfileImageUrl = ""
    @AppStorage("defaultProfileImageUrlFetchedAt") private var defaultProfileImageUrlFetchedAt = 0.0
    @AppStorage("notificationPermissionPromptLastShownAt") private var notificationPermissionPromptLastShownAt = 0.0
    @AppStorage("dismissedMinimumSupportedVersion") private var dismissedMinimumSupportedVersion = ""
    @AppStorage("dismissedMinimumSupportedVersionAt") private var dismissedMinimumSupportedVersionAt = 0.0
    private let spotlightIndexingService: SpotlightIndexingServiceProtocol = SpotlightIndexingService()
    private var uiTestBypassAuth: Bool {
        ProcessInfo.processInfo.environment["LOOPED_UI_TEST_BYPASS_AUTH"] == "1"
    }

    var body: some View {
        configuredContent
    }

    private var primaryContent: some View {
        Group {
            if uiTestBypassAuth {
                MainTabView()
            } else if authViewModel.isAuthenticated, (!authViewModel.didLoadIdentity || keepBootstrapVisible) {
                LaunchBootstrapView(isReady: authViewModel.didLoadIdentity) {
                    keepBootstrapVisible = false
                }
                .onAppear {
                    keepBootstrapVisible = !authViewModel.didLoadIdentity
                }
            } else if authViewModel.isAuthenticated {
                if !authViewModel.onboardingComplete {
                    AuthView(authViewModel: authViewModel)
                } else {
                    MainTabView()
                }
            } else {
                AuthView(authViewModel: authViewModel)
            }
        }
    }

    private var modalLayerContent: some View {
        primaryContent
        .loopedDismissKeyboardOnTap()
        .task {
            await fetchAppConfigAndEvaluateMinimumVersionPrompt()
        }
        .task(id: notificationPromptKey) {
            await evaluateNotificationPermissionPromptIfNeeded()
        }
        .task(id: profileCompletionPromptKey) {
            await evaluateProfileCompletionPromptIfNeeded()
        }
        .fullScreenCover(isPresented: $showProfileCompletionPrompt) {
            NavigationStack {
                FinishProfileSetupView()
            }
            .environmentObject(authViewModel)
            .environmentObject(feedViewModel)
            .preferredColorScheme(preferredColorScheme)
        }
        .fullScreenCover(isPresented: $showNotificationPermissionPrompt) {
            NotificationPermissionPromptView {
                dismissNotificationPermissionPrompt()
            }
        }
        .overlay {
            LoopedBottomDrawer(
                isPresented: showFirstPostCongrats,
                onDismiss: {
                    dismissFirstPostCongrats()
                }
            ) {
                FirstPostCongratsSheetView(
                    postId: firstPostCongratsPostId,
                    onDismiss: {
                        dismissFirstPostCongrats()
                    }
                )
            }
        }
        .overlay {
            GlobalShareDrawerHost()
        }
        .overlay {
            LoopedBottomDrawer(
                isPresented: presentedUserNotice != nil,
                onDismiss: {
                    guard let notice = presentedUserNotice,
                          noticeAllowsOverlayDismiss(notice),
                          inFlightUserNoticeAction == nil else { return }
                    handleNoticeAction(notice, action: .dismiss)
                },
                backgroundColor: .loopedBackground
            ) {
                if let notice = presentedUserNotice {
                    UserNoticeSheetView(
                        notice: notice,
                        inFlightAction: inFlightUserNoticeAction,
                        onAction: { action in
                            handleNoticeAction(notice, action: action)
                        }
                    )
                }
            }
        }
    }

    private var alertContent: some View {
        modalLayerContent
        .alert("Accounts Deleted", isPresented: $showAccountDeletedAlert) {
            Button("OK", role: .cancel) {
                showAccountDeletedAlert = false
            }
        } message: {
            Text("Your account and anonymous profile have been deleted.")
        }
        .alert("Account Deletion Requested", isPresented: $showAccountDeletionPendingAlert) {
            Button("OK", role: .cancel) {
                showAccountDeletionPendingAlert = false
            }
        } message: {
            Text("Your request was accepted and deletion is still processing in the background. If it is still pending after 24 hours, contact support at looped-social.com/contact.")
        }
        .alert("Account Deactivated", isPresented: $showAccountDeactivatedAlert) {
            Button("OK", role: .cancel) {
                showAccountDeactivatedAlert = false
            }
        } message: {
            Text("Your profile is hidden until you log back in.")
        }
        .alert("Connected Account Updated", isPresented: $showProviderDisconnectStatusAlert) {
            Button("OK", role: .cancel) {
                showProviderDisconnectStatusAlert = false
                providerDisconnectStatusMessage = ""
            }
        } message: {
            Text(providerDisconnectStatusMessage.isEmpty
                 ? "Connected account status changed. Please sign in again."
                 : providerDisconnectStatusMessage)
        }
        .alert("Update Recommended", isPresented: $showMinimumSupportedVersionPrompt) {
            Button("Not Now", role: .cancel) {
                recordMinimumSupportedVersionPromptDismissal()
            }
            if let minimumSupportedVersionUpdateUrl {
                Button("Update Now") {
                    recordMinimumSupportedVersionPromptDismissal()
                    openURL(minimumSupportedVersionUpdateUrl)
                }
            }
        } message: {
            Text(minimumSupportedVersionPromptMessage)
        }
    }

    private var configuredContent: some View {
        alertContent
        .environment(\.loopedPresentToast) { globalToastMessage = $0 }
        .toast($globalToastMessage)
        .environmentObject(authViewModel)
        .environmentObject(feedViewModel)
        .environment(\.preferCommunityShortNames, preferCommunityShortNames)
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            deepLinkRouter.setAuthenticationState(authViewModel.isAuthenticated)
            syncPresentedUserNotice()
            if !authViewModel.isAuthenticated {
                Task {
                    await spotlightIndexingService.removeAllPosts()
                }
            }
        }
        .onChange(of: authViewModel.isAuthenticated) { _, newValue in
            deepLinkRouter.setAuthenticationState(newValue)
            syncPresentedUserNotice()
            if !newValue {
                showProfileCompletionPrompt = false
                showFirstPostCongrats = false
                firstPostCongratsPostId = nil
                presentedUserNotice = nil
                inFlightUserNoticeAction = nil
                Task {
                    await spotlightIndexingService.removeAllPosts()
                }
            }
        }
        .onChange(of: authViewModel.didLoadIdentity) { _, _ in
            syncPresentedUserNotice()
        }
        .onChange(of: authViewModel.onboardingComplete) { _, _ in
            syncPresentedUserNotice()
        }
        .onChange(of: authViewModel.notices) { _, _ in
            syncPresentedUserNotice()
        }
        .onReceive(NotificationCenter.default.publisher(for: .firstPostEverMilestoneAwarded)) { notification in
            guard showFirstPostCongrats == false else { return }
            if let post = notification.object as? Post {
                firstPostCongratsPostId = post.backendId
            } else {
                firstPostCongratsPostId = nil
            }
            showFirstPostCongrats = true
        }
        .onChange(of: preferCommunityShortNames) { _, _ in
            Task { await feedViewModel.loadFollowedCommunities(reset: true) }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        AppearanceMode.from(rawValue: appearanceMode).colorScheme
    }

    private var notificationPromptKey: String {
        [
            authViewModel.isAuthenticated ? "auth" : "noauth",
            authViewModel.didLoadIdentity ? "id" : "noid",
            authViewModel.isIdentityRefreshInFlight ? "identityloading" : "identitystable",
            authViewModel.onboardingComplete ? "onboarded" : "notonboarded",
            authViewModel.shouldPromptProfileCompletion ? "profileprompt" : "noprofileprompt",
            showProfileCompletionPrompt ? "profilepromptshown" : "profileprompthidden",
            "lastprompt:\(Int(notificationPermissionPromptLastShownAt))",
            showNotificationPermissionPrompt ? "notifpromptshown" : "notifprompthidden"
        ].joined(separator: "|")
    }

    private var profileCompletionPromptKey: String {
        [
            authViewModel.isAuthenticated ? "auth" : "noauth",
            authViewModel.didLoadIdentity ? "id" : "noid",
            authViewModel.isIdentityRefreshInFlight ? "identityloading" : "identitystable",
            authViewModel.onboardingComplete ? "onboarded" : "notonboarded",
            authViewModel.shouldPromptProfileCompletion ? "shouldprompt" : "noshouldprompt"
        ].joined(separator: "|")
    }

    private func evaluateNotificationPermissionPromptIfNeeded() async {
        guard authViewModel.isAuthenticated else { return }
        guard authViewModel.didLoadIdentity else { return }
        guard !authViewModel.isIdentityRefreshInFlight else { return }
        guard authViewModel.onboardingComplete else { return }
        guard !authViewModel.shouldPromptProfileCompletion else { return }
        guard !showNotificationPermissionPrompt else { return }
        guard !showProfileCompletionPrompt else { return }

        #if canImport(UserNotifications)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined, .denied:
            let shouldPrompt = NotificationPermissionPromptPolicy.shouldPrompt(
                authorizationStatus: settings.authorizationStatus,
                lastPromptedAt: notificationPermissionPromptLastShownAt
            )
            guard shouldPrompt else { return }
            await MainActor.run {
                presentNotificationPermissionPrompt()
            }
        case .authorized, .provisional, .ephemeral:
            return
        @unknown default:
            return
        }
        #else
        return
        #endif
    }

    private func presentNotificationPermissionPrompt() {
        notificationPermissionPromptLastShownAt = Date().timeIntervalSince1970
        showNotificationPermissionPrompt = true
    }

    private func dismissNotificationPermissionPrompt() {
        showNotificationPermissionPrompt = false
    }

    private func dismissFirstPostCongrats() {
        guard showFirstPostCongrats else { return }
        let dismissedPostId = firstPostCongratsPostId
        showFirstPostCongrats = false
        firstPostCongratsPostId = nil
        Task {
            await TelemetryManager.shared.track(
                type: .milestoneFirstPostDismissed,
                postId: dismissedPostId,
                data: ["milestone_type": .string(FeedViewModel.firstPostEverMilestone)]
            )
        }
    }

    private func syncPresentedUserNotice() {
        guard authViewModel.isAuthenticated,
              authViewModel.didLoadIdentity,
              authViewModel.onboardingComplete else {
            presentedUserNotice = nil
            inFlightUserNoticeAction = nil
            return
        }

        if let current = presentedUserNotice,
           authViewModel.notices.contains(where: { $0.key == current.key }) {
            return
        }

        presentedUserNotice = authViewModel.notices.first
        inFlightUserNoticeAction = nil
    }

    private func handleNoticeAction(_ notice: UserNotice, action: UserNoticeAckAction) {
        guard inFlightUserNoticeAction == nil else { return }
        inFlightUserNoticeAction = action

        Task {
            let didAcknowledge = await authViewModel.acknowledgeNotice(notice, action: action)
            await MainActor.run {
                inFlightUserNoticeAction = nil
                if didAcknowledge {
                    syncPresentedUserNotice()
                } else {
                    globalToastMessage = ToastMessage(
                        text: "Couldn't update this message. Please try again.",
                        kind: .error
                    )
                }
            }
        }
    }

    private func noticeAllowsOverlayDismiss(_ notice: UserNotice) -> Bool {
        notice.dismissible && notice.key != Self.migrationNoticeKey
    }

    private func evaluateProfileCompletionPromptIfNeeded() async {
        guard authViewModel.isAuthenticated else {
            await MainActor.run {
                showProfileCompletionPrompt = false
            }
            return
        }
        guard authViewModel.didLoadIdentity else { return }
        guard !authViewModel.isIdentityRefreshInFlight else { return }
        guard authViewModel.onboardingComplete else {
            await MainActor.run {
                showProfileCompletionPrompt = false
            }
            return
        }
        await MainActor.run {
            let shouldShowProfileCompletionPrompt = authViewModel.shouldPromptProfileCompletion
            if shouldShowProfileCompletionPrompt {
                showNotificationPermissionPrompt = false
            }
            showProfileCompletionPrompt = shouldShowProfileCompletionPrompt
        }
    }

    private func fetchAppConfigAndEvaluateMinimumVersionPrompt() async {
        guard !uiTestBypassAuth else { return }
        do {
            let config = try await AppConfigService().fetch()
            applyDefaultProfileImageIfNeeded(from: config)
            evaluateMinimumSupportedVersionPrompt(from: config)
        } catch {
            // Best-effort; the UI will still fall back to local placeholders.
        }
    }

    private func applyDefaultProfileImageIfNeeded(from config: AppConfigDTO) {
        let now = Date().timeIntervalSince1970
        let refreshAfterSeconds = 24.0 * 60.0 * 60.0
        if now - defaultProfileImageUrlFetchedAt < refreshAfterSeconds, !defaultProfileImageUrl.isEmpty {
            return
        }

        defaultProfileImageUrl = (config.defaultProfileImageUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        defaultProfileImageUrlFetchedAt = now
    }

    private func evaluateMinimumSupportedVersionPrompt(from config: AppConfigDTO) {
        let minimumVersion = (config.minimumSupportedVersion ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !minimumVersion.isEmpty else { return }

        let currentVersion = AppVersionPolicy.currentAppVersion()
        guard AppVersionPolicy.shouldPromptForMinimumSupportedVersion(
            currentVersion: currentVersion,
            minimumSupportedVersion: minimumVersion
        ) else {
            return
        }

        guard shouldShowMinimumSupportedVersionPrompt(for: minimumVersion) else { return }

        minimumSupportedVersionPromptValue = minimumVersion
        minimumSupportedVersionPromptMessage = resolveMinimumSupportedVersionPromptMessage(
            from: config,
            minimumVersion: minimumVersion
        )
        minimumSupportedVersionUpdateUrl = resolveMinimumSupportedVersionUpdateUrl(from: config)
        showMinimumSupportedVersionPrompt = true
    }

    private func resolveMinimumSupportedVersionPromptMessage(from config: AppConfigDTO, minimumVersion: String) -> String {
        let backendMessage = (config.minimumSupportedVersionMessage ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !backendMessage.isEmpty {
            return backendMessage
        }

        return "Your Looped app version is below the minimum supported version (\(minimumVersion)). Please update to the latest version."
    }

    private func resolveMinimumSupportedVersionUpdateUrl(from config: AppConfigDTO) -> URL? {
        let backendUrl = (config.minimumSupportedVersionUpdateUrl ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !backendUrl.isEmpty,
           let url = URL(string: backendUrl),
           let scheme = url.scheme?.lowercased(),
           scheme == "https" || scheme == "itms-apps" {
            return url
        }
        return fallbackAppStoreUrl()
    }

    private func fallbackAppStoreUrl() -> URL? {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier,
              let encodedBundleIdentifier = bundleIdentifier.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return URL(string: "itms-apps://itunes.apple.com/app/bundle-id/\(encodedBundleIdentifier)")
    }

    private func shouldShowMinimumSupportedVersionPrompt(for minimumVersion: String) -> Bool {
        guard dismissedMinimumSupportedVersion == minimumVersion else { return true }
        let now = Date().timeIntervalSince1970
        let reminderInterval: TimeInterval = 24.0 * 60.0 * 60.0
        return now - dismissedMinimumSupportedVersionAt >= reminderInterval
    }

    private func recordMinimumSupportedVersionPromptDismissal() {
        dismissedMinimumSupportedVersion = minimumSupportedVersionPromptValue
        dismissedMinimumSupportedVersionAt = Date().timeIntervalSince1970
    }
}

private struct LaunchBootstrapView: View {
	    @Environment(\.accessibilityReduceMotion) private var reduceMotion
	    @State private var revealProgress: CGFloat = 0
	    @State private var didFinish = false
	    private static let baseLogoFrameDimension: CGFloat = 180
	    private static let launchScreenMatchScale: CGFloat = {
	        guard let launchLogo = UIImage(named: "LaunchLogo") else { return 1 }
	        guard let appLogo = UIImage(named: "logo") else { return 1 }

	        let launchAspect = launchLogo.size.width / max(launchLogo.size.height, 1)
	        let appAspect = appLogo.size.width / max(appLogo.size.height, 1)
	        guard launchAspect > 0, appAspect > 0 else { return 1 }

	        return appAspect / launchAspect
	    }()

	    let isReady: Bool
	    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.loopedBackground.ignoresSafeArea()

	            VStack(spacing: 18) {
	                animatedLogo
	                    .frame(width: logoFrameDimension, height: logoFrameDimension)
	                    .accessibilityHidden(true)
	            }
	            .padding(.horizontal, 24)
	        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
        .onAppear {
            didFinish = false

            if reduceMotion {
                revealProgress = isReady ? 1 : 0.9
                if isReady {
                    finishIfNeeded()
                }
                return
            }

            revealProgress = 0
            if isReady {
                withAnimation(.easeInOut(duration: 0.25)) {
                    revealProgress = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    finishIfNeeded()
                }
            } else {
                withAnimation(.easeOut(duration: 0.7)) {
                    revealProgress = 0.9
                }
            }
        }
        .onChange(of: isReady) { _, newValue in
            guard newValue else { return }
            if reduceMotion {
                revealProgress = 1
                finishIfNeeded()
                return
            }
            withAnimation(.easeInOut(duration: 0.25)) {
                revealProgress = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                finishIfNeeded()
            }
        }
    }

	    private var animatedLogo: some View {
	        ZStack {
	            Image("logo")
	                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(placeholderLogoColor)

            Image("logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.loopedPrimary)
                .mask(
                    GeometryReader { proxy in
                        Rectangle()
                            .frame(width: proxy.size.width * revealProgress, height: proxy.size.height)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }
                )
	        }
	        .compositingGroup()
	    }

	    private var logoFrameDimension: CGFloat {
	        Self.baseLogoFrameDimension * Self.launchScreenMatchScale
	    }

	    private var placeholderLogoColor: Color {
	        Color(.sRGB, red: 175.0 / 255.0, green: 162.0 / 255.0, blue: 162.0 / 255.0, opacity: 1)
	    }

    private func finishIfNeeded() {
        guard !didFinish else { return }
        didFinish = true
        onFinished()
    }
}

struct MainTabView: View {
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: TabItem = .home
    @State private var homePopToRootSignal = 0
    @State private var homePopToRootProcessedSignal = 0
    @State private var homeDidPopOnReselect = false
    @State private var feedScrollToTopSignal = 0
    @State private var showCreatePost = false
    @State private var createPostPrefillText: String?
    @State private var showNewMessage = false
    @State private var isRightMenuOpen = false
	    @State private var showingChat = false
	    @State private var selectedConversation: Conversation?
	    @State private var selectedChannel: Channel?
	    @State private var deepLinkConversationId: Int?
	    @State private var deepLinkChannelId: Int?
	    @State private var menuDestination: MenuDestination?
	    @State private var mainOverlayDestination: LoopedMainOverlayDestination?
	    @State private var tabBarHeight: CGFloat = 0
	    @State private var showFAQSheet = false
	    @State private var deepLinkProfile: DeepLinkProfile?
    @State private var deepLinkUnavailable: DeepLinkUnavailableState?
    @State private var isDeepLinkLoading = false
    @StateObject private var commentsManager = CommentsModalManager()
    @StateObject private var fabState = FloatingActionButtonState()
    @StateObject private var coachMarkPresenter = CoachMarkPresenter()
    @StateObject private var notificationsViewModel = NotificationsViewModel()
    @StateObject private var messagesViewModel = MessagesViewModel()
    @State private var isTabBarVisible = true
    @AppStorage("anonymousMode") private var isAnonymousMode = false
    @AppStorage("lastSeenNotificationsAt") private var lastSeenNotificationsAt = 0.0
    @AppStorage("lastSeenMessagesAt") private var lastSeenMessagesAt = 0.0
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("didShowFeedDiscovery") private var didShowFeedDiscovery = false
    @AppStorage("didShowFeedSearchDiscovery") private var didShowFeedSearchDiscovery = false
    @State private var feedDiscoveryStep: FeedDiscoveryStep?
    @AppStorage("didShowSearchPageDiscovery") private var didShowSearchPageDiscovery = false
    @AppStorage("searchPageUnverifiedHintLastShownAt") private var searchPageUnverifiedHintLastShownAt = 0.0
    @State private var isShowingSearchPageDiscovery = false
    @AppStorage("unverifiedSearchDiscoveryLastShownAt") private var unverifiedSearchDiscoveryLastShownAt = 0.0
    @AppStorage("unverifiedSearchDiscoveryParity") private var unverifiedSearchDiscoveryParity = 0
    @State private var isShowingUnverifiedSearchDiscovery = false
    @State private var didEvaluateUnverifiedSearchDiscoveryThisSession = false
    @State private var toastMessage: ToastMessage?
    private var uiTestDisableNetworkBootstrap: Bool {
        ProcessInfo.processInfo.environment["LOOPED_UI_TEST_DISABLE_NETWORK"] == "1"
    }
    private let faqUrl = URL(string: "https://looped-social.com/faq")!
    private let deepLinkFeedService: FeedServiceProtocol = FeedService()
    private let deepLinkUserService: UserServiceProtocol = UserService()
    private let widgetSummaryService: WidgetSummaryServiceProtocol = WidgetSummaryService()
    
    var body: some View {
        GeometryReader { geometry in
            mainLayout(for: geometry)
        }
        .environment(\.floatingActionButtonState, fabState)
        .task {
            guard !uiTestDisableNetworkBootstrap else { return }
            presentPendingSharedPostIfNeeded()
            didEvaluateUnverifiedSearchDiscoveryThisSession = false
            async let loadCommunities: Void = feedViewModel.loadFollowedCommunities()
            async let loadNotifications: Void = notificationsViewModel.loadNotifications()
            if !isAnonymousMode {
                async let loadInbox: Void = messagesViewModel.loadInbox()
                _ = await (loadCommunities, loadNotifications, loadInbox)
            } else {
                _ = await (loadCommunities, loadNotifications)
            }
            startFeedDiscoveryIfNeeded()
            startUnverifiedSearchDiscoveryIfNeeded()
            startSearchPageDiscoveryIfNeeded()
            await widgetSummaryService.refreshSharedSnapshot()
            syncWidgetSnapshot()
        }
        .onAppear {
            presentPendingSharedPostIfNeeded()
            startFeedDiscoveryIfNeeded()
            startUnverifiedSearchDiscoveryIfNeeded()
            startSearchPageDiscoveryIfNeeded()
        }
        .onChange(of: selectedTab) { _, _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isTabBarVisible = true
            }
            updateLastSeen(for: selectedTab)
            startFeedDiscoveryIfNeeded()
            startUnverifiedSearchDiscoveryIfNeeded()
            startSearchPageDiscoveryIfNeeded()
            syncFloatingActionButtonVisibility()
            if selectedTab == .home {
                VideoPlaybackManager.shared.requestVisibilityRefresh()
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    VideoPlaybackManager.shared.requestVisibilityRefresh()
                }
            } else {
                VideoPlaybackManager.shared.resetVisibility()
            }
        }
        .onChange(of: homePopToRootProcessedSignal) { _, _ in
            guard selectedTab == .home else { return }
            guard homePopToRootProcessedSignal == homePopToRootSignal else { return }
            guard homeDidPopOnReselect == false else { return }
            feedScrollToTopSignal += 1
        }
        .onChange(of: isRightMenuOpen) { _, _ in
            startFeedDiscoveryIfNeeded()
            startUnverifiedSearchDiscoveryIfNeeded()
            startSearchPageDiscoveryIfNeeded()
        }
        .onChange(of: commentsManager.isPresented) { _, _ in
            startFeedDiscoveryIfNeeded()
            startUnverifiedSearchDiscoveryIfNeeded()
            startSearchPageDiscoveryIfNeeded()
        }
        .onChange(of: showingChat) { _, _ in
            startFeedDiscoveryIfNeeded()
            startUnverifiedSearchDiscoveryIfNeeded()
            startSearchPageDiscoveryIfNeeded()
        }
        .onReceive(notificationsViewModel.$notifications) { _ in
            guard selectedTab == .notifications else { return }
            lastSeenNotificationsAt = Date().timeIntervalSince1970
        }
        .onReceive(messagesViewModel.$conversations) { _ in
            guard selectedTab == .messages else { return }
            lastSeenMessagesAt = Date().timeIntervalSince1970
        }
        .onReceive(messagesViewModel.$messageRequests) { _ in
            guard selectedTab == .messages else { return }
            lastSeenMessagesAt = Date().timeIntervalSince1970
        }
        .onReceive(messagesViewModel.$conversations) { _ in
            syncWidgetSnapshot()
        }
        .onReceive(messagesViewModel.$messageRequests) { _ in
            syncWidgetSnapshot()
        }
        .onReceive(notificationsViewModel.$notifications) { _ in
            syncWidgetSnapshot()
        }
        .onReceive(feedViewModel.$followedCommunities) { _ in
            syncWidgetSnapshot()
        }
        .onReceive(feedViewModel.$selectedCommunity) { community in
            syncWidgetSnapshot()
            if let communityId = community?.id {
                Task {
                    await AppOpenReporter.shared.markCommunitySeen(communityId)
                }
            }
        }
        .onReceive(feedViewModel.$posts) { _ in
            syncWidgetSnapshot()
        }
        .onChange(of: isAnonymousMode) { _, _ in
            syncWidgetSnapshot()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            authViewModel.appDidBecomeActive()
            presentPendingSharedPostIfNeeded()
            Task {
                await widgetSummaryService.refreshSharedSnapshot()
                syncWidgetSnapshot()
                await AppOpenReporter.shared.reportIfNeeded(
                    isAuthenticated: authViewModel.isAuthenticated,
                    activeCommunityId: feedViewModel.selectedCommunity?.id
                )
            }
        }
        .onReceive(authViewModel.$isAuthenticated.removeDuplicates()) { isAuthenticated in
            guard isAuthenticated else { return }
            guard scenePhase == .active else { return }
            presentPendingSharedPostIfNeeded()
            Task {
                await AppOpenReporter.shared.reportIfNeeded(
                    isAuthenticated: true,
                    activeCommunityId: feedViewModel.selectedCommunity?.id
                )
            }
        }
        .environmentObject(feedViewModel)
        .environmentObject(commentsManager)
        .environment(\.loopedPresentToast) { toastMessage = $0 }
        .toast($toastMessage)
		        .overlay(
		            Group {
		                if commentsManager.isPresented, let post = commentsManager.currentPost {
	                    CommentsNavigationHost(post: post) {
	                        commentsManager.dismissComments()
	                    }
	                    .environmentObject(commentsManager)
	                    .preferredColorScheme(preferredColorScheme)
	                    .transition(.move(edge: .trailing))
	                }
	            }
	        )
	        .overlay(
	            Group {
	                if let destination = mainOverlayDestination {
	                    LoopedMainOverlayNavigationHost(destination: destination) {
	                        withAnimation(.easeInOut(duration: 0.25)) {
	                            mainOverlayDestination = nil
	                        }
	                    }
	                    .preferredColorScheme(preferredColorScheme)
	                    .transition(.move(edge: .trailing))
	                }
	            }
	        )
        .sheet(isPresented: $showCreatePost, onDismiss: {
            createPostPrefillText = nil
        }) {
            CreatePostView(
                feedViewModel: feedViewModel,
                prefillText: createPostPrefillText,
                onPostCreated: {
                    showCreatePost = false
                },
                onPostStatus: { message in
                    toastMessage = message
                }
            )
                .onAppear {
                    if createPostPrefillText != nil {
                        SharedPostPrefillStore.clearPending()
                    }
                }
                .preferredColorScheme(preferredColorScheme)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showNewMessage) {
            NewMessageView(onChatSelected: { conversation, channel in
                // Dismiss the sheet first
                showNewMessage = false

                // Small delay to let sheet dismiss before showing chat
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedConversation = conversation
                        selectedChannel = channel
                        showingChat = true
                    }
                }
            })
            .preferredColorScheme(preferredColorScheme)
        }
        .fullScreenCover(item: $menuDestination) { destination in
            switch destination {
            case .settings:
                SettingsModalHost()
                    .environmentObject(authViewModel)
                    .environmentObject(feedViewModel)
                    .environmentObject(commentsManager)
                    .environment(\.floatingActionButtonState, fabState)
                    .preferredColorScheme(preferredColorScheme)
            default:
                NavigationStack {
                    destinationView(for: destination)
                }
                .environmentObject(authViewModel)
                .environmentObject(feedViewModel)
                .environmentObject(commentsManager)
                .environment(\.floatingActionButtonState, fabState)
                .preferredColorScheme(preferredColorScheme)
            }
        }
        .sheet(isPresented: $showFAQSheet) {
            SafariView(url: faqUrl)
                .ignoresSafeArea()
        }
        .fullScreenCover(item: $deepLinkProfile) { profile in
            NavigationStack {
                if profile.isAnonymous {
                    UserProfileView(anonProfileId: profile.profileId)
                } else {
                    UserProfileView(userId: profile.profileId)
                }
            }
            .environmentObject(authViewModel)
            .environmentObject(feedViewModel)
            .environmentObject(commentsManager)
            .environment(\.floatingActionButtonState, fabState)
            .preferredColorScheme(preferredColorScheme)
        }
        .fullScreenCover(item: $deepLinkUnavailable) { unavailable in
            DeepLinkUnavailableView(unavailable: unavailable) {
                deepLinkUnavailable = nil
            } onOpenHome: {
                selectedTab = .home
                deepLinkUnavailable = nil
            }
            .preferredColorScheme(preferredColorScheme)
        }
        .onReceive(deepLinkRouter.$pendingNavigation.compactMap { $0 }) { request in
            handleDeepLinkRequest(request)
        }
        .overlay {
            if isDeepLinkLoading {
                DeepLinkLoadingOverlay()
            }
        }
    }

    private func mainLayout(for geometry: GeometryProxy) -> some View {
        let safeWidth = max(geometry.size.width, 0)
        let drawerWidth = safeWidth * 0.8

        return ZStack(alignment: .leading) {
            rightMenu(drawerWidth: drawerWidth)
            mainContent(drawerWidth: drawerWidth)
            floatingActionButton
            chatOverlay
        }
        .environmentObject(coachMarkPresenter)
        .overlayPreferenceValue(CoachMarkTargetKey.self) { targets in
            ZStack {
                feedDiscoveryOverlay(targets: targets)
                unverifiedSearchDiscoveryOverlay(targets: targets)
                searchPageDiscoveryOverlay(targets: targets)
                presentedCoachMarkOverlay(targets: targets)
            }
        }
    }

    @ViewBuilder
    private func presentedCoachMarkOverlay(targets: [CoachMarkTarget: Anchor<CGRect>]) -> some View {
        if feedDiscoveryStep == nil,
           let overlay = coachMarkPresenter.overlay,
           targets[overlay.target] != nil {
            CoachMarkOverlay(
                target: overlay.target,
                targets: targets,
                message: overlay.message,
                primaryTitle: overlay.primaryTitle,
                secondaryTitle: overlay.secondaryTitle,
                onPrimary: overlay.onPrimary,
                onSecondary: overlay.onSecondary
            )
        }
    }

    @ViewBuilder
    private func rightMenu(drawerWidth: CGFloat) -> some View {
        if selectedTab == .home {
            HStack(spacing: 0) {
                Spacer()

                // Menu content constrained to 80% width with full background
                MenuContent(onMenuItemTap: { destination in
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isRightMenuOpen = false
                    }
                    // Small delay to let drawer close before navigation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if destination == .faq {
                            showFAQSheet = true
                        } else {
                            menuDestination = destination
                        }
                    }
                })
                .frame(width: drawerWidth)
                .background(Color.loopedBackground.ignoresSafeArea(.all))
                .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.loopedBackground.ignoresSafeArea(.all))
            .offset(x: isRightMenuOpen ? 0 : drawerWidth)
            .allowsHitTesting(isRightMenuOpen)
        }
    }

    @ViewBuilder
		    private func mainContent(drawerWidth: CGFloat) -> some View {
		        tabContent
		            .frame(maxWidth: .infinity, maxHeight: .infinity)
		            .safeAreaInset(edge: .bottom, spacing: 0) {
		                if isTabBarVisible {
		                    CustomTabBar(
		                        selectedTab: $selectedTab,
		                        showsUpdateDot: { tab in shouldShowUpdateDot(for: tab) },
                                onReselect: handleTabReselect
	                    )
		                        .transition(.move(edge: .bottom).combined(with: .opacity))
	                }
	            }
	                .onPreferenceChange(LoopedTabBarHeightPreferenceKey.self) { newValue in
	                    if newValue > 0, abs(newValue - tabBarHeight) > 0.5 {
	                        tabBarHeight = newValue
	                    } else if newValue == 0 {
	                        tabBarHeight = 0
	                    }
	                }
	                .environment(\.loopedTabBarHeight, isTabBarVisible ? tabBarHeight : 0)
	                .environment(\.loopedIsTabBarVisible, isTabBarVisible)
	                .environment(\.loopedSetTabBarVisible) { visible in
	                    withAnimation(.easeInOut(duration: 0.25)) {
	                        isTabBarVisible = visible
	                    }
	                }
	                .environment(\.loopedPresentMainOverlay) { destination in
	                    withAnimation(.easeInOut(duration: 0.25)) {
	                        mainOverlayDestination = destination
	                    }
	                }
		            .animation(.easeInOut(duration: 0.25), value: isTabBarVisible)
	        .background(Color.loopedBackground.ignoresSafeArea())
	        .overlay(
            // Blocking overlay when drawer is open - prevents feed interactions
            Group {
                if selectedTab == .home && isRightMenuOpen {
                    Color.loopedClear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                isRightMenuOpen = false
                            }
                        }
                        .allowsHitTesting(true)
                }
            }
        )
        .offset(x: selectedTab == .home ? (isRightMenuOpen ? -drawerWidth : 0) : 0)
        .scaleEffect((selectedTab == .home && isRightMenuOpen) ? 0.95 : 1.0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isRightMenuOpen)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            NavigationStack {
                FeedView(
                    isTabBarVisible: $isTabBarVisible,
                    scrollToTopSignal: $feedScrollToTopSignal,
                    onProfileTap: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isRightMenuOpen.toggle()
                        }
                    }
                )
                .environmentObject(feedViewModel)
                .environmentObject(commentsManager)
                .background(
                    NavigationPopToRootHandler(
                        popToRootSignal: $homePopToRootSignal,
                        lastProcessedSignal: $homePopToRootProcessedSignal,
                        didPopOnLastSignal: $homeDidPopOnReselect
                    )
                )
            }
        case .messages:
            NavigationStack {
                MessagesView(
                    viewModel: messagesViewModel,
                    onChatSelected: { conversation, channel in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedConversation = conversation
                            selectedChannel = channel
                            showingChat = true
                        }
                    }
                )
            }
        case .search:
            SearchView()
        case .notifications:
            NavigationStack {
                NotificationsView(viewModel: notificationsViewModel)
            }
        case .profile:
            NavigationStack {
                ProfileView()
            }
        }
    }

    private func handleTabReselect(_ tab: TabItem) {
        guard tab == .home else { return }

        if isRightMenuOpen {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isRightMenuOpen = false
            }
        }

        homePopToRootSignal += 1
    }

    private func shouldShowUpdateDot(for tab: TabItem) -> Bool {
        switch tab {
        case .messages:
            guard !isAnonymousMode else { return false }
            guard selectedTab != .messages else { return false }
            let lastSeen = Date(timeIntervalSince1970: lastSeenMessagesAt)
            let hasNewUnreadConversation = messagesViewModel.conversations.contains { conversation in
                conversation.hasUnreadMessages && conversation.lastMessageTimestamp > lastSeen
            }
            let hasPendingRequest = !messagesViewModel.messageRequests.isEmpty
            return hasNewUnreadConversation || hasPendingRequest
        case .notifications:
            guard selectedTab != .notifications else { return false }
            let lastSeen = Date(timeIntervalSince1970: lastSeenNotificationsAt)
            return notificationsViewModel.notifications.contains { notification in
                !notification.isRead && notification.createdAt > lastSeen
            }
        default:
            return false
        }
    }

    private func updateLastSeen(for tab: TabItem) {
        let now = Date().timeIntervalSince1970
        switch tab {
        case .messages:
            lastSeenMessagesAt = now
        case .notifications:
            lastSeenNotificationsAt = now
        default:
            break
        }
    }

    private func syncWidgetSnapshot() {
        let unreadMessages: Int
        let pendingRequests: Int
        if isAnonymousMode {
            unreadMessages = 0
            pendingRequests = 0
        } else {
            unreadMessages = messagesViewModel.conversations.reduce(0) { partialResult, conversation in
                partialResult + max(0, conversation.unreadCount)
            }
            pendingRequests = messagesViewModel.messageRequests.count
        }

        let unreadMentions = notificationsViewModel.notifications.reduce(0) { partialResult, notification in
            guard !notification.isRead, notification.type == .mention else { return partialResult }
            return partialResult + 1
        }

        let verifiedCommunities = feedViewModel.followedCommunities.filter(\.canPost)
        WidgetSnapshotStore.save(
            unreadMessageCount: unreadMessages,
            messageRequestCount: pendingRequests,
            unreadMentionCount: unreadMentions,
            verifiedCommunities: verifiedCommunities,
            selectedCommunityId: feedViewModel.selectedCommunity?.id,
            recentChats: makeWidgetRecentChats()
        )
    }

    private func makeWidgetRecentChats() -> [WidgetSnapshot.RecentChat]? {
        guard !isAnonymousMode else { return nil }
        let recent = messagesViewModel.conversations
            .sorted { $0.lastMessageTimestamp > $1.lastMessageTimestamp }
            .prefix(3)
        guard !recent.isEmpty else { return nil }

        return recent.map { conversation in
            let name = conversation.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            let preview = conversation.lastMessagePreview.trimmingCharacters(in: .whitespacesAndNewlines)
            let avatar = conversation.userProfileImageUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
            return .init(
                conversationId: max(0, conversation.backendId),
                title: name.isEmpty ? "Chat" : name,
                avatarThumbnailUrl: (avatar?.isEmpty == false) ? avatar : nil,
                lastMessagePreview: preview.isEmpty ? "Open chat to continue." : preview,
                unreadCount: max(0, conversation.unreadCount)
            )
        }
    }

    private func syncFloatingActionButtonVisibility() {
        switch selectedTab {
        case .home, .messages, .profile:
            fabState.isHidden = false
        default:
            fabState.isHidden = true
        }
    }

    @ViewBuilder
    private var floatingActionButton: some View {
        if (selectedTab == .home || selectedTab == .messages || selectedTab == .profile)
            && !commentsManager.isPresented
            && (selectedTab != .home || !isRightMenuOpen)
            && !fabState.isHidden {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Group {
                        if selectedTab == .messages {
                            FloatingActionButton(type: .sendMessage) {
                                showNewMessage = true
                            }
                        } else {
                            FloatingActionButton(type: .addPost) {
                                createPostPrefillText = SharedPostPrefillStore.loadComposedText()
                                showCreatePost = true
                            }
                            .coachMarkTarget(.feedPostButton)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, isTabBarVisible ? 60 : 16)
                    .animation(.easeInOut(duration: 0.25), value: isTabBarVisible)
                }
            }
        }
    }

    @ViewBuilder
    private var chatOverlay: some View {
        if showingChat {
            ChatNavigationHost(
                conversation: selectedConversation,
                channel: selectedChannel,
                conversationId: deepLinkConversationId,
                channelId: deepLinkChannelId
            ) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingChat = false
                    selectedConversation = nil
                    selectedChannel = nil
                    deepLinkConversationId = nil
                    deepLinkChannelId = nil
                }
            }
            .transition(.move(edge: .trailing))
        }
    }

    @ViewBuilder
    private func feedDiscoveryOverlay(targets: [CoachMarkTarget: Anchor<CGRect>]) -> some View {
        if let step = feedDiscoveryStep,
           selectedTab == .home,
           !isRightMenuOpen,
           !commentsManager.isPresented,
           !showingChat,
           !fabState.isHidden,
           targets[step.target] != nil {
            CoachMarkOverlay(
                target: step.target,
                targets: targets,
                message: step.message,
                primaryTitle: step.primaryTitle,
                secondaryTitle: step.secondaryTitle,
                onPrimary: advanceFeedDiscovery,
                onSecondary: skipFeedDiscovery
            )
        }
    }

    @ViewBuilder
    private func unverifiedSearchDiscoveryOverlay(targets: [CoachMarkTarget: Anchor<CGRect>]) -> some View {
        if isShowingUnverifiedSearchDiscovery,
           selectedTab == .home,
           isTabBarVisible,
           !isRightMenuOpen,
           !commentsManager.isPresented,
           !showingChat,
           feedDiscoveryStep == nil,
           coachMarkPresenter.overlay == nil,
           targets[.mainTabSearch] != nil {
            CoachMarkOverlay(
                target: .mainTabSearch,
                targets: targets,
                message: "Search for the community you want to verify in. You can verify from the community page.",
                primaryTitle: "Got it",
                secondaryTitle: nil,
                onPrimary: dismissUnverifiedSearchDiscovery,
                onSecondary: nil
            )
        }
    }

    @ViewBuilder
    private func searchPageDiscoveryOverlay(targets: [CoachMarkTarget: Anchor<CGRect>]) -> some View {
        if isShowingSearchPageDiscovery,
           selectedTab == .search,
           !commentsManager.isPresented,
           !showingChat,
           !isRightMenuOpen,
           feedDiscoveryStep == nil,
           coachMarkPresenter.overlay == nil,
           targets[.searchPageSearchBar] != nil {
            CoachMarkOverlay(
                target: .searchPageSearchBar,
                targets: targets,
                message: "Search for a community to get verified.",
                primaryTitle: "Got it",
                secondaryTitle: nil,
                onPrimary: dismissSearchPageDiscovery,
                onSecondary: nil
            )
        }
    }

    @ViewBuilder
    private func destinationView(for destination: MenuDestination) -> some View {
        MenuDestinationView(destination: destination)
    }
    
    private var preferredColorScheme: ColorScheme? {
        AppearanceMode.from(rawValue: appearanceMode).colorScheme
    }

    private func startFeedDiscoveryIfNeeded() {
        guard isVerifiedInAnyCommunity else { return }
        guard selectedTab == .home else { return }
        guard !isRightMenuOpen, !commentsManager.isPresented, !showingChat else { return }
        guard feedDiscoveryStep == nil else { return }
        guard !isShowingUnverifiedSearchDiscovery else { return }

        if didShowFeedDiscovery {
            guard !didShowFeedSearchDiscovery else { return }
            DispatchQueue.main.async {
                guard feedDiscoveryStep == nil else { return }
                feedDiscoveryStep = .search
            }
            return
        }

        DispatchQueue.main.async {
            guard feedDiscoveryStep == nil else { return }
            feedDiscoveryStep = .postButton
        }
    }

    private func startUnverifiedSearchDiscoveryIfNeeded() {
        guard !isVerifiedInAnyCommunity else {
            isShowingUnverifiedSearchDiscovery = false
            return
        }
        guard !isShowingUnverifiedSearchDiscovery else { return }
        guard selectedTab == .home else { return }
        guard isTabBarVisible else { return }
        guard !isRightMenuOpen, !commentsManager.isPresented, !showingChat else { return }
        guard feedDiscoveryStep == nil else { return }
        guard coachMarkPresenter.overlay == nil else { return }
        guard !didEvaluateUnverifiedSearchDiscoveryThisSession else { return }

        let now = Date().timeIntervalSince1970
        let minInterval: TimeInterval = 18 * 60 * 60
        if unverifiedSearchDiscoveryLastShownAt > 0,
           now - unverifiedSearchDiscoveryLastShownAt < minInterval {
            return
        }

        didEvaluateUnverifiedSearchDiscoveryThisSession = true
        unverifiedSearchDiscoveryParity += 1
        guard unverifiedSearchDiscoveryParity % 2 == 1 else { return }

        unverifiedSearchDiscoveryLastShownAt = now
        isShowingUnverifiedSearchDiscovery = true
    }

    private func dismissUnverifiedSearchDiscovery() {
        isShowingUnverifiedSearchDiscovery = false
    }

    private func startSearchPageDiscoveryIfNeeded() {
        guard selectedTab == .search else {
            isShowingSearchPageDiscovery = false
            return
        }
        guard !isShowingSearchPageDiscovery else { return }
        guard !commentsManager.isPresented, !showingChat, !isRightMenuOpen else { return }
        guard feedDiscoveryStep == nil else { return }
        guard coachMarkPresenter.overlay == nil else { return }

        if isVerifiedInAnyCommunity {
            guard !didShowSearchPageDiscovery else { return }
            DispatchQueue.main.async {
                guard selectedTab == .search else { return }
                isShowingSearchPageDiscovery = true
            }
            return
        }

        let now = Date().timeIntervalSince1970
        let minInterval: TimeInterval = 18 * 60 * 60
        let shouldShowBecauseNeverSeen = !didShowSearchPageDiscovery
        let shouldShowBecauseIntervalElapsed =
            searchPageUnverifiedHintLastShownAt <= 0
            || now - searchPageUnverifiedHintLastShownAt >= minInterval
        guard shouldShowBecauseNeverSeen || shouldShowBecauseIntervalElapsed else { return }

        DispatchQueue.main.async {
            guard selectedTab == .search else { return }
            if !isVerifiedInAnyCommunity {
                searchPageUnverifiedHintLastShownAt = now
            }
            isShowingSearchPageDiscovery = true
        }
    }

    private func dismissSearchPageDiscovery() {
        didShowSearchPageDiscovery = true
        if !isVerifiedInAnyCommunity {
            searchPageUnverifiedHintLastShownAt = Date().timeIntervalSince1970
        }
        isShowingSearchPageDiscovery = false
    }

    private func advanceFeedDiscovery() {
        guard let step = feedDiscoveryStep else { return }
        if let next = FeedDiscoveryStep(rawValue: step.rawValue + 1) {
            feedDiscoveryStep = next
        } else {
            didShowFeedDiscovery = true
            if step == .search {
                didShowFeedSearchDiscovery = true
            }
            feedDiscoveryStep = nil
        }
    }

    private func skipFeedDiscovery() {
        didShowFeedSearchDiscovery = true
        didShowFeedDiscovery = true
        feedDiscoveryStep = nil
    }

    private var isVerifiedInAnyCommunity: Bool {
        feedViewModel.followedCommunities.contains(where: { $0.canPost })
    }

    private func handleDeepLinkRequest(_ request: DeepLinkNavigationRequest) {
        defer { deepLinkRouter.consumeNavigation(request) }

        switch request.destination {
        case .messages:
            if isAnonymousMode {
                selectedTab = .home
                toastMessage = ToastMessage(text: "Messages aren't available in anonymous mode.", kind: .info)
            } else {
                selectedTab = .messages
            }
        case .search:
            selectedTab = .search
        case .profileTab:
            selectedTab = .profile
        case .createPost:
            selectedTab = .home
            createPostPrefillText = SharedPostPrefillStore.loadComposedText()
            showCreatePost = true
        case .community(let communityId):
            openCommunity(communityId: communityId)
        case .post(let postId):
            Task {
                await openPost(postId: postId, focusCommentId: nil, request: request)
            }
        case .profileSlug(let slug):
            Task {
                await openProfile(slug: slug, request: request)
            }
        case .comment(let commentId, let postId):
            if let postId {
                Task {
                    await openPost(postId: postId, focusCommentId: commentId, request: request)
                }
            } else {
                selectedTab = .notifications
            }
        case .user(let userId, let isAnonymous):
            deepLinkProfile = DeepLinkProfile(profileId: userId, isAnonymous: isAnonymous)
        case .announcement:
            selectedTab = .notifications
        case .conversation(let conversationId):
            Task {
                await openConversationFromDeepLink(conversationId)
            }
        case .channel(let channelId):
            openChat(conversationId: nil, channelId: channelId)
        case .home:
            selectedTab = .home
            if request.pathType != .home && request.pathType != .unsupported {
                toastMessage = ToastMessage(text: "That link isn't available.", kind: .warning)
            }
        }
    }

    private func presentPendingSharedPostIfNeeded() {
        guard authViewModel.isAuthenticated else { return }
        guard !showCreatePost else { return }
        guard let prefill = SharedPostPrefillStore.loadComposedText() else { return }
        selectedTab = .home
        createPostPrefillText = prefill
        showCreatePost = true
    }

    private func openCommunity(communityId: Int) {
        selectedTab = .home
        Task {
            if let existing = feedViewModel.followedCommunities.first(where: { $0.id == communityId }) {
                await feedViewModel.selectCommunity(existing)
                await widgetSummaryService.markCommunitySeen(communityId: communityId)
                return
            }

            await feedViewModel.loadFollowedCommunities(reset: true)
            if let loaded = feedViewModel.followedCommunities.first(where: { $0.id == communityId }) {
                await feedViewModel.selectCommunity(loaded)
                await widgetSummaryService.markCommunitySeen(communityId: communityId)
            } else {
                toastMessage = ToastMessage(text: "That community is unavailable right now.", kind: .warning)
            }
        }
    }

    private func openChat(conversationId: Int?, channelId: Int?) {
        selectedTab = .messages
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedConversation = nil
            selectedChannel = nil
            deepLinkConversationId = conversationId
            deepLinkChannelId = channelId
            showingChat = true
        }
    }

    private func openChat(conversation: Conversation) {
        selectedTab = .messages
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedConversation = conversation
            selectedChannel = nil
            deepLinkConversationId = nil
            deepLinkChannelId = nil
            showingChat = true
        }
    }

    @MainActor
    private func openConversationFromDeepLink(_ conversationId: Int) async {
        guard conversationId > 0 else {
            selectedTab = .messages
            toastMessage = ToastMessage(text: "That chat is unavailable right now.", kind: .warning)
            return
        }

        if let existing = messagesViewModel.conversations.first(where: { $0.backendId == conversationId }) {
            openChat(conversation: existing)
            return
        }

        await messagesViewModel.loadConversations()
        if let loaded = messagesViewModel.conversations.first(where: { $0.backendId == conversationId }) {
            openChat(conversation: loaded)
        } else {
            // Fallback: still open chat by id so direct-load path can attempt message fetch.
            openChat(conversationId: conversationId, channelId: nil)
        }
    }

    private func openPost(postId: Int, focusCommentId: Int?, request: DeepLinkNavigationRequest) async {
        await MainActor.run {
            isDeepLinkLoading = true
        }
        defer {
            Task { @MainActor in
                isDeepLinkLoading = false
            }
        }

        do {
            let post = try await deepLinkFeedService.fetchPost(postId: postId)
            await MainActor.run {
                selectedTab = .home
                commentsManager.showComments(
                    for: post,
                    focusCommentId: focusCommentId,
                    telemetryEntryPoint: telemetryEntryPoint(for: request)
                )
            }
        } catch {
            let reason = deepLinkFailureReason(from: error)
            await MainActor.run {
                deepLinkRouter.reportNavigationFailure(for: request, reason: reason)
                if let fallbackURL = request.fallbackURL {
                    // Used for push routing (ex: trending_today) when the target post is unavailable.
                    _ = deepLinkRouter.handleIncomingURL(fallbackURL)
                } else {
                    deepLinkUnavailable = DeepLinkUnavailableState(
                        title: "Post unavailable",
                        message: "This post may have been removed or is no longer available."
                    )
                }
            }
        }
    }

    private func telemetryEntryPoint(for request: DeepLinkNavigationRequest) -> String {
        switch request.pathType {
        case .comment:
            return "deep_link_comment"
        case .post:
            return "deep_link_post"
        default:
            return "deep_link"
        }
    }

    private func openProfile(slug: String, request: DeepLinkNavigationRequest) async {
        await MainActor.run {
            isDeepLinkLoading = true
        }
        defer {
            Task { @MainActor in
                isDeepLinkLoading = false
            }
        }

        do {
            let userId = try await deepLinkUserService.resolveUserId(fromSlug: slug)
            await MainActor.run {
                deepLinkProfile = DeepLinkProfile(profileId: userId, isAnonymous: false)
            }
        } catch {
            let reason = deepLinkFailureReason(from: error)
            await MainActor.run {
                deepLinkRouter.reportNavigationFailure(for: request, reason: reason)
                deepLinkUnavailable = DeepLinkUnavailableState(
                    title: "Profile unavailable",
                    message: "This profile may have been removed or is no longer available."
                )
            }
        }
    }

    private func deepLinkFailureReason(from error: Error) -> DeepLinkFailureReason {
        if error is URLError {
            return .networkError
        }

        guard let apiError = error as? APIError else {
            return .unavailable
        }

        switch apiError {
        case .unauthorized:
            return .unauthorized
        case .networkError:
            return .networkError
        case .apiError(let code, let apiCode, _):
            if code == 401 || code == 403 || apiCode == "unauthorized" || apiCode == "forbidden" {
                return .unauthorized
            }
            if code == 404 || apiCode == "not_found" || apiCode.hasSuffix("_not_found") {
                return .notFound
            }
            if code == 410 || apiCode.contains("unavailable") || apiCode.contains("removed") {
                return .unavailable
            }
            if code >= 500 {
                return .networkError
            }
            return .unavailable
        case .rateLimited:
            return .networkError
        case .serverError(let code):
            return code >= 500 ? .networkError : .unavailable
        case .invalidResponse, .decodingError:
            return .unavailable
        }
    }

    private struct DeepLinkProfile: Identifiable {
        let profileId: Int
        let isAnonymous: Bool

        var id: String {
            "\(profileId)-\(isAnonymous ? "anon" : "user")"
        }
    }

    private struct DeepLinkUnavailableState: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private struct DeepLinkLoadingOverlay: View {
        var body: some View {
            ZStack {
                Color.loopedBlack.opacity(0.22)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Opening link...")
                        .font(.loopedSubBodyMedium)
                        .foregroundStyle(Color.loopedTextStrong)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.loopedBackground)
                )
            }
            .allowsHitTesting(true)
        }
    }

    private struct DeepLinkUnavailableView: View {
        let unavailable: DeepLinkUnavailableState
        let onDismiss: () -> Void
        let onOpenHome: () -> Void

        var body: some View {
            NavigationStack {
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.loopedSymbol(.regular, size: 44))
                        .foregroundStyle(Color.loopedSecondary)

                    Text(unavailable.title)
                        .font(.loopedBodyMedium)
                        .foregroundStyle(Color.loopedTextStrong)

                    Text(unavailable.message)
                        .font(.loopedSubBodyRegular)
                        .foregroundStyle(Color.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    Spacer()

                    VStack(spacing: 10) {
                        Button(action: onOpenHome) {
                            Text("Home")
                                .font(.loopedSubBodyBold)
                                .foregroundStyle(Color.loopedBackground)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.loopedPrimary)
                                )
                        }

                        Button(action: onDismiss) {
                            Text("Back")
                                .font(.loopedSubBodyMedium)
                                .foregroundStyle(Color.loopedTextStrong)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.loopedTextSecondary.opacity(0.25), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.loopedBackground.ignoresSafeArea())
                .navigationBarBackButtonHidden(true)
            }
        }
    }

    private enum FeedDiscoveryStep: Int, CaseIterable {
        case postButton
        case filters
        case search

        var target: CoachMarkTarget {
            switch self {
            case .postButton:
                return .feedPostButton
            case .filters:
                return .feedFilterPills
            case .search:
                return .mainTabSearch
            }
        }

        var message: String {
            switch self {
            case .postButton:
                return "Post here once you're verified in a community. You can still read every post."
            case .filters:
                return "Filter the feed by the communities you follow."
            case .search:
                return "Search for a community to get verified."
            }
        }

        var primaryTitle: String {
            switch self {
            case .postButton:
                return "Next"
            case .filters:
                return "Next"
            case .search:
                return "Got it"
            }
        }

        var secondaryTitle: String? {
            switch self {
            case .postButton:
                return "Skip"
            case .filters, .search:
                return nil
            }
        }
    }
}

#Preview {
    ContentView()
}
