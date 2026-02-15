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
            ProfileAvatarView(imageURL: person.avatarURL, size: 40)

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
    @Environment(\.preferCommunityShortNames) private var preferCommunityShortNames

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                ProfileAvatarView(
                    imageURL: post.post.isAnonymous ? nil : post.post.authorProfileImageURL,
                    size: 40,
                    variant: post.post.isAnonymous ? .anonymous : .standard
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(post.post.resolvedAuthorName)
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 8)

                        Text(timeAgoString(from: post.post.createdAt))
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    if let communityContextText {
                        Text(communityContextText)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    postContentPreview
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var communityContextText: String? {
        if let name = post.post.communityDisplayName(preferShortNames: preferCommunityShortNames) {
            return "Posting in \(name)"
        }
        if let kind = post.post.communityKind, kind != .unknown {
            return "Posting in \(kind.rawValue.capitalized)"
        }
        return nil
    }

    @ViewBuilder
    private var postContentPreview: some View {
        let trimmed = post.post.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Text("View post")
                .font(.loopedBody)
                .foregroundColor(.loopedTextSecondary)
                .lineLimit(2)
        } else if trimmed.contains("#") || trimmed.contains("@") {
            HashtagText(
                text: trimmed,
                font: .loopedBody,
                textColor: .loopedTextPrimary,
                hashtagColor: .loopedPrimary,
                onHashtagTap: { _ in },
                onMentionTap: { _ in }
            )
            .multilineTextAlignment(.leading)
            .lineLimit(3)
        } else {
            LinkifiedText(
                trimmed,
                font: .loopedBody,
                textColor: .loopedTextPrimary,
                linkColor: .loopedPrimary
            )
            .multilineTextAlignment(.leading)
            .lineLimit(3)
        }
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
                    Text(loopLabel)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text(loopSubtitle)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if let label = loop.specializationLabel {
                            Text(label)
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)

                            Text("•")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                        }

                        Text("\(loop.memberCount) members")
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var loopLabel: String {
        CommunityLabelText.preferredName(
            preferShortNames: false,
            name: loop.name,
            shortName: loop.shortName
        ) ?? loop.name
    }

    private var loopSubtitle: String {
        let trimmed = loop.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return loop.specializationLabel ?? "Community"
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
                            .scaledToFit()
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
            .fill(Color.loopedBackground)
            .overlay(
                Group {
                    if loop.kind == .specialization {
                        specializationGlyph
                    } else {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(.loopedTextSecondary)
                            .font(.loopedCustom(size: 16))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.loopedMutedBackground, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var specializationGlyph: some View {
        if let icon = loop.icon?.normalizedOrNil() {
            switch icon.kind {
            case .emoji:
                Text(icon.value)
                    .font(.loopedCustom(.semibold, size: 22))
                    .foregroundColor(.loopedTextPrimary)
            case .sfSymbol:
                Image(systemName: icon.value)
                    .font(.loopedCustom(.semibold, size: 18))
                    .foregroundColor(.loopedTextPrimary)
            case .imageUrl:
                if let url = URL(string: icon.value), url.scheme != nil {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Text(specializationInitials)
                                .font(.loopedCustom(.semibold, size: 16))
                                .foregroundColor(.loopedPrimary)
                        case .empty:
                            ProgressView()
                                .tint(.loopedTextSecondary)
                        @unknown default:
                            Text(specializationInitials)
                                .font(.loopedCustom(.semibold, size: 16))
                                .foregroundColor(.loopedPrimary)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Text(specializationInitials)
                        .font(.loopedCustom(.semibold, size: 16))
                        .foregroundColor(.loopedPrimary)
                }
            case .unknown:
                Text(specializationInitials)
                    .font(.loopedCustom(.semibold, size: 16))
                    .foregroundColor(.loopedPrimary)
            }
        } else {
            Text(specializationInitials)
                .font(.loopedCustom(.semibold, size: 16))
                .foregroundColor(.loopedPrimary)
        }
    }

    private var specializationInitials: String {
        let trimmed = loopLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }

        if trimmed.count <= 3, trimmed.contains(" ") == false {
            return trimmed.uppercased()
        }

        let parts = trimmed.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        let combined = (first + second).uppercased()
        return combined.isEmpty ? "?" : combined
    }
}

// MARK: - Search Results Section
struct SearchResultsSection: View {
    let results: SearchResults
    let onPostTap: (SearchResultPost) -> Void
    let onLoopTap: (SearchResultLoop) -> Void
    let onHashtagTap: (String) -> Void

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
                    onHashtagTap(tag.name)
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
        onLoopTap: { _ in },
        onHashtagTap: { _ in }
    )
    .background(Color.loopedBackground)
}
