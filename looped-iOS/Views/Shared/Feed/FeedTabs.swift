import SwiftUI

enum FeedTab: String, CaseIterable {
    case forYou = "For You"
    case hot = "Latest"
}

struct FeedTabs: View {
    @State private var selectedTab: FeedTab = .forYou
    @State private var isPlus: Bool = false

    let communities: [CommunitySummary]
    let selectedCommunityId: Int?
    let onSelectCommunity: (CommunitySummary) -> Void
    let onSelectAll: () -> Void
    let onLoadMore: (CommunitySummary) -> Void
    let onSelectMode: (FeedMode) -> Void
    
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
            
            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    // Plus/Minus toggle button
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isPlus.toggle()
                        }
                    }) {
                        ZStack {
                            // Horizontal line (always visible)
                            RoundedRectangle(cornerRadius: 1.5)
                                .frame(width: 25, height: 3)
                                .foregroundColor(.loopedSecondary)

                            // Vertical line (only visible for plus)
                            if isPlus {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .frame(width: 3, height: 25)
                                    .foregroundColor(.loopedSecondary)
                            }
                        }
                        .frame(width: 16)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if !isPlus {
                        Group {
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
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 28)
            .padding(.vertical, 8)
            .coachMarkTarget(.feedFilterPills)
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
            communities: [],
            selectedCommunityId: nil,
            onSelectCommunity: { _ in },
            onSelectAll: {},
            onLoadMore: { _ in },
            onSelectMode: { _ in }
        )
        Spacer()
    }
    .background(Color.loopedBackground.ignoresSafeArea())
}
