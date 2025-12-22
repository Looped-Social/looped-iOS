import SwiftUI

// MARK: - Person Search Result
struct PersonSearchResultItem: View {
    let person: SearchResultPerson

    var body: some View {
        if let backendId = person.backendId {
            NavigationLink(destination: UserProfileView(userId: backendId)) {
                rowContent
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: person.avatarURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.loopedMutedBackground)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.loopedTextSecondary)
                            .font(.system(size: 16))
                    )
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)

                Text("@\(person.username) • \(person.title) @ \(person.company)")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Post Search Result
struct PostSearchResultItem: View {
    let post: SearchResultPost
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(post.authorName)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Spacer()

                    Text(timeAgoString(from: post.timestamp))
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }

                Text(post.content)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                HStack {
                    Text("\(post.reactionCount) reactions")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)

                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)

        let minutes = Int(timeInterval) / 60
        let hours = Int(timeInterval) / 3600
        let days = Int(timeInterval) / 86400

        if days > 0 {
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "now"
        }
    }
}

// MARK: - Loop Search Result
struct LoopSearchResultItem: View {
    let loop: SearchResultLoop
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                loopImage
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(loop.name)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text(loop.description)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .lineLimit(1)

                    Text("\(loop.memberCount) members")
                        .font(.loopedSmallText)
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

    private var loopImage: some View {
        Group {
            if let imageUrl = loop.imageUrl,
               let url = URL(string: imageUrl),
               url.scheme != nil {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderImage
                    case .empty:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
        }
        .clipped()
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.loopedMutedBackground)
            .overlay(
                Image(systemName: "person.3.fill")
                    .foregroundColor(.loopedTextSecondary)
                    .font(.system(size: 16))
            )
    }
}

// MARK: - Search Results Section
struct SearchResultsSection: View {
    let results: SearchResults
    let onPostTap: (SearchResultPost) -> Void
    let onLoopTap: (SearchResultLoop) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // People results
            ForEach(results.people) { person in
                PersonSearchResultItem(person: person)

                if person.id != results.people.last?.id || !results.posts.isEmpty || !results.loops.isEmpty {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }

            // Post results
            ForEach(results.posts) { post in
                PostSearchResultItem(post: post) {
                    onPostTap(post)
                }

                if post.id != results.posts.last?.id || !results.loops.isEmpty {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }

            // Loop results
            ForEach(results.loops) { loop in
                LoopSearchResultItem(loop: loop) {
                    onLoopTap(loop)
                }

                if loop.id != results.loops.last?.id {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }

            // Hashtag results (listed after loops)
            ForEach(results.hashtags) { tag in
                Button(action: {
                    // Handled upstream via hashtag suggestions tap
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "number")
                            .foregroundColor(.loopedTextSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tag.name)
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedTextPrimary)
                            Text("\(tag.usageCount) uses")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())

                if tag.id != results.hashtags.last?.id {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }
}

#Preview {
    let mockResults = SearchResults(
        people: [
            SearchResultPerson(
                id: UUID(),
                name: "Sarah Chen",
                username: "sarah58",
                title: "Product Designer",
                company: "Looped",
                avatarURL: nil
            )
        ],
        posts: [],
        loops: []
    )

    return SearchResultsSection(
        results: mockResults,
        onPostTap: { _ in },
        onLoopTap: { _ in }
    )
    .background(Color.loopedBackground)
}
