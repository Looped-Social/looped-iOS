import SwiftUI

struct SearchBar: View {
    @Binding var searchText: String
    var placeholder: String = "Search"

    var body: some View {
        HStack(spacing: 8) {
            // Hide magnifying glass when text is empty to center placeholder
            if !searchText.isEmpty {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.loopedTextSecondary)
                    .font(.system(size: 16))
            }

            TextField("", text: $searchText)
                .font(.loopedBody)
                .foregroundColor(.loopedTextPrimary)
                .multilineTextAlignment(searchText.isEmpty ? .center : .leading)
                .overlay(
                    // Custom centered placeholder when empty
                    Group {
                        if searchText.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.loopedTextSecondary)
                                    .font(.system(size: 16))
                                Text(placeholder)
                                    .font(.loopedBody)
                                    .foregroundColor(.loopedTextSecondary)
                            }
                        }
                    }
                )

            if !searchText.isEmpty {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

#Preview {
    @State var searchText = ""

    return VStack {
        SearchBar(searchText: $searchText)
        Spacer()
    }
    .background(Color.loopedBackground)
}