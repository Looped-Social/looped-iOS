import SwiftUI

struct CommunityFilterTabs: View {
    let communities: [CommunitySummary]
    let selectedCommunityId: Int?
    let onSelectCommunity: (CommunitySummary) -> Void
    let onSelectAll: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    onSelectAll()
                }) {
                    Text("All Communities")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedCommunityId == nil ? .white : .loopedTextSecondary)
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
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedCommunityId == community.id ? .white : .loopedTextSecondary)
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
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    CommunityFilterTabs(
        communities: [
            CommunitySummary(id: 1, name: "Design", kind: .company, memberCount: 12, isPinned: false, sortOrder: nil, canPost: true),
            CommunitySummary(id: 2, name: "Engineering", kind: .company, memberCount: 40, isPinned: false, sortOrder: nil, canPost: true)
        ],
        selectedCommunityId: nil,
        onSelectCommunity: { _ in },
        onSelectAll: {}
    )
    .background(Color.loopedBackground)
}
