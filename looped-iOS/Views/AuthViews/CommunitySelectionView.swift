import SwiftUI

struct CommunitySelectionView: View {
    let communities: [SearchResultLoop]
    @Binding var searchText: String
    @Binding var selectedIds: Set<UUID>
    let onBack: () -> Void
    let onContinue: ([SearchResultLoop]) -> Void

    private var filteredCommunities: [SearchResultLoop] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return communities }
        let query = trimmed.lowercased()
        return communities.filter { loop in
            loop.name.lowercased().contains(query) || loop.description.lowercased().contains(query)
        }
    }

    private var selectedCommunities: [SearchResultLoop] {
        communities.filter { selectedIds.contains($0.id) }
    }

    private var continueTitle: String {
        selectedIds.isEmpty ? "Continue with no communities" : "Continue"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 8)
                .padding(.horizontal, 16)

            Spacer()
                .frame(height: 16)

            Text("Select communities")
                .font(.loopedHeadingMedium)
                .foregroundColor(.loopedContrast)

            Text("Select as many or as little as you like.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .padding(.top, 6)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.loopedTextSecondary)

                TextField("Search communities", text: $searchText)
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
                    ForEach(filteredCommunities) { community in
                        CommunityRow(
                            community: community,
                            isSelected: selectedIds.contains(community.id)
                        ) {
                            toggleSelection(for: community)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }

            Button(action: { onContinue(selectedCommunities) }) {
                Text(continueTitle)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.loopedPrimary)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.loopedBackground.ignoresSafeArea())
    }

    private func toggleSelection(for community: SearchResultLoop) {
        if selectedIds.contains(community.id) {
            selectedIds.remove(community.id)
        } else {
            selectedIds.insert(community.id)
        }
    }
}

private extension CommunitySelectionView {
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

private struct CommunityRow: View {
    let community: SearchResultLoop
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.loopedMutedBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(initials(for: community.name))
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedContrast)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(community.name)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .loopedPrimary : .loopedTextSecondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.loopedBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color.loopedContrast : Color.loopedTextSecondary.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let initials = parts.prefix(2).compactMap { $0.first }
        return initials.map(String.init).joined().uppercased()
    }
}

#Preview {
    CommunitySelectionView(
        communities: MockSearchContent.communities,
        searchText: .constant(""),
        selectedIds: .constant([]),
        onBack: { },
        onContinue: { _ in }
    )
}
