import SwiftUI

struct SearchFilterTabs: View {
    let filters: [SearchFilterOption]
    @Binding var selectedFilter: SearchFilterOption
    let onFilterChange: (SearchFilterOption) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filters) { filter in
                    FilterTab(
                        title: filter.title,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                        onFilterChange(filter)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct FilterTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.loopedBodyMedium)
                .foregroundColor(isSelected ? .white : .loopedTextPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.loopedPrimary : Color.loopedMutedBackground)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    @State var selectedFilter: SearchFilterOption = MockSearchContent.filterOptions[1]

    return VStack(spacing: 20) {
        SearchFilterTabs(
            filters: MockSearchContent.filterOptions,
            selectedFilter: $selectedFilter,
            onFilterChange: { filter in
                print("Selected filter: \(filter.title)")
            }
        )

        Text("Selected: \(selectedFilter.title)")
    }
    .background(Color.loopedBackground)
}
