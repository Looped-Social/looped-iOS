import SwiftUI

struct OrganizationDetailSelectionView: View {
    let title: String
    let kind: CommunitySearchKind
    @Binding var searchText: String
    @Binding var selectedItem: CommunitySearchResult?
    let onSelect: (CommunitySearchResult) -> Void

    @StateObject private var viewModel: OnboardingSpecializationSelectionViewModel
    @State private var isInfoPresented = false

    init(
        title: String,
        kind: CommunitySearchKind,
        searchText: Binding<String>,
        selectedItem: Binding<CommunitySearchResult?>,
        onSelect: @escaping (CommunitySearchResult) -> Void
    ) {
        self.title = title
        self.kind = kind
        _searchText = searchText
        _selectedItem = selectedItem
        self.onSelect = onSelect
        _viewModel = StateObject(wrappedValue: OnboardingSpecializationSelectionViewModel(kind: kind))
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 12)

                Text(title)
                    .font(.loopedHeadingMedium)
                    .foregroundColor(.loopedContrast)

                Button(action: { isInfoPresented = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.loopedCustom(.medium, size: 13))
                        Text("Why am I choosing this?")
                            .font(.loopedSmallText)
                    }
                    .foregroundColor(.loopedTextSecondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.loopedCustom(.medium, size: 16))
                        .foregroundColor(.loopedTextSecondary)

                    TextField("Search", text: $searchText)
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
                        if viewModel.isLoading, viewModel.results.isEmpty {
                            ProgressView()
                                .tint(.loopedPrimary)
                                .padding(.top, 24)
                        }

                        if !viewModel.isLoading, viewModel.results.isEmpty {
                            Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "Start typing to search."
                                : "No matches found."
                            )
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 24)
                        }

                        ForEach(viewModel.results) { result in
                            OrganizationDetailRow(
                                title: CommunityLabelText.preferredName(
                                    preferShortNames: false,
                                    name: result.name,
                                    shortName: result.shortName
                                ) ?? result.name,
                                isSelected: result.id == selectedItem?.id
                            ) {
                                selectedItem = result
                                onSelect(result)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.query = searchText
            viewModel.refresh()
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.query = newValue
        }
        .alert("About your choice", isPresented: $isInfoPresented) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text(infoText)
        }
    }
}

private extension OrganizationDetailSelectionView {
    var infoText: String {
        switch kind {
        case .field:
            return "Follow a field to personalize your experience. You can change this later."
        case .major:
            return "Follow a major to personalize your experience. You can change this later."
        default:
            return "Pick what you want featured on your profile. You can update this later."
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
                        .font(.loopedCustom(.semibold, size: 18))
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
    NavigationStack {
        OrganizationDetailSelectionView(
            title: "Field",
            kind: .field,
            searchText: .constant(""),
            selectedItem: .constant(nil as CommunitySearchResult?),
            onSelect: { _ in }
        )
    }
}
