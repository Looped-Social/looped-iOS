import SwiftUI

// MARK: - Organization Selection View

struct OrganizationSelectionView: View {
    let title: String
    let scope: OnboardingOrganizationSearchViewModel.Scope
    @Binding var searchText: String
    let selectedOrganizationId: UUID?
    let onSelect: (Organization) -> Void
    let onNavigate: (AuthScreen) -> Void

    @StateObject private var viewModel: OnboardingOrganizationSearchViewModel
    @State private var isInfoPresented = false

    init(
        title: String,
        scope: OnboardingOrganizationSearchViewModel.Scope,
        searchText: Binding<String>,
        selectedOrganizationId: UUID?,
        onSelect: @escaping (Organization) -> Void,
        onNavigate: @escaping (AuthScreen) -> Void
    ) {
        self.title = title
        self.scope = scope
        _searchText = searchText
        self.selectedOrganizationId = selectedOrganizationId
        self.onSelect = onSelect
        self.onNavigate = onNavigate
        _viewModel = StateObject(wrappedValue: OnboardingOrganizationSearchViewModel(scope: scope))
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 12)

                Text(title)
                    .font(.loopedHeadingMedium)
                    .foregroundColor(.loopedContrast)
                    .multilineTextAlignment(.center)

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
                        if viewModel.isLoading, viewModel.organizations.isEmpty {
                            ProgressView()
                                .tint(.loopedPrimary)
                                .padding(.top, 24)
                        }

                        if !viewModel.isLoading, viewModel.organizations.isEmpty {
                            Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "Start typing to search."
                                : "No matches found."
                            )
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 24)
                        }

	                        ForEach(viewModel.organizations) { organization in
	                            OrganizationListRow(
	                                organization: organization,
	                                isSelected: organization.id == selectedOrganizationId
	                            ) {
	                                onSelect(organization)
	                                onNavigate(organization.kind == .school ? .degreeSelection : .departmentSelection)
	                            }
	                        }
	                    }
	                    .padding(.horizontal, 24)
	                    .padding(.top, 20)
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
            Text("If you work and go to school, no worries — you can verify additional communities later. Pick the one you want to feature on your profile for now. You can always change this later.")
        }
    }
}

private struct OrganizationListRow: View {
    let organization: Organization
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.loopedMutedBackground)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(organization.logoText)
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedContrast)
                    )

                Text(organization.name)
                    .font(.loopedBodyMedium)
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
        OrganizationSelectionView(
            title: "Where do you work?",
            scope: .companiesOnly,
            searchText: .constant(""),
            selectedOrganizationId: nil,
            onSelect: { _ in },
            onNavigate: { _ in }
        )
    }
}
