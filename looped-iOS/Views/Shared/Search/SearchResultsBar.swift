import SwiftUI

struct SearchResultsBar: View {
    @Binding var searchText: String
    var placeholder: String = "Search"
    let onCancel: () -> Void
    @FocusState.Binding var isSearchFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Search Bar with red border
            HStack(spacing: 8) {
                // Hide magnifying glass when text is empty to center placeholder
                if !searchText.isEmpty {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.loopedTextSecondary)
                        .font(.loopedCustom(size: 16))
                }

                TextField("", text: $searchText)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)
                    .multilineTextAlignment(searchText.isEmpty ? .center : .leading)
                    .focused($isSearchFieldFocused)
                    .overlay(
                        // Custom centered placeholder when empty
                        Group {
                            if searchText.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.loopedTextSecondary)
                                        .font(.loopedCustom(size: 16))
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
            .background(Color.loopedGray.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.loopedContrast, lineWidth: 3)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Cancel Button
            LoopedCancelTextButton(action: onCancel)
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    @Previewable @State var searchText = "Test"
    @Previewable @FocusState var isSearchFieldFocused: Bool

    return VStack {
        SearchResultsBar(
            searchText: $searchText,
            placeholder: "Search in JP Morgan",
            onCancel: {},
            isSearchFieldFocused: $isSearchFieldFocused
        )

        Spacer()
    }
    .background(Color.loopedBackground)
}
