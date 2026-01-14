import SafariServices
import SwiftUI

// MARK: - Icon Source Enum

enum IconSource {
    case system(String)  // SF Symbol
    case asset(String)   // Asset from Assets.xcassets
}

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
    @Environment(\.dismiss) private var dismiss
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
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @State private var showFeedback = false
    @State private var showContentPolicy = false
    @State private var showPrivacyPolicy = false
    @State private var showUserAgreement = false
    @State private var pendingDisconnectProvider: LinkedProvider?

    private let feedbackUrl = URL(string: "https://www.mylooped.app/contact")!
    private let contentPolicyUrl = URL(string: "https://www.mylooped.app/community-rules")!
    private let privacyPolicyUrl = URL(string: "https://www.mylooped.app/privacy-policy")!
    private let userAgreementUrl = URL(string: "https://www.mylooped.app/terms")!

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
        VStack(spacing: 0) {
            // Header
            SettingsHeader {
                dismiss()
            }

            // Scrollable content
            ScrollView {
                    VStack(spacing: 0) {
                    // Account Section
                    SettingsSection(title: "Account") {
                        NavigationLink(destination: UserSettingsView().environmentObject(authViewModel)) {
                            SettingsNavigationRow(icon: .asset("user-settings-icon"), title: "Edit profile")
                        }
                            .buttonStyle(PlainButtonStyle())

                            NavigationLink(destination: SecurityView().environmentObject(authViewModel)) {
                                SettingsNavigationRow(icon: .asset("shield-icon"), title: "Security")
                            }
                            .buttonStyle(PlainButtonStyle())

                        NavigationLink(destination: NotificationSettingsView()) {
                            SettingsNavigationRow(icon: .asset("bell-icon"), title: "Notifications")
                        }
                        .buttonStyle(PlainButtonStyle())

                        NavigationLink(destination: PrivacyView()) {
                            SettingsNavigationRow(icon: .asset("lock-icon"), title: "Privacy and Data Protection")
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Appearance Section
                    SettingsSection(title: "Appearance") {
                        AppearanceModeRow(selection: $appearanceMode)
                    }

                    // Verification Section
                    SettingsSection(title: "Verification") {
                        NavigationLink(destination: CommunityVerificationsView()) {
                            SettingsNavigationRow(icon: .system("checkmark.seal"), title: "Community verifications")
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Support & About Section
                    SettingsSection(title: "Support & About") {
                        SettingsRow(icon: .asset("help-icon"), title: "Feedback") {
                            showFeedback = true
                        }
                        SettingsRow(icon: .asset("rules-icon"), title: "Content Policy") {
                            showContentPolicy = true
                        }
                        SettingsRow(icon: .asset("terms-and-policies-icon"), title: "Privacy Policy") {
                            showPrivacyPolicy = true
                        }
                        SettingsRow(icon: .asset("user-agreement-icon"), title: "User Agreement") {
                            showUserAgreement = true
                        }
                    }

                    // Community Section
                    SettingsSection(title: "Community") {
                        SettingsRow(icon: .system("person.3"), title: "Request new community") {
                            showCommunityRequest = true
                        }
                    }

                    // Connected Accounts Section
                    SettingsSection(title: "Connected Accounts") {
                        ConnectedAccountRow(
                            icon: .asset("google-logo"),
                            title: "Google",
                            isConnected: authViewModel.isGoogleLinked
                        ) {
                            if authViewModel.isGoogleLinked {
                                pendingDisconnectProvider = .google
                            } else {
                                connectGoogle()
                            }
                        }
                        ConnectedAccountRow(
                            icon: .asset("apple-logo"),
                            title: "Apple",
                            isConnected: authViewModel.isAppleLinked
                        ) {
                            if authViewModel.isAppleLinked {
                                pendingDisconnectProvider = .apple
                            } else {
                                connectApple()
                            }
                        }
                    }

                    // Safety Section
                    SettingsSection(title: "Safety") {
                        SettingsToggleRow(
                            icon: .system("eye.slash"),
                            title: "Hide Anonymous Posts",
                            isOn: $hideAnonymousPosts
                        )
                        SettingsToggleRow(
                            icon: .asset("follower-count-icon"),
                            title: "Show Follower Count",
                            isOn: $showFollowerCount
                        )
                        NavigationLink(destination: MessagingPermissionsView().environmentObject(authViewModel)) {
                            SettingsNavigationRow(icon: .asset("message-permisions-icon"), title: "Messaging Permissions")
                        }
                        .buttonStyle(PlainButtonStyle())
                        NavigationLink(destination: BlockedUsersView()) {
                            SettingsNavigationRow(icon: .asset("blocked-icon"), title: "Blocked")
                        }
                        .buttonStyle(PlainButtonStyle())
                        NavigationLink(destination: ViolationsView()) {
                            SettingsNavigationRow(icon: .system("exclamationmark.triangle"), title: "Appeals & Violations")
                        }
                        .buttonStyle(PlainButtonStyle())
                        NavigationLink(destination: AnonymousRecoveryView()) {
                            SettingsNavigationRow(icon: .system("key.fill"), title: "Anonymous Recovery")
                        }
                        .buttonStyle(PlainButtonStyle())
                        SettingsToggleRow(
                            icon: .system("theatermasks"),
                            title: "Anonymous Mode",
                            isOn: $anonymousMode
                        )
                    }

                    // Actions Section
                    SettingsSection(title: "Actions") {
                        NavigationLink(destination: DeactivateAccountIntroView()) {
                            SettingsNavigationRow(icon: .system("pause.circle"), title: "Deactivate Account")
                        }
                        .buttonStyle(PlainButtonStyle())
                        NavigationLink(destination: DeleteAccountIntroView()) {
                            SettingsNavigationRow(icon: .system("trash"), title: "Delete Account")
                        }
                        .buttonStyle(PlainButtonStyle())
                        SettingsRow(icon: .asset("log-out-icon"), title: "Log out") {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            showLogoutAlert = true
                        }
                    }

                }
                .padding(.bottom, 100)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
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

private extension SettingsView {
    func handleAnonToggle(isOn: Bool) async {
        guard isOn, !isEnrollingAnon else { return }
        isEnrollingAnon = true
        defer { isEnrollingAnon = false }
        do {
            let communityId = await AnonCommunityResolver.resolve(
                preferredCommunityId: authViewModel.currentUser?.displayCommunity?.id,
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

// MARK: - Settings Header

struct SettingsHeader: View {
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.loopedCustom(.medium, size: 24))
                    .foregroundColor(.loopedTextSecondary)
            }

            Image("logo-banner")
                .resizable()
                .scaledToFit()
                .frame(height: 36)

            Spacer()

            Text("Settings")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 12)
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.loopedBodyStrong)
                .foregroundColor(.loopedTextPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 4)

            VStack(spacing: 0) {
                content
            }
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: IconSource?
    let title: String
    let textColor: Color
    let isIndented: Bool
    let action: (() -> Void)?

    init(
        icon: IconSource? = nil,
        title: String,
        textColor: Color = .loopedTextPrimary,
        isIndented: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.textColor = textColor
        self.isIndented = isIndented
        self.action = action
    }

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 4) {
                if !isIndented {
                    if let icon = icon {
                        switch icon {
                        case .system(let name):
                            Image(systemName: name)
                                .font(.loopedCustom(.medium, size: 16))
                                .foregroundColor(.loopedTextSecondary)
                                .frame(width: 20, height: 10)
                        case .asset(let name):
                            Image(name)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.loopedTextSecondary)
                                .frame(width: 20, height: 20)
                        }
                    }
                }

                Text(title)
                    .font(.loopedBodyMedium)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(.horizontal, isIndented ? 52 : 28)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Appearance Mode Row
struct AppearanceModeRow: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.loopedCustom(.medium, size: 16))
                .foregroundColor(.loopedTextSecondary)
                .frame(width: 20, height: 20)

            Text("Theme")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            Picker("", selection: $selection) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    let icon: IconSource
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            switch icon {
            case .system(let name):
                Image(systemName: name)
                    .font(.loopedCustom(.medium, size: 16))
                    .foregroundColor(.loopedTextSecondary)
                    .frame(width: 20, height: 20)
            case .asset(let name):
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.loopedTextSecondary)
                    .frame(width: 20, height: 20)
            }

            Text(title)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Color.loopedSecondary))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Settings Navigation Row

struct SettingsNavigationRow: View {
    let icon: IconSource?
    let title: String
    let textColor: Color

    init(
        icon: IconSource? = nil,
        title: String,
        textColor: Color = .loopedTextPrimary
    ) {
        self.icon = icon
        self.title = title
        self.textColor = textColor
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                switch icon {
                case .system(let name):
                    Image(systemName: name)
                        .font(.loopedCustom(.medium, size: 16))
                        .foregroundColor(.loopedTextSecondary)
                        .frame(width: 20, height: 10)
                case .asset(let name):
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.loopedTextSecondary)
                        .frame(width: 20, height: 20)
                }
            }

            Text(title)
                .font(.loopedBodyMedium)
                .foregroundColor(textColor)
                .multilineTextAlignment(.leading)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.loopedCustom(.semibold, size: 13))
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 8)
    }
}

// MARK: - Connected Account Row

struct ConnectedAccountRow: View {
    let icon: IconSource
    let title: String
    let isConnected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

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
                Image(resolvedAssetName(for: name))
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

    private func resolvedAssetName(for name: String) -> String {
        if name == "apple-logo", colorScheme == .dark {
            return "apple-logo-dark"
        }
        return name
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
