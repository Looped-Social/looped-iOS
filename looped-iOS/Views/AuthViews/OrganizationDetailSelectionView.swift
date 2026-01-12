import SwiftUI

struct OrganizationDetailSelectionView: View {
    let title: String
    let kind: CommunitySearchKind
    @Binding var searchText: String
    @Binding var selectedItem: CommunitySearchResult?
    let onSelect: (CommunitySearchResult) -> Void
    let onBack: () -> Void

    @StateObject private var viewModel: OnboardingSpecializationSelectionViewModel
    @State private var isInfoPresented = false

    init(
        title: String,
        kind: CommunitySearchKind,
        searchText: Binding<String>,
        selectedItem: Binding<CommunitySearchResult?>,
        onSelect: @escaping (CommunitySearchResult) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.title = title
        self.kind = kind
        _searchText = searchText
        _selectedItem = selectedItem
        self.onSelect = onSelect
        self.onBack = onBack
        _viewModel = StateObject(wrappedValue: OnboardingSpecializationSelectionViewModel(kind: kind))
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                    .padding(.horizontal, 16)

                Spacer()
                    .frame(height: 24)

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
                                title: result.name,
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

    var infoText: String {
        switch kind {
        case .department:
            return "Pick the department you want featured on your profile. You can update this later."
        case .major:
            return "Pick the major you want featured on your profile. You can update this later."
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
    OrganizationDetailSelectionView(
        title: "Department",
        kind: .department,
        searchText: .constant(""),
        selectedItem: .constant(nil as CommunitySearchResult?),
        onSelect: { _ in },
        onBack: { }
    )
}
