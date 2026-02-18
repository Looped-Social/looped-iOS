import SwiftUI

struct OrganizationDetailSelectionView: View {
    let title: String
    let kind: CommunitySearchKind
    @Binding var searchText: String
    @Binding var selectedItems: [CommunitySearchResult]
    let maxSelections: Int
    let onSelect: ([CommunitySearchResult]) -> Void
    let onContinue: ([CommunitySearchResult]) -> Void

    @StateObject private var viewModel: OnboardingSpecializationSelectionViewModel
    @State private var isInfoPresented = false
    @State private var selectionErrorMessage: String?
    @FocusState private var isSearchFieldFocused: Bool

    init(
        title: String,
        kind: CommunitySearchKind,
        searchText: Binding<String>,
        selectedItems: Binding<[CommunitySearchResult]>,
        maxSelections: Int = 2,
        onSelect: @escaping ([CommunitySearchResult]) -> Void,
        onContinue: @escaping ([CommunitySearchResult]) -> Void
    ) {
        self.title = title
        self.kind = kind
        _searchText = searchText
        _selectedItems = selectedItems
        self.maxSelections = max(1, maxSelections)
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
                                isSelected: isSelected(result.id),
                                selectionOrder: selectionOrder(for: result.id)
                            ) {
                                isSearchFieldFocused = false
                                toggleSelection(result)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, (selectedItems.isEmpty || isSearchFieldFocused) ? 20 : 100)
                }

                if let selectionErrorMessage, !isSearchFieldFocused {
                    Text(selectionErrorMessage)
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedError)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.loopedBackground.ignoresSafeArea())
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(
            NavigationPopGestureDisabler(isEnabled: false)
                .frame(width: 0, height: 0)
        )
        .onAppear {
            viewModel.query = searchText
            viewModel.refresh()
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.query = newValue
        }
        .safeAreaInset(edge: .bottom) {
            if !selectedItems.isEmpty, !isSearchFieldFocused {
                PrimaryButton(title: "Continue") {
                    onContinue(selectedItems)
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
            return "Select up to 2 fields to join now."
        case .major:
            return "Select up to 2 majors to join now."
        default:
            return "Select up to 2 specializations to join now."
        }
    }

    var infoText: String {
        "Workplace verification lets you join up to 2 fields. School verification lets you join up to 2 majors."
    }

    func isSelected(_ specializationId: Int) -> Bool {
        selectedItems.contains(where: { $0.id == specializationId })
    }

    func selectionOrder(for specializationId: Int) -> Int? {
        selectedItems.firstIndex(where: { $0.id == specializationId }).map { $0 + 1 }
    }

    func toggleSelection(_ result: CommunitySearchResult) {
        if let existingIndex = selectedItems.firstIndex(where: { $0.id == result.id }) {
            selectedItems.remove(at: existingIndex)
            selectionErrorMessage = nil
            onSelect(selectedItems)
            return
        }

        guard selectedItems.count < maxSelections else {
            selectionErrorMessage = "You can select up to \(maxSelections)."
            return
        }

        selectedItems.append(result)
        selectionErrorMessage = nil
        onSelect(selectedItems)
    }
}

private struct OrganizationDetailRow: View {
    let title: String
    let isSelected: Bool
    let selectionOrder: Int?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(title)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                if isSelected {
                    if let selectionOrder {
                        ZStack {
                            Circle()
                                .fill(Color.loopedPrimary)
                                .frame(width: 22, height: 22)
                            Text("\(selectionOrder)")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedBackground)
                        }
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.loopedCustom(.semibold, size: 18))
                            .foregroundColor(.loopedPrimary)
                    }
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
            selectedItems: .constant([]),
            onSelect: { _ in },
            onContinue: { _ in }
        )
    }
}
