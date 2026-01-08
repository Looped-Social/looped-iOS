import SwiftUI

struct BlockedUsersView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BlockedUsersViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    Text("Manage the people you've blocked.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if viewModel.isLoading && viewModel.blockedUsers.isEmpty {
                        ProgressView()
                            .padding(.top, 16)
                    }

                    if let errorMessage = viewModel.errorMessage, viewModel.blockedUsers.isEmpty {
                        Text(errorMessage)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedError)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    if viewModel.blockedUsers.isEmpty && viewModel.errorMessage == nil && !viewModel.isLoading {
                        emptyState
                    } else {
                        blockedList
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
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

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.loopedCustom(.medium, size: 24))
                    .foregroundColor(.loopedTextSecondary)
            }

            Spacer()

            Text("Blocked Users")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            Image(systemName: "chevron.left")
                .font(.loopedCustom(.medium, size: 24))
                .opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 12)
    }

    private var blockedList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.blockedUsers) { user in
                BlockedUserRow(
                    user: user,
                    isUnblocking: viewModel.unblockingUserIds.contains(user.backendId)
                ) {
                    Task { await viewModel.unblock(user) }
                }
                .onAppear {
                    Task { await viewModel.loadMoreIfNeeded(current: user) }
                }

                if user.id != viewModel.blockedUsers.last?.id {
                    Divider()
                        .padding(.leading, 64)
                }
            }
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
            NavigationLink(destination: UserProfileView(userId: user.backendId)) {
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
        .padding(.vertical, 12)
    }
}

#Preview {
    BlockedUsersView()
}
