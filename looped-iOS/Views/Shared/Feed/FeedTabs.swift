import SwiftUI

enum FeedTab: String, CaseIterable {
    case forYou = "For You"
    case hot = "Latest"
    case following = "Following"
}

struct FeedTabs: View {
    @State private var selectedTab: FeedTab = .forYou
    @Binding var isSearching: Bool
    @Binding var searchQuery: String
    @FocusState private var isSearchFocused: Bool
    @Environment(\.preferCommunityShortNames) private var preferCommunityShortNames

    let communities: [CommunitySummary]
    let selectedCommunityId: Int?
    let onSelectCommunity: (CommunitySummary) -> Void
    let onSelectAll: () -> Void
    let onLoadMore: (CommunitySummary) -> Void
    let onSelectMode: (FeedMode) -> Void
    let searchResults: [CommunitySearchResult]
    let isSearchLoading: Bool
    let searchErrorMessage: String?
    let onSearchQueryChange: (String) -> Void
    let onSelectSearchResult: (CommunitySearchResult) -> Void
    let onDismissSearch: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector (For You / Latest / Following)
            VStack(spacing: 0) {
                HStack {
                    ForEach(FeedTab.allCases, id: \.self) { tab in
                        Button(action: {
                            guard selectedTab != tab else { return }
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            selectedTab = tab
                            onSelectMode(tab.feedMode)
                        }) {
                            Text(tab.rawValue)
                                .font(selectedTab == tab ? .loopedSubBodyBold : .loopedSubBodyMedium)
                                .foregroundColor(selectedTab == tab ? .loopedPrimary : .loopedTextSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                
                // Full-width underlines
                HStack(spacing: 0) {
                    ForEach(FeedTab.allCases, id: \.self) { tab in
                        Rectangle()
                            .frame(height: selectedTab == tab ? 2 : 1)
                            .foregroundColor(selectedTab == tab ? .loopedPrimary : .loopedTextSecondary.opacity(0.3))
                    }
                }
            }
            
            Group {
                if isSearching {
                    communitySearch
                } else {
                    filterPills
                }
            }
            .coachMarkTarget(.feedFilterPills)
        }
        .onChange(of: isSearching) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isSearchFocused = true
                }
            }
        }
        .onChange(of: searchQuery) { _, newValue in
            onSearchQueryChange(newValue)
        }
    }
}

private extension FeedTabs {
    var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        isSearching = true
                    }
                }) {
                    Image("search-icon")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.loopedSecondary)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Search communities")

                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    onSelectAll()
                }) {
                    Text("All Loops")
                        .font(selectedCommunityId == nil ? .loopedSubBodyBold : .loopedSubBodyMedium)
                        .foregroundColor(selectedCommunityId == nil ? .loopedWhite : .loopedTextSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(
                            selectedCommunityId == nil
                            ? Color.loopedPrimary
                            : Color.loopedTextSecondary.opacity(0.1)
                        )
                        .cornerRadius(20)
                }
                .buttonStyle(PlainButtonStyle())

                ForEach(communities) { community in
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        onSelectCommunity(community)
                    }) {
                        Text(communityLabel(for: community))
                            .font(selectedCommunityId == community.id ? .loopedSubBodyBold : .loopedSubBodyMedium)
                            .foregroundColor(selectedCommunityId == community.id ? .loopedWhite : .loopedTextSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(
                                selectedCommunityId == community.id
                                ? Color.loopedPrimary
                                : Color.loopedTextSecondary.opacity(0.1)
                            )
                            .cornerRadius(20)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onAppear {
                        if community.id == communities.last?.id {
                            onLoadMore(community)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 32)
        .padding(.vertical, 8)
    }

    var communitySearch: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image("search-icon")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.loopedTextSecondary)
                        .frame(width: 18, height: 18)

                    TextField("Search communities", text: $searchQuery)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                        .tint(.loopedPrimary)
                        .focused($isSearchFocused)
                        .submitLabel(.search)

                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.loopedCustom(.medium, size: 16))
                                .foregroundColor(.loopedTextSecondary.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.loopedMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(22)

                LoopedCancelTextButton(action: dismissSearch)
                    .accessibilityLabel("Cancel community search")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            VStack(spacing: 0) {
                if let message = searchErrorMessage, !message.isEmpty {
                    Text(message)
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedError)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                } else if isSearchLoading {
                    ProgressView()
                        .tint(.loopedPrimary)
                        .padding(.vertical, 16)
                } else if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(spacing: 4) {
                        Text("Start typing to search.")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)

                        Text("Selecting a community filters your feed to posts from that community.")
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary.opacity(0.9))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                } else if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    Text("Type at least 2 characters.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.vertical, 16)
                } else if searchResults.isEmpty {
                    Text("No matches found.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.vertical, 16)
	                } else {
	                    ScrollView {
	                        LazyVStack(spacing: 0) {
	                            ForEach(searchResults) { result in
	                                Button(action: { selectSearchResult(result) }) {
	                                    CommunitySearchResultRow(
	                                        result: result,
	                                        kindLabel: kindLabel(for: result.kind, specializationType: result.specializationType)
	                                    )
	                                    .padding(.horizontal, 16)
	                                    .padding(.vertical, 12)
	                                }
	                                .buttonStyle(.plain)

                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.loopedTextSecondary.opacity(0.1))
                            }
                        }
                    }
                    .frame(maxHeight: 230)
                }
            }
            .background(Color.loopedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.loopedTextSecondary.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    func dismissSearch() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            isSearching = false
        }
        isSearchFocused = false
        onDismissSearch()
    }

    func selectSearchResult(_ result: CommunitySearchResult) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        onSelectSearchResult(result)
        dismissSearch()
    }

    func communityLabel(for community: CommunitySummary) -> String {
        CommunityLabelText.preferredName(
            preferShortNames: preferCommunityShortNames,
            name: community.name,
            shortName: community.shortName
        ) ?? community.name
    }

	    func searchResultLabel(for result: CommunitySearchResult) -> String {
	        CommunityLabelText.preferredName(
	            preferShortNames: false,
	            name: result.name,
	            shortName: result.shortName
	        ) ?? result.name
	    }

	    func kindLabel(for kind: CommunityKind, specializationType: CommunitySpecializationType) -> String {
	        switch kind {
	        case .company:
	            return "Company"
	        case .school:
	            return "School"
	        case .specialization:
	            return specializationType.displayName ?? "Specialization"
	        case .unknown:
	            return ""
	        }
	    }
	}

private extension FeedTab {
    var feedMode: FeedMode {
        switch self {
        case .forYou:
            return .forYou
        case .hot:
            return .new
        case .following:
            return .following
        }
    }
}

#Preview {
    VStack {
        FeedHeader()
        FeedTabs(
            isSearching: .constant(false),
            searchQuery: .constant(""),
            communities: [],
            selectedCommunityId: nil,
            onSelectCommunity: { _ in },
            onSelectAll: {},
            onLoadMore: { _ in },
            onSelectMode: { _ in },
            searchResults: [],
            isSearchLoading: false,
            searchErrorMessage: nil,
            onSearchQueryChange: { _ in },
            onSelectSearchResult: { _ in },
            onDismissSearch: {}
        )
        Spacer()
    }
	    .background(Color.loopedBackground.ignoresSafeArea())
	}

private struct CommunitySearchResultRow: View {
    let result: CommunitySearchResult
    let kindLabel: String

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(primaryText)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if !kindLabel.isEmpty {
                        Text(kindLabel)
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)
                            .lineLimit(1)
                    }
                }

                if let secondaryText {
                    Text(secondaryText)
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .lineLimit(1)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private var primaryText: String {
        let trimmedShortName = (result.shortName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedShortName.isEmpty { return trimmedShortName }
        return result.name
    }

    private var secondaryText: String? {
        let trimmedShortName = (result.shortName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedShortName.isEmpty { return result.name }

        let trimmedDescription = result.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDescription.isEmpty { return trimmedDescription }

        return nil
    }

    private var thumbnail: some View {
        Group {
            if let url = resolvedThumbnailURL,
               url.scheme != nil {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.loopedTextSecondary.opacity(0.12), lineWidth: 1)
        )
    }

    private var resolvedThumbnailURL: URL? {
        if let url = URL.loopedMediaURL(from: result.profileDisplayImageUrl) {
            return url
        }
        if let icon = result.icon?.normalizedOrNil(),
           icon.kind == .imageUrl,
           let url = URL.loopedMediaURL(from: icon.value) {
            return url
        }
        return nil
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.loopedMutedBackground)
            .overlay(
                placeholderGlyph
            )
    }

    @ViewBuilder
    private var placeholderGlyph: some View {
        if result.kind == .specialization, let icon = result.icon?.normalizedOrNil() {
            switch icon.kind {
            case .emoji:
                Text(icon.value)
                    .font(.loopedCustom(.semibold, size: 18))
                    .foregroundColor(.loopedTextPrimary)
            case .sfSymbol:
                Image(systemName: icon.value)
                    .font(.loopedCustom(.semibold, size: 14))
                    .foregroundColor(.loopedTextPrimary)
            case .imageUrl:
                Text(initials)
                    .font(.loopedSmallTextMedium)
                    .foregroundColor(.loopedPrimary)
            case .unknown:
                Text(initials)
                    .font(.loopedSmallTextMedium)
                    .foregroundColor(.loopedPrimary)
            }
        } else if result.kind == .specialization {
            Text(initials)
                .font(.loopedSmallTextMedium)
                .foregroundColor(.loopedPrimary)
        } else {
            Text(initials)
                .font(.loopedSmallTextMedium)
                .foregroundColor(.loopedTextSecondary)
        }
    }

    private var initials: String {
        let trimmedShortName = (result.shortName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedShortName.isEmpty {
            return String(trimmedShortName.prefix(2)).uppercased()
        }
        let trimmedName = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = trimmedName.first {
            return String(first).uppercased()
        }
        return "?"
    }
}
