import SwiftUI

struct SearchBar: View {
    @Binding var searchText: String
    var placeholder: String = "Search"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.loopedTextSecondary)
                .font(.system(size: 16))

            TextField(placeholder, text: $searchText)
                .font(.loopedBody)
                .foregroundColor(.loopedTextPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.loopedMutedBackground)
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