import SwiftUI

struct MessagesSearchBar: View {
    @Binding var searchText: String
    var placeholder: String = "Search"

    var body: some View {
        HStack(spacing: 8) {
            // Search icon on the left
            Image(systemName: "magnifyingglass")
                .foregroundColor(.loopedTextSecondary)
                .font(.loopedCustom(size: 16))

            // Search text field
            TextField(placeholder, text: $searchText)
                .font(.loopedBody)
                .foregroundColor(.loopedTextPrimary)

            // Clear button (only show when there's text)
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.loopedTextSecondary)
                        .font(.loopedCustom(size: 16))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.loopedTextSecondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
    }
}

#Preview {
    @Previewable @State var searchText = ""

    return VStack {
        MessagesSearchBar(searchText: $searchText, placeholder: "Search")
        Spacer()
    }
    .background(Color.loopedBackground)
}
