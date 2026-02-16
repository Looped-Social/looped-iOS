import SafariServices
import SwiftUI

enum LinkedProvider: String, Identifiable {
    case google
    case apple

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .google: return "Google"
        case .apple: return "Apple"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    private let userService: UserServiceProtocol = UserService()
    private let contentPreferencesService: ContentPreferencesServiceProtocol = ContentPreferencesService()
    private let anonService = AnonService.shared
    private let verificationService: CommunityVerificationServiceProtocol = CommunityVerificationService()

    // Toggle states
    @State private var showFollowerCount = true
    @State private var hideAnonymousPosts = false
    @AppStorage("anonymousMode") private var anonymousMode = false
    @State private var showCommunityRequest = false
    @State private var isEnrollingAnon = false
    @State private var isLinkingGoogle = false
    @State private var isLinkingApple = false
    @State private var isUnlinkingGoogle = false
    @State private var isUnlinkingApple = false
    @State private var showEmailSignInSettings = false
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("preferCommunityShortNames") private var preferCommunityShortNames = true
    @State private var showFeedback = false
    @State private var showContentPolicy = false
    @State private var showPrivacyPolicy = false
    @State private var showUserAgreement = false
    @State private var showAttributions = false
    @State private var pendingDisconnectProvider: LinkedProvider?
    @State private var contentDestination: MenuDestination?

    private let feedbackUrl = URL(string: "https://www.mylooped.app/contact")!
    private let contentPolicyUrl = URL(string: "https://www.mylooped.app/community-rules")!
    private let privacyPolicyUrl = URL(string: "https://www.mylooped.app/privacy-policy")!
    private let userAgreementUrl = URL(string: "https://www.mylooped.app/terms")!
    private let attributionsUrl = URL(string: "https://www.mylooped.app/attributions")!

    // Alert states
    @State private var showLogoutAlert = false
    @State private var showAnonErrorAlert = false
    @State private var anonErrorMessage = ""
    @State private var showLinkErrorAlert = false
    @State private var linkErrorMessage = ""
    @State private var showFollowerUpdateAlert = false
    @State private var followerUpdateError = ""
    @State private var isUpdatingFollowerCount = false
    @State private var skipFollowerToggleUpdate = false
    @State private var contentPreferencesUpdateError = ""
    @State private var showContentPreferencesUpdateAlert = false
    @State private var isUpdatingContentPreferences = false
    @State private var skipContentPreferencesToggleUpdate = false

    var body: some View {
        let onOpenFeedback = { showFeedback = true }
        let onOpenContentPolicy = { showContentPolicy = true }
        let onOpenPrivacyPolicy = { showPrivacyPolicy = true }
        let onOpenUserAgreement = { showUserAgreement = true }
        let onOpenAttributions = { showAttributions = true }
        let onRequestCommunity = { showCommunityRequest = true }
        let onSelectContent: (MenuDestination) -> Void = { destination in contentDestination = destination }
        let onConfirmLogout = {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            showLogoutAlert = true
        }
        let onTapGoogle = {
            if authViewModel.isGoogleLinked {
                pendingDisconnectProvider = .google
            } else {
                connectGoogle()
            }
        }
        let onTapApple = {
            if authViewModel.isAppleLinked {
                pendingDisconnectProvider = .apple
            } else {
                connectApple()
            }
        }
        let onTapEmail = {
            showEmailSignInSettings = true
        }

        return AnyView(
            SettingsListContent(
                appearanceMode: $appearanceMode,
                preferCommunityShortNames: $preferCommunityShortNames,
                hideAnonymousPosts: $hideAnonymousPosts,
                showFollowerCount: $showFollowerCount,
                anonymousMode: $anonymousMode,
                onOpenFeedback: onOpenFeedback,
                onOpenContentPolicy: onOpenContentPolicy,
                onOpenPrivacyPolicy: onOpenPrivacyPolicy,
                onOpenUserAgreement: onOpenUserAgreement,
                onOpenAttributions: onOpenAttributions,
                onRequestCommunity: onRequestCommunity,
                onSelectContent: onSelectContent,
                onConfirmLogout: onConfirmLogout,
                onTapGoogle: onTapGoogle,
                onTapApple: onTapApple,
                onTapEmail: onTapEmail
            )
        )
        .fullScreenCover(isPresented: $showCommunityRequest) {
            CommunityRequestFlowView()
        }
        .sheet(isPresented: $showFeedback) {
            SafariView(url: feedbackUrl)
        }
        .sheet(isPresented: $showContentPolicy) {
            SafariView(url: contentPolicyUrl)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            SafariView(url: privacyPolicyUrl)
        }
        .sheet(isPresented: $showUserAgreement) {
            SafariView(url: userAgreementUrl)
        }
        .sheet(isPresented: $showAttributions) {
            SafariView(url: attributionsUrl)
        }
        .sheet(isPresented: $showEmailSignInSettings) {
            NavigationStack {
                EmailSignInSettingsView()
            }
        }
        .fullScreenCover(item: $contentDestination) { destination in
            NavigationStack {
                MenuDestinationView(destination: destination)
            }
        }
        .onChange(of: anonymousMode) { _, newValue in
            Task { await handleAnonToggle(isOn: newValue) }
        }
        .onReceive(authViewModel.$currentUser) { user in
            guard let user else { return }
            let resolvedValue = user.showFollowerCount ?? true
            if showFollowerCount != resolvedValue {
                skipFollowerToggleUpdate = true
                showFollowerCount = resolvedValue
            } else {
                skipFollowerToggleUpdate = false
            }

            let resolvedHideAnonymousPosts = user.hideAnonymousPosts ?? false
            if hideAnonymousPosts != resolvedHideAnonymousPosts {
                skipContentPreferencesToggleUpdate = true
                hideAnonymousPosts = resolvedHideAnonymousPosts
            } else {
                skipContentPreferencesToggleUpdate = false
            }
        }
        .onChange(of: showFollowerCount) { oldValue, newValue in
            if skipFollowerToggleUpdate {
                skipFollowerToggleUpdate = false
                return
            }
            Task { await updateFollowerCount(oldValue: oldValue, newValue: newValue) }
        }
        .onChange(of: hideAnonymousPosts) { oldValue, newValue in
            if skipContentPreferencesToggleUpdate {
                skipContentPreferencesToggleUpdate = false
                return
            }
            Task { await updateHideAnonymousPosts(oldValue: oldValue, newValue: newValue) }
        }
        .alert("Log out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log out", role: .destructive) {
                authViewModel.signOut()
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
        .alert("Anonymous Mode Failed", isPresented: $showAnonErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(anonErrorMessage)
        }
        .alert("Update Failed", isPresented: $showFollowerUpdateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(followerUpdateError)
        }
        .alert("Update Failed", isPresented: $showContentPreferencesUpdateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(contentPreferencesUpdateError)
        }
        .alert("Connection Failed", isPresented: $showLinkErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(linkErrorMessage)
        }
        .alert(item: $pendingDisconnectProvider) { provider in
            Alert(
                title: Text("Disconnect \(provider.displayName)?"),
                message: Text("Are you sure you want to disconnect this account?"),
                primaryButton: .destructive(Text("Disconnect")) {
                    Task { await disconnect(provider) }
                },
                secondaryButton: .cancel()
            )
        }
    }

}

private struct SettingsListContent: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @Binding var appearanceMode: String
    @Binding var preferCommunityShortNames: Bool
    @Binding var hideAnonymousPosts: Bool
    @Binding var showFollowerCount: Bool
    @Binding var anonymousMode: Bool

    let onOpenFeedback: () -> Void
    let onOpenContentPolicy: () -> Void
    let onOpenPrivacyPolicy: () -> Void
    let onOpenUserAgreement: () -> Void
    let onOpenAttributions: () -> Void
    let onRequestCommunity: () -> Void
    let onSelectContent: (MenuDestination) -> Void
    let onConfirmLogout: () -> Void
    let onTapGoogle: () -> Void
    let onTapApple: () -> Void
    let onTapEmail: () -> Void

    var body: some View {
        List {
            accountSection
            appearanceSection
            verificationSection
            supportSection
            communitySection
            connectedAccountsSection
            safetySection
            actionsSection
            contentSection
        }
        .buttonStyle(.plain)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var accountSection: some View {
        Section("Account") {
            NavigationLink(destination: UserSettingsView().environmentObject(authViewModel)) {
                SettingsRowLabel(icon: .asset("user-settings-icon"), title: "Edit profile")
            }

            NavigationLink(destination: SecurityView().environmentObject(authViewModel)) {
                SettingsRowLabel(icon: .asset("shield-icon"), title: "Security")
            }

            NavigationLink(destination: NotificationSettingsView()) {
                SettingsRowLabel(icon: .asset("bell-icon"), title: "Notifications")
            }

            NavigationLink(destination: PrivacyView().environmentObject(authViewModel)) {
                SettingsRowLabel(icon: .asset("lock-icon"), title: "Privacy and Data Protection")
            }
        }
    }

    @ViewBuilder
    private var appearanceSection: some View {
        Section("Appearance") {
            themePickerRow

            Toggle(isOn: $preferCommunityShortNames) {
                SettingsRowLabel(icon: .system("textformat.size.smaller"), title: "Prefer Community Short Names")
            }
            .tint(.loopedSecondary)
        }
    }

    private var themePickerRow: some View {
        HStack(spacing: 12) {
            SettingsIconView(icon: .system("circle.lefthalf.filled"))
            Text("Theme")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)
            Spacer()
            Picker("", selection: $appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
        }
    }

    @ViewBuilder
    private var verificationSection: some View {
        Section("Verification") {
            NavigationLink(destination: CommunityVerificationsView()) {
                SettingsRowLabel(icon: .system("checkmark.seal"), title: "Community verifications")
            }
        }
    }

    @ViewBuilder
    private var supportSection: some View {
        Section("Support & About") {
            Button(action: onOpenFeedback) {
                SettingsRowLabel(icon: .asset("help-icon"), title: "Feedback")
            }
            Button(action: onOpenContentPolicy) {
                SettingsRowLabel(icon: .asset("rules-icon"), title: "Content Policy")
            }
            Button(action: onOpenPrivacyPolicy) {
                SettingsRowLabel(icon: .asset("terms-and-policies-icon"), title: "Privacy Policy")
            }
            Button(action: onOpenUserAgreement) {
                SettingsRowLabel(icon: .asset("user-agreement-icon"), title: "User Agreement")
            }
            Button(action: onOpenAttributions) {
                SettingsRowLabel(icon: .system("doc.text"), title: "Attributions")
            }
        }
    }

    @ViewBuilder
    private var communitySection: some View {
        Section("Community") {
            Button(action: onRequestCommunity) {
                SettingsRowLabel(icon: .system("person.3"), title: "Request new community")
            }
        }
    }

    @ViewBuilder
    private var connectedAccountsSection: some View {
        Section("Connected Accounts") {
            EmailSignInRow(
                email: authViewModel.emailForEmailPasswordLogin,
                isEnabled: authViewModel.isEmailPasswordLinked,
                action: onTapEmail
            )

            ConnectedAccountRow(
                icon: .asset("google-logo"),
                title: "Google",
                isConnected: authViewModel.isGoogleLinked,
                action: onTapGoogle
            )

            ConnectedAccountRow(
                icon: .asset("apple-logo"),
                title: "Apple",
                isConnected: authViewModel.isAppleLinked,
                action: onTapApple
            )
        }
    }

    @ViewBuilder
    private var safetySection: some View {
        Section("Safety") {
            Toggle(isOn: $hideAnonymousPosts) {
                SettingsRowLabel(icon: .system("eye.slash"), title: "Hide Anonymous Posts")
            }
            .tint(.loopedSecondary)

            Toggle(isOn: $showFollowerCount) {
                SettingsRowLabel(icon: .asset("follower-count-icon"), title: "Show Follower Count")
            }
            .tint(.loopedSecondary)

            NavigationLink(destination: MessagingPermissionsView().environmentObject(authViewModel)) {
                SettingsRowLabel(icon: .asset("message-permisions-icon"), title: "Messaging Permissions")
            }
            NavigationLink(destination: BlockedUsersView()) {
                SettingsRowLabel(icon: .asset("blocked-icon"), title: "Blocked")
            }
            NavigationLink(destination: ViolationsView()) {
                SettingsRowLabel(icon: .system("exclamationmark.triangle"), title: "Appeals & Violations")
            }
            NavigationLink(destination: UnderReviewView()) {
                SettingsRowLabel(icon: .system("hourglass"), title: "Under review")
            }
            NavigationLink(destination: AnonymousRecoveryView()) {
                SettingsRowLabel(icon: .system("key.fill"), title: "Anonymous Recovery")
            }

            Toggle(isOn: $anonymousMode) {
                SettingsRowLabel(icon: .system("theatermasks"), title: "Anonymous Mode")
            }
            .tint(.loopedSecondary)
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        Section("Actions") {
            NavigationLink(destination: DeactivateAccountIntroView()) {
                SettingsRowLabel(icon: .system("pause.circle"), title: "Deactivate Account")
            }
            NavigationLink(destination: DeleteAccountIntroView()) {
                SettingsRowLabel(icon: .system("trash"), title: "Delete Account")
            }
            Button(action: onConfirmLogout) {
                SettingsRowLabel(icon: .asset("log-out-icon"), title: "Log out")
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        Section("Content") {
            Button { onSelectContent(.posts) } label: {
                SettingsRowLabel(icon: .system("text.bubble"), title: "Posts")
            }
            Button { onSelectContent(.replies) } label: {
                SettingsRowLabel(icon: .system("bubble.left.and.bubble.right"), title: "Replies")
            }
            Button { onSelectContent(.liked) } label: {
                SettingsRowLabel(icon: .system("heart"), title: "Liked")
            }
            Button { onSelectContent(.saved) } label: {
                SettingsRowLabel(icon: .system("bookmark"), title: "Saved")
            }
        }
    }
}

private extension SettingsView {
    func handleAnonToggle(isOn: Bool) async {
        guard isOn, !isEnrollingAnon else { return }
        isEnrollingAnon = true
        defer { isEnrollingAnon = false }
        do {
            let communityId = await AnonCommunityResolver.resolve(
                preferredCommunityId: authViewModel.currentUser?.displayCommunity?.id,
                preferredSpecializationId: authViewModel.currentUser?.displaySpecialization?.id,
                verificationService: verificationService
            )
            guard let communityId else {
                throw AnonServiceError.missingCommunityContext
            }
            AnonCommunityResolver.cacheSelectedCommunityId(communityId)
            _ = try await anonService.ensureIdentity(communityId: communityId)
        } catch {
            anonErrorMessage = error.localizedDescription
            showAnonErrorAlert = true
            anonymousMode = false
        }
    }

    func connectGoogle() {
        guard !isLinkingGoogle, !authViewModel.isGoogleLinked else { return }
        isLinkingGoogle = true
        Task {
            defer {
                Task { @MainActor in
                    isLinkingGoogle = false
                }
            }
            do {
                try await authViewModel.linkGoogle()
            } catch {
                await MainActor.run {
                    linkErrorMessage = error.localizedDescription
                    showLinkErrorAlert = true
                }
            }
        }
    }

    func connectApple() {
        guard !isLinkingApple, !authViewModel.isAppleLinked else { return }
        isLinkingApple = true
        Task {
            defer {
                Task { @MainActor in
                    isLinkingApple = false
                }
            }
            do {
                try await authViewModel.linkApple()
            } catch {
                await MainActor.run {
                    linkErrorMessage = error.localizedDescription
                    showLinkErrorAlert = true
                }
            }
        }
    }

    func disconnect(_ provider: LinkedProvider) async {
        switch provider {
        case .google:
            guard !isUnlinkingGoogle else { return }
            isUnlinkingGoogle = true
            defer {
                Task { @MainActor in
                    isUnlinkingGoogle = false
                }
            }
            do {
                try await authViewModel.unlinkGoogle()
            } catch {
                await MainActor.run {
                    linkErrorMessage = error.localizedDescription
                    showLinkErrorAlert = true
                }
            }
        case .apple:
            guard !isUnlinkingApple else { return }
            isUnlinkingApple = true
            defer {
                Task { @MainActor in
                    isUnlinkingApple = false
                }
            }
            do {
                try await authViewModel.unlinkApple()
            } catch {
                await MainActor.run {
                    linkErrorMessage = error.localizedDescription
                    showLinkErrorAlert = true
                }
            }
        }
    }

    func updateFollowerCount(oldValue: Bool, newValue: Bool) async {
        guard !isUpdatingFollowerCount else { return }
        guard let user = authViewModel.currentUser else { return }
        isUpdatingFollowerCount = true
        defer { isUpdatingFollowerCount = false }
        do {
            let updatedUser = try await userService.updateProfile(
                displayName: nil,
                bio: nil,
                isAnonymous: user.isAnonymous,
                showFollowerCount: newValue,
                messagePermission: user.messagePermission
            )
            await MainActor.run {
                authViewModel.currentUser = updatedUser
            }
        } catch {
            followerUpdateError = error.localizedDescription
            showFollowerUpdateAlert = true
            skipFollowerToggleUpdate = true
            showFollowerCount = oldValue
        }
    }

    func updateHideAnonymousPosts(oldValue: Bool, newValue: Bool) async {
        guard !isUpdatingContentPreferences else { return }
        isUpdatingContentPreferences = true
        defer { isUpdatingContentPreferences = false }
        do {
            let response = try await contentPreferencesService.updateHideAnonymousPosts(newValue)
            let resolvedValue = response.content.hideAnonymousPosts
            await MainActor.run {
                hideAnonymousPosts = resolvedValue
                if let user = authViewModel.currentUser {
                    authViewModel.currentUser = user.updating(hideAnonymousPosts: resolvedValue)
                }
            }
            NotificationCenter.default.post(
                name: .contentPreferencesChanged,
                object: nil,
                userInfo: ["hideAnonymousPosts": resolvedValue]
            )
        } catch {
            await MainActor.run {
                contentPreferencesUpdateError = error.localizedDescription
                showContentPreferencesUpdateAlert = true
                skipContentPreferencesToggleUpdate = true
                hideAnonymousPosts = oldValue
            }
        }
    }
}

// MARK: - Connected Account Row

struct ConnectedAccountRow: View {
    let icon: IconSource
    let title: String
    let isConnected: Bool
    let action: () -> Void

    init(
        icon: IconSource,
        title: String,
        isConnected: Bool,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.isConnected = isConnected
        self.action = action
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            switch icon {
            case .system(let name):
                Image(systemName: name)
                    .font(.loopedCustom(.medium, size: 16))
                    .foregroundColor(.loopedTextPrimary)
                    .frame(width: 20, height: 20)
            case .asset(let name):
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            }

            Text(title)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            Button(isConnected ? "Connected" : "Connect") {
                action()
            }
            .font(.loopedSubBodyMedium)
            .foregroundColor(isConnected ? .loopedTextSecondary : .loopedSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Email Sign-In Row

struct EmailSignInRow: View {
    let email: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope")
                .font(.loopedCustom(.medium, size: 16))
                .foregroundColor(.loopedTextPrimary)
                .frame(width: 20, height: 20)

            Text("Email")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            if isEnabled, !email.isEmpty {
                Text(email)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Button(isEnabled ? "Edit" : "Add") {
                action()
            }
            .font(.loopedSubBodyMedium)
            .foregroundColor(.loopedSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
