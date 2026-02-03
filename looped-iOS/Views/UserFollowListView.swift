import SwiftUI

struct UserFollowListView: View {
    @Environment(\.floatingActionButtonState) private var fabState
    @StateObject private var viewModel: UserFollowListViewModel
    private let kind: UserFollowListKind

    init(subject: UserFollowListSubject, kind: UserFollowListKind) {
        _viewModel = StateObject(wrappedValue: UserFollowListViewModel(subject: subject, kind: kind))
        self.kind = kind
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.top, 24)
                } else if let errorMessage = viewModel.errorMessage, viewModel.items.isEmpty {
                    errorState(message: errorMessage)
                } else if viewModel.items.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.items) { item in
                        UserFollowListRow(item: item)
                            .onAppear { Task { await viewModel.loadMoreIfNeeded(current: item) } }

                        Divider()
                            .background(Color.loopedMutedBackground)
                            .padding(.leading, 72)
                    }

                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .searchable(
            text: $viewModel.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search"
        )
        .onAppear {
            fabState.isHidden = true
        }
        .task { await viewModel.loadInitialIfNeeded() }
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder
    private var emptyState: some View {
        let trimmedQuery = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.loopedCustom(.semibold, size: 32))
                    .foregroundColor(.loopedSecondary)
                Text("No results")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)
                Text("Try a different search.")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }
            .padding(.top, 32)
            .padding(.horizontal, 24)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "person.2")
                    .font(.loopedCustom(.semibold, size: 32))
                    .foregroundColor(.loopedSecondary)
                Text(kind == .followers ? "No followers yet" : "Not following anyone yet")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)
                Text(kind == .followers ? "When people follow this account, they’ll show up here." : "When this account follows someone, they’ll show up here.")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            .padding(.horizontal, 24)
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.loopedCustom(.semibold, size: 32))
                .foregroundColor(.loopedError)
            Text(message)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedError)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }
}

private struct UserFollowListRow: View {
    let item: UserFollowListItem

    var body: some View {
        NavigationLink(destination: destinationView) {
            HStack(spacing: 12) {
                avatar

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.titleText)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text(item.subtitleText)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var destinationView: some View {
        switch item.kind {
        case .user:
            UserProfileView(userId: item.entityId)
        case .anon:
            UserProfileView(anonProfileId: item.entityId)
        }
    }

    @ViewBuilder
    private var avatar: some View {
        ProfileAvatarView(
            imageURL: item.profileImageURL,
            size: 44,
            variant: item.kind == .anon ? .anonymous : .standard
        )
    }
}
