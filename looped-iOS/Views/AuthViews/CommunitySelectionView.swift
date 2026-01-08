import SwiftUI

struct CommunitySelectionView: View {
    let recommendedKind: CommunitySearchKind?
    @Binding var searchText: String
    @Binding var selectedIds: Set<UUID>
    let onBack: () -> Void
    let onContinue: ([SearchResultLoop]) -> Void

    @StateObject private var viewModel: OnboardingCommunitySelectionViewModel
    @State private var selectedLookup: [UUID: SearchResultLoop] = [:]

    private var selectedCommunities: [SearchResultLoop] {
        if selectedLookup.isEmpty {
            return viewModel.communities.filter { selectedIds.contains($0.id) }
        }
        return selectedLookup.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var continueTitle: String {
        selectedIds.isEmpty ? "Continue with no communities" : "Continue"
    }

    init(
        recommendedKind: CommunitySearchKind? = nil,
        searchText: Binding<String>,
        selectedIds: Binding<Set<UUID>>,
        onBack: @escaping () -> Void,
        onContinue: @escaping ([SearchResultLoop]) -> Void
    ) {
        self.recommendedKind = recommendedKind
        _searchText = searchText
        _selectedIds = selectedIds
        self.onBack = onBack
        self.onContinue = onContinue
        _viewModel = StateObject(wrappedValue: OnboardingCommunitySelectionViewModel(recommendedKind: recommendedKind))
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
                    .font(.loopedCustom(.medium, size: 16))
                    .foregroundColor(.loopedTextSecondary)

                TextField("Search communities", text: $searchText)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)
                    .tint(.loopedPrimary)
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

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedError)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 10)
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.isLoading, viewModel.communities.isEmpty {
                        ProgressView()
                            .tint(.loopedPrimary)
                            .padding(.top, 24)
                    }

                    if !viewModel.isLoading, viewModel.communities.isEmpty {
                        Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Start typing to search."
                            : "No matches found."
                        )
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 24)
                    }

                    ForEach(viewModel.communities) { community in
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
                    .foregroundColor(.loopedWhite)
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
        .onAppear {
            viewModel.query = searchText
            viewModel.refresh()
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.query = newValue
        }
    }

    private func toggleSelection(for community: SearchResultLoop) {
        if selectedIds.contains(community.id) {
            selectedIds.remove(community.id)
            selectedLookup.removeValue(forKey: community.id)
        } else {
            selectedIds.insert(community.id)
            selectedLookup[community.id] = community
        }
    }
}

private extension CommunitySelectionView {
    var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.loopedCustom(.semibold, size: 20))
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
                    .font(.loopedCustom(size: 20))
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
        recommendedKind: nil,
        searchText: .constant(""),
        selectedIds: .constant([]),
        onBack: { },
        onContinue: { _ in }
    )
}
