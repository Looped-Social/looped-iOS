import SwiftUI

struct DisplaySpecializationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSpecialization: DisplayCommunity?
    @State private var searchText = ""
    @State private var results: [CommunitySearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var alertMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var filter: SpecializationFilter
    @State private var communityToView: CommunityProfileData?

    private let communityService: CommunityServiceProtocol

    init(
        selectedSpecialization: Binding<DisplayCommunity?>,
        communityService: CommunityServiceProtocol = CommunityService()
    ) {
        _selectedSpecialization = selectedSpecialization
        self.communityService = communityService
        let initialFilter = SpecializationFilter.from(selectedSpecialization.wrappedValue?.specializationType) ?? .major
        _filter = State(initialValue: initialFilter)
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
            .navigationTitle("Display Specialization")
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
            .onChange(of: searchText) { _, _ in
                scheduleSearch()
            }
            .onChange(of: filter) { _, _ in
                scheduleSearch()
            }
            .sheet(item: $communityToView, onDismiss: {
                scheduleSearch()
            }) { community in
                CommunityProfileView(community: community)
            }
            .alert(
                "Join Required",
                isPresented: Binding(
                    get: { alertMessage != nil },
                    set: { if !$0 { alertMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "")
            }
            .background(Color.loopedBackground.ignoresSafeArea())
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.loopedCustom(.medium, size: 16))
                .foregroundColor(.loopedTextSecondary)

            TextField("Search majors or departments", text: $searchText)
                .font(.loopedBody)
                .foregroundColor(.loopedTextPrimary)
                .textInputAutocapitalization(.words)
        }
        .padding(12)
        .background(Color.loopedTextSecondary.opacity(0.1))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            HStack(spacing: 8) {
                ProgressView()
                Text("Searching specializations...")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let errorMessage {
            Text(errorMessage)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedError)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if results.isEmpty {
            Text(emptyStateText)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { result in
                        SpecializationResultRow(
                            result: result,
                            isSelected: result.id == selectedSpecialization?.id,
                            onSelect: { select(result) }
                        )

                        if result.id != results.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var emptyStateText: String {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Start typing to search majors or departments." : "No specializations found."
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            return
        }
        let requestedFilter = filter
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await performSearch(query: trimmed, filter: requestedFilter)
        }
    }

    @MainActor
    private func performSearch(query: String, filter: SpecializationFilter) async {
        let currentQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard currentQuery == query, self.filter == filter else { return }
        isLoading = true
        errorMessage = nil
        do {
            let page = try await communityService.searchCommunities(
                query: query,
                limit: 20,
                cursor: nil,
                kind: filter.searchKind
            )
            guard currentQuery == query, self.filter == filter else { return }
            results = page.items.filter { $0.specializationType != .unknown }
        } catch {
            guard currentQuery == query, self.filter == filter else { return }
            errorMessage = error.localizedDescription
            results = []
        }
        isLoading = false
    }

    private func select(_ result: CommunitySearchResult) {
        guard result.kind == .specialization else { return }
        guard result.specializationType != .unknown else { return }
        if result.isJoined != true {
            let label = result.specializationType.displayName?.lowercased() ?? "specialization"
            alertMessage = "Join this \(label) to display it on your profile."
            communityToView = CommunityProfileData(community: result)
            return
        }
        selectedSpecialization = DisplayCommunity(
            id: result.id,
            name: result.name,
            shortName: result.shortName,
            kind: result.kind,
            specializationType: result.specializationType == .unknown ? nil : result.specializationType
        )
        dismiss()
    }
}

private enum SpecializationFilter: CaseIterable {
    case major
    case department

    var title: String {
        switch self {
        case .major:
            return "Major"
        case .department:
            return "Department"
        }
    }

    var searchKind: CommunitySearchKind {
        switch self {
        case .major:
            return .major
        case .department:
            return .department
        }
    }

    static func from(_ specializationType: CommunitySpecializationType?) -> SpecializationFilter? {
        switch specializationType {
        case .major:
            return .major
        case .department:
            return .department
        case .unknown, .none:
            return nil
        }
    }
}

private struct SpecializationResultRow: View {
    let result: CommunitySearchResult
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.loopedMutedBackground)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(initials(for: specializationLabel))
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedTextPrimary)
                    )

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

    private func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }
}
