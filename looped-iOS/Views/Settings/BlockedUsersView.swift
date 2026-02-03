import SwiftUI

private enum BlockedUsersDestination: Hashable {
    case user(id: Int)
    case anon(profileId: Int)
}

struct BlockedUsersView: View {
    @StateObject private var viewModel = BlockedUsersViewModel()

    var body: some View {
        List {
            Section {
                Text("Manage the people you've blocked.")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            Section {
                if viewModel.isLoading && viewModel.blockedUsers.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if let errorMessage = viewModel.errorMessage, viewModel.blockedUsers.isEmpty {
                    Text(errorMessage)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedError)
                        .multilineTextAlignment(.center)
                } else if viewModel.blockedUsers.isEmpty && viewModel.errorMessage == nil && !viewModel.isLoading {
                    emptyState
                        .listRowBackground(Color.loopedBackground)
                } else {
                    ForEach(viewModel.blockedUsers) { user in
                        BlockedUserRow(
                            user: user,
                            isUnblocking: viewModel.unblockingPrincipalIds.contains(user.principalId)
                        ) {
                            Task { await viewModel.unblock(user) }
                        }
                        .onAppear {
                            Task { await viewModel.loadMoreIfNeeded(current: user) }
                        }
                    }

                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Blocked")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(for: BlockedUsersDestination.self) { destination in
            switch destination {
            case .user(let id):
                UserProfileView(userId: id)
            case .anon(let profileId):
                UserProfileView(anonProfileId: profileId)
            }
        }
        .task {
            await viewModel.loadBlockedUsers()
        }
        .alert(
            "Unable to Unblock",
            isPresented: Binding(
                get: { viewModel.actionErrorMessage != nil },
                set: { if !$0 { viewModel.actionErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.actionErrorMessage ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.fill.xmark")
                .font(.loopedCustom(.semibold, size: 32))
                .foregroundColor(.loopedSecondary)
            Text("No blocked accounts")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)
            Text("When you block someone, they'll show up here.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }
}

private struct BlockedUserRow: View {
    let user: BlockedUser
    let isUnblocking: Bool
    let onUnblock: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: destination) {
                HStack(spacing: 12) {
                    ProfileAvatarView(imageURL: user.profileImageURL, size: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.resolvedDisplayName)
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextPrimary)

                        Text(user.subtitle)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            Button(action: onUnblock) {
                ZStack {
                    Text("Unblock")
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedSecondary)
                        .opacity(isUnblocking ? 0 : 1)

                    if isUnblocking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .loopedSecondary))
                            .scaleEffect(0.7)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.loopedSecondary, lineWidth: 1)
                )
            }
            .disabled(isUnblocking)
        }
    }

    private var destination: BlockedUsersDestination {
        user.isAnonymous ? .anon(profileId: user.backendId) : .user(id: user.backendId)
    }
}

#Preview {
    BlockedUsersView()
}
