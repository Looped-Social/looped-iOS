import SwiftUI

// MARK: - Organization Selection View

struct OrganizationSelectionView: View {
    let title: String
    let scope: OnboardingOrganizationSearchViewModel.Scope
    @Binding var searchText: String
    let selectedOrganizationId: UUID?
    let onSelect: (Organization) -> Void
    let onContinue: (Organization) -> Void
    let onRequestCommunityCompletion: () async -> Bool

    @StateObject private var viewModel: OnboardingOrganizationSearchViewModel
    @State private var isInfoPresented = false
    @State private var isCommunityRequestPresented = false
    @State private var pendingSelection: Organization?
    @FocusState private var isSearchFieldFocused: Bool

    init(
        title: String,
        scope: OnboardingOrganizationSearchViewModel.Scope,
        searchText: Binding<String>,
        selectedOrganizationId: UUID?,
        onSelect: @escaping (Organization) -> Void,
        onContinue: @escaping (Organization) -> Void,
        onRequestCommunityCompletion: @escaping () async -> Bool = { false }
    ) {
        self.title = title
        self.scope = scope
        _searchText = searchText
        self.selectedOrganizationId = selectedOrganizationId
        self.onSelect = onSelect
        self.onContinue = onContinue
        self.onRequestCommunityCompletion = onRequestCommunityCompletion
        _viewModel = StateObject(wrappedValue: OnboardingOrganizationSearchViewModel(scope: scope))
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
                        .multilineTextAlignment(.center)

                    Text("If you're in multiple workplaces, choose one for now. You can verify others later.")
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
                    VStack(spacing: 6) {
                        Text(error)
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedError)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            viewModel.refresh()
                        }
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedPrimary)
                        .buttonStyle(.plain)
                    }
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

                            if viewModel.hasNoResultsForActiveQuery {
                                VStack(spacing: 8) {
                                    Text("Don't see your community?")
                                        .font(.loopedSubBodyMedium)
                                        .foregroundColor(.loopedTextSecondary)
                                        .multilineTextAlignment(.center)

                                    Text("No worries. Request it here and we'll be on it.")
                                        .font(.loopedSmallText)
                                        .foregroundColor(.loopedTextSecondary)
                                        .multilineTextAlignment(.center)

                                    Button {
                                        isCommunityRequestPresented = true
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.loopedSymbol(.medium, size: 16))
                                            Text("Request your community")
                                                .font(.loopedBodyMedium)
                                        }
                                        .foregroundColor(.loopedWhite)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 46)
                                        .background(Color.loopedPrimary)
                                        .cornerRadius(14)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.top, 8)
                                .padding(.horizontal, 8)
                            }
                        }

                        ForEach(viewModel.organizations) { organization in
                            OrganizationListRow(
                                organization: organization,
                                isSelected: organization.id == resolvedSelection?.id
                            ) {
                                isSearchFieldFocused = false
                                pendingSelection = organization
                                onSelect(organization)
                            }
                        }
	                    }
	                    .padding(.horizontal, 24)
	                    .padding(.top, 20)
                        .padding(.bottom, (resolvedSelection == nil || isSearchFieldFocused) ? 20 : 100)
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
        .onChange(of: selectedOrganizationId) { _, newValue in
            guard pendingSelection?.id != newValue else { return }
            pendingSelection = nil
        }
        .safeAreaInset(edge: .bottom) {
            if let selection = resolvedSelection, !isSearchFieldFocused {
                PrimaryButton(title: "Continue") {
                    onContinue(selection)
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
            Text("You can only post in communities where you're verified. We'll ask you to verify next, so choose one where you can verify with a work email or ID/badge.")
        }
        .fullScreenCover(isPresented: $isCommunityRequestPresented) {
            CommunityRequestFlowView(
                mode: .onboarding,
                initialName: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
                suggestedKind: scope.preferredRequestKind,
                onOnboardingExploreApp: onRequestCommunityCompletion
            )
        }
    }

    private var resolvedSelection: Organization? {
        if let pendingSelection {
            return pendingSelection
        }
        guard let selectedOrganizationId else { return nil }
        return viewModel.organizations.first(where: { $0.id == selectedOrganizationId })
    }
}

private struct OrganizationListRow: View {
    let organization: Organization
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                avatarView

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

    @ViewBuilder
    var avatarView: some View {
        let trimmed = (organization.imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), !trimmed.isEmpty, url.scheme != nil {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure, .empty:
                    placeholderAvatar
                @unknown default:
                    placeholderAvatar
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
        } else {
            placeholderAvatar
        }
    }

    var placeholderAvatar: some View {
        Circle()
            .fill(Color.loopedMutedBackground)
            .frame(width: 48, height: 48)
            .overlay(
                Text(organization.logoText)
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedContrast)
            )
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
            onContinue: { _ in }
        )
    }
}
