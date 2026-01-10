import SwiftUI

enum FeedTab: String, CaseIterable {
    case forYou = "For You"
    case hot = "Latest"
}

struct FeedTabs: View {
    @State private var selectedTab: FeedTab = .forYou
    @Binding var isSearching: Bool
    @Binding var searchQuery: String
    @FocusState private var isSearchFocused: Bool

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
            // Tab selector (For You / Latest)
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
                    // For You underline
                    Rectangle()
                        .frame(height: selectedTab == .forYou ? 2 : 1)
                        .foregroundColor(selectedTab == .forYou ? .loopedPrimary : .loopedTextSecondary.opacity(0.3))
                    
                    // Latest underline
                    Rectangle()
                        .frame(height: selectedTab == .hot ? 2 : 1)
                        .foregroundColor(selectedTab == .hot ? .loopedPrimary : .loopedTextSecondary.opacity(0.3))
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
                        Text(community.name)
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

                Button(action: dismissSearch) {
                    Text("Cancel")
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedPrimary)
                }
                .buttonStyle(.plain)
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
                    Text("Start typing to search.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
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
                                    HStack(spacing: 10) {
                                        Text(result.name)
                                            .font(.loopedBody)
                                            .foregroundColor(.loopedTextPrimary)
                                            .lineLimit(1)

                                        Spacer(minLength: 8)

                                        Text(kindLabel(for: result.kind))
                                            .font(.loopedSmallText)
                                            .foregroundColor(.loopedTextSecondary)
                                    }
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

    func kindLabel(for kind: CommunityKind) -> String {
        switch kind {
        case .company:
            return "Company"
        case .school:
            return "School"
        case .profession:
            return "Profession"
        case .sector:
            return "Sector"
        case .specialization:
            return "Specialization"
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
