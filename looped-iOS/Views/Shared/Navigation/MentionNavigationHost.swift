import SwiftUI

struct MentionRoute: Hashable, Identifiable {
    let handle: String

    var id: String { handle.lowercased() }
}

private struct LoopedOpenMentionKey: EnvironmentKey {
    static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
    var loopedOpenMention: (String) -> Void {
        get { self[LoopedOpenMentionKey.self] }
        set { self[LoopedOpenMentionKey.self] = newValue }
    }
}

private struct MentionNavigationHostModifier: ViewModifier {
    @State private var activeMention: MentionRoute?

    func body(content: Content) -> some View {
        content
            .environment(\.loopedOpenMention) { rawHandle in
                let cleanHandle = normalizeMentionHandle(rawHandle)
                guard !cleanHandle.isEmpty else { return }
                activeMention = MentionRoute(handle: cleanHandle)
            }
            .navigationDestination(item: $activeMention) { route in
                MentionProfileDestinationView(handle: route.handle)
            }
    }

    private func normalizeMentionHandle(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let unprefixed = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        return unprefixed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

}

extension View {
    func loopedMentionNavigationHost() -> some View {
        modifier(MentionNavigationHostModifier())
    }
}

struct MentionProfileDestinationView: View {
    let handle: String

    @State private var isLoading = true
    @State private var hasAttemptedResolution = false
    @State private var resolvedUserId: Int?
    @State private var errorMessage: String?

    private let userService: UserServiceProtocol

    private var normalizedHandle: String {
        handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    init(handle: String, userService: UserServiceProtocol = UserService()) {
        self.handle = handle
        self.userService = userService
    }

    var body: some View {
        Group {
            if let resolvedUserId {
                UserProfileView(userId: resolvedUserId)
            } else if isLoading {
                ProgressView()
                    .tint(.loopedPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.loopedBackground)
            } else {
                unavailableView
            }
        }
        .navigationTitle("@\(normalizedHandle)")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: normalizedHandle) {
            await resolveIfNeeded()
        }
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Text("Profile unavailable")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            Text(errorMessage ?? "We couldn't find this profile.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .multilineTextAlignment(.center)

            Button("Try again") {
                Task {
                    await retryResolution()
                }
            }
            .font(.loopedSubBodyMedium)
            .foregroundColor(.loopedPrimary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground)
    }

    @MainActor
    private func resolveIfNeeded() async {
        guard !hasAttemptedResolution else { return }
        await resolveProfile()
    }

    @MainActor
    private func retryResolution() async {
        hasAttemptedResolution = false
        errorMessage = nil
        await resolveIfNeeded()
    }

    @MainActor
    private func resolveProfile() async {
        hasAttemptedResolution = true
        isLoading = true
        defer { isLoading = false }

        do {
            resolvedUserId = try await resolveUserIdForMentionHandle()
            errorMessage = nil
        } catch {
            resolvedUserId = nil
            errorMessage = error.localizedDescription
        }
    }

    private func resolveUserIdForMentionHandle() async throws -> Int {
        let page = try await userService.searchUsers(query: normalizedHandle, limit: 25, cursor: nil)
        if let match = page.users.first(where: { user in
            let username = (user.username ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let handle = user.handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return username == normalizedHandle || handle == normalizedHandle
        }) {
            return match.backendId
        }
        throw UserServiceError.userSlugNotFound(normalizedHandle)
    }
}
