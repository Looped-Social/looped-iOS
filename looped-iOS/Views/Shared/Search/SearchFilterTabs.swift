import SwiftUI

struct SearchFilterTabs: View {
    @Binding var selectedFilter: SearchFilter
    let onFilterChange: (SearchFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SearchFilter.allCases, id: \.self) { filter in
                    FilterTab(
                        title: filter.displayName,
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
    @State var selectedFilter: SearchFilter = .jpMorgan

    return VStack(spacing: 20) {
        SearchFilterTabs(
            selectedFilter: $selectedFilter,
            onFilterChange: { filter in
                print("Selected filter: \(filter)")
            }
        )

        Text("Selected: \(selectedFilter.rawValue)")
    }
    .background(Color.loopedBackground)
}
