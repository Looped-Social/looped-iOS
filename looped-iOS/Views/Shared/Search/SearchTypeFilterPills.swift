import SwiftUI

struct SearchTypeFilterPills: View {
    let selectedFilter: SearchResultsFilter?
    let onSelect: (SearchResultsFilter?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SearchResultsFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter || (selectedFilter == nil && filter == .all)
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        onSelect(isSelected ? nil : filter)
                    }) {
                        Text(filter.rawValue)
                            .font(isSelected ? .loopedSubBodyBold : .loopedSubBodyMedium)
                            .foregroundColor(isSelected ? .loopedWhite : .loopedTextSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                isSelected
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
    SearchTypeFilterPills(selectedFilter: .companies, onSelect: { _ in })
        .background(Color.loopedBackground)
}
