import SwiftUI

struct RecentSearchItem: View {
    let query: String
    let onTap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack {
                    Text(query)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.loopedTextSecondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct RecentSearchesSection: View {
    let recentSearches: [String]
    let onSearchTap: (String) -> Void
    let onRemoveSearch: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(recentSearches, id: \.self) { query in
                RecentSearchItem(
                    query: query,
                    onTap: {
                        onSearchTap(query)
                    },
                    onRemove: {
                        onRemoveSearch(query)
                    }
                )

                if query != recentSearches.last {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        RecentSearchesSection(
            recentSearches: [
                "elevator broken",
                "Lunch Break Shortened",
                "#interns"
            ],
            onSearchTap: { _ in },
            onRemoveSearch: { _ in }
        )
    }
    .background(Color.loopedBackground)
}
