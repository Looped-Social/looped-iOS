import SwiftUI

struct OrganizationDetailSelectionView: View {
    let title: String
    let items: [String]
    @Binding var searchText: String
    @Binding var selectedItem: String?
    let onSelect: (String) -> Void
    let onBack: () -> Void

    private var filteredItems: [String] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        let query = trimmed.lowercased()
        return items.filter { $0.lowercased().contains(query) }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                    .padding(.horizontal, 16)

                Spacer()
                    .frame(height: geometry.size.height * 0.08)

                Text(title)
                    .font(.loopedHeadingMedium)
                    .foregroundColor(.loopedContrast)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.loopedTextSecondary)

                    TextField("", text: $searchText)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.loopedMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(22)
                .padding(.horizontal, 32)
                .padding(.top, 16)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredItems, id: \.self) { item in
                            OrganizationDetailRow(title: item, isSelected: item == selectedItem) {
                                selectedItem = item
                                onSelect(item)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.loopedBackground.ignoresSafeArea())
        }
    }
}

private extension OrganizationDetailSelectionView {
    var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.loopedTextPrimary)
                    .frame(width: 40, height: 40)
            }
            Spacer()
        }
    }
}

private struct OrganizationDetailRow: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(title)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.loopedPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.loopedBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color.loopedPrimary : Color.loopedTextSecondary.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    OrganizationDetailSelectionView(
        title: "Department",
        items: MockOnboardingDetails.departments,
        searchText: .constant(""),
        selectedItem: .constant(nil),
        onSelect: { _ in },
        onBack: { }
    )
}
