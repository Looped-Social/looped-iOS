import SwiftUI

struct RepostersListView: View {
    let users: [RepostBannerUser]
    let totalCount: Int

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if users.isEmpty {
                    emptyState
                } else {
                    ForEach(users) { user in
                        NavigationLink(destination: UserProfileView(userId: user.userId)) {
                            HStack(spacing: 12) {
                                ProfileAvatarView(imageURL: nil, size: 44)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("@\(user.username)")
                                        .font(.loopedBodyMedium)
                                        .foregroundColor(.loopedTextPrimary)

                                    Text("Reposted")
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

                        Divider()
                            .background(Color.loopedMutedBackground)
                            .padding(.leading, 72)
                    }

                    if totalCount > users.count {
                        Text("And \(totalCount - users.count) more")
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)
                            .padding(.top, 12)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle("Reposts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.2.squarepath")
                .font(.loopedCustom(.semibold, size: 32))
                .foregroundColor(.loopedSecondary)

            Text(totalCount == 0 ? "No reposts yet" : "Reposted by \(totalCount) people")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            Text(totalCount == 0 ? "When someone reposts, they’ll show up here." : "The full list isn’t available yet.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}
