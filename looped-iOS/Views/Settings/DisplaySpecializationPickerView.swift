import SwiftUI

struct DisplaySpecializationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSpecialization: DisplayCommunity?
    @StateObject private var viewModel: DisplaySpecializationPickerViewModel
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var filter: SpecializationFilter
    @State private var communityToView: CommunityProfileData?
    private let title: String

    init(
        selectedSpecialization: Binding<DisplayCommunity?>,
        title: String = "Majors & Fields",
        communityService: CommunityServiceProtocol = CommunityService(),
        discoveryService: DiscoveryServiceProtocol = DiscoveryService()
    ) {
        _selectedSpecialization = selectedSpecialization
        self.title = title
        let initialFilter = SpecializationFilter.from(selectedSpecialization.wrappedValue?.specializationType) ?? .major
        _filter = State(initialValue: initialFilter)
        _viewModel = StateObject(
            wrappedValue: DisplaySpecializationPickerViewModel(
                communityService: communityService,
                discoveryService: discoveryService
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                searchField

                Picker("Type", selection: $filter) {
                    ForEach(SpecializationFilter.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                content

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    LoopedCancelTextButton(action: { dismiss() })
                }
                if selectedSpecialization != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Clear") {
                            selectedSpecialization = nil
                            dismiss()
                        }
                        .foregroundColor(.loopedSecondary)
                    }
                }
            }
            .onAppear {
                scheduleSearch(immediate: true)
            }
            .onDisappear {
                searchTask?.cancel()
            }
            .onChange(of: searchText) { _, _ in
                scheduleSearch()
            }
            .onChange(of: filter) { _, _ in
                scheduleSearch(immediate: true)
            }
            .sheet(item: $communityToView, onDismiss: {
                scheduleSearch(immediate: true)
            }) { community in
                NavigationStack {
                    CommunityProfileView(community: community)
                }
            }
            .background(Color.loopedBackground.ignoresSafeArea())
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.loopedCustom(size: 14))
                .foregroundColor(.loopedTextSecondary)

            TextField("Search majors or fields", text: $searchText)
                .font(.loopedBody)
                .foregroundColor(.loopedTextPrimary)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.loopedMutedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            HStack(spacing: 8) {
                ProgressView()
                Text("Loading specializations...")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedError)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if viewModel.results.isEmpty {
            Text(emptyStateText)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.results) { result in
                        SpecializationResultRow(
                            result: result,
                            isSelected: result.id == selectedSpecialization?.id,
                            onSelect: { select(result) }
                        )
                        .onAppear {
                            Task {
                                await viewModel.loadMoreIfNeeded(
                                    currentId: result.id,
                                    query: searchText,
                                    filter: filter
                                )
                            }
                        }

                        if result.id != viewModel.results.last?.id {
                            Divider()
                        }
                    }

                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private var emptyStateText: String {
        let trimmed = DisplaySpecializationPickerViewModel.normalizedQuery(searchText)
        if trimmed.isEmpty {
            return "Browse majors and fields to join and display on your profile."
        }
        return "No specializations found."
    }

    private func scheduleSearch(immediate: Bool = false) {
        searchTask?.cancel()
        let query = searchText
        let requestedFilter = filter
        searchTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            guard !Task.isCancelled else { return }
            await viewModel.reload(query: query, filter: requestedFilter)
        }
    }

    private func select(_ result: CommunitySearchResult) {
        guard result.kind == .specialization else { return }
        guard result.specializationType != .unknown else { return }
        if result.isJoined != true {
            communityToView = CommunityProfileData(community: result)
            return
        }
        selectedSpecialization = DisplayCommunity(
            id: result.id,
            name: result.name,
            shortName: result.shortName,
            kind: result.kind,
            specializationType: result.specializationType == .unknown ? nil : result.specializationType,
            icon: result.icon?.normalizedOrNil()
        )
        dismiss()
    }
}

private struct SpecializationResultRow: View {
    let result: CommunitySearchResult
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                specializationGlyph

                VStack(alignment: .leading, spacing: 2) {
                    Text(specializationLabel)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    if let label = result.specializationType.displayName {
                        Text(label)
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }

                Spacer()

                if result.isJoined == true {
                    Text("Joined")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.loopedMutedBackground)
                        .clipShape(Capsule())
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.loopedPrimary)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var specializationLabel: String {
        CommunityLabelText.preferredName(
            preferShortNames: false,
            name: result.name,
            shortName: result.shortName
        ) ?? result.name
    }

    @ViewBuilder
    private var specializationGlyph: some View {
        Group {
            if let icon = result.icon?.normalizedOrNil() {
                switch icon.kind {
                case .emoji:
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.loopedMutedBackground)
                        .overlay(
                            Text(icon.value)
                                .font(.loopedCustom(.semibold, size: 18))
                                .foregroundColor(.loopedTextPrimary)
                        )
                case .sfSymbol:
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.loopedMutedBackground)
                        .overlay(
                            Image(systemName: icon.value)
                                .font(.loopedCustom(.semibold, size: 16))
                                .foregroundColor(.loopedTextPrimary)
                        )
                case .imageUrl:
                    if let url = URL.loopedMediaURL(from: icon.value) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure, .empty:
                                initialsGlyph
                            @unknown default:
                                initialsGlyph
                            }
                        }
                    } else {
                        initialsGlyph
                    }
                case .unknown:
                    initialsGlyph
                }
            } else {
                initialsGlyph
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var initialsGlyph: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.loopedMutedBackground)
            .overlay(
                Text(initials(for: specializationLabel))
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedTextPrimary)
            )
    }

    private func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }
}
