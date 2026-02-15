import SwiftUI

struct OrganizationDetailSelectionView: View {
    let title: String
    let kind: CommunitySearchKind
    @Binding var searchText: String
    @Binding var selectedItem: CommunitySearchResult?
    let onSelect: (CommunitySearchResult) -> Void
    let onContinue: (CommunitySearchResult) -> Void

    @StateObject private var viewModel: OnboardingSpecializationSelectionViewModel
    @State private var isInfoPresented = false
    @FocusState private var isSearchFieldFocused: Bool

    init(
        title: String,
        kind: CommunitySearchKind,
        searchText: Binding<String>,
        selectedItem: Binding<CommunitySearchResult?>,
        onSelect: @escaping (CommunitySearchResult) -> Void,
        onContinue: @escaping (CommunitySearchResult) -> Void
    ) {
        self.title = title
        self.kind = kind
        _searchText = searchText
        _selectedItem = selectedItem
        self.onSelect = onSelect
        self.onContinue = onContinue
        _viewModel = StateObject(wrappedValue: OnboardingSpecializationSelectionViewModel(kind: kind))
    }

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: isSearchFieldFocused ? 6 : 12)

                if !isSearchFieldFocused {
                    Text(title)
                        .font(.loopedHeadingMedium)
                        .foregroundColor(.loopedContrast)

                    Text(inlineHelperText)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.top, 6)

                    Button(action: { isInfoPresented = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.loopedCustom(.medium, size: 13))
                            Text("More info")
                                .font(.loopedSmallText)
                        }
                        .foregroundColor(.loopedTextSecondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.loopedCustom(.medium, size: 16))
                        .foregroundColor(.loopedTextSecondary)

                    TextField("Search", text: $searchText)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                        .tint(.loopedPrimary)
                        .focused($isSearchFieldFocused)
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
                                isSearchFieldFocused = false
                                selectedItem = result
                                onSelect(result)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, (selectedItem == nil || isSearchFieldFocused) ? 20 : 100)
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
        .safeAreaInset(edge: .bottom) {
            if let selectedItem, !isSearchFieldFocused {
                PrimaryButton(title: "Continue") {
                    onContinue(selectedItem)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color.loopedBackground)
            }
        }
        .alert("About your choice", isPresented: $isInfoPresented) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text(infoText)
        }
    }
}

private extension OrganizationDetailSelectionView {
    var inlineHelperText: String {
        switch kind {
        case .field:
            return "Looped has field specializations. You must join one to post in it."
        case .major:
            return "Looped has major specializations. You must join one to post in it."
        default:
            return "You must join a specialization to post in it."
        }
    }

    var infoText: String {
        "Workplace verification lets you join up to 2 fields. School verification lets you join up to 2 majors. During onboarding we only follow this specialization to tailor content; you can join after onboarding."
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
            onSelect: { _ in },
            onContinue: { _ in }
        )
    }
}
