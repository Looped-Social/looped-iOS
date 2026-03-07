import Foundation
import Combine

@MainActor
final class DisplaySpecializationPickerViewModel: ObservableObject {
    @Published private(set) var results: [CommunitySearchResult] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?

    var hasMorePages: Bool {
        guard let nextCursor else { return false }
        return !nextCursor.isEmpty
    }

    private let communityService: CommunityServiceProtocol
    private let discoveryService: DiscoveryServiceProtocol
    private let pageLimit: Int

    private var nextCursor: String?
    private var activeQuery: String = ""
    private var activeFilter: SpecializationFilter = .field
    private var requestGeneration = 0

    init(
        communityService: CommunityServiceProtocol = CommunityService(),
        discoveryService: DiscoveryServiceProtocol = DiscoveryService(),
        pageLimit: Int = 24
    ) {
        self.communityService = communityService
        self.discoveryService = discoveryService
        self.pageLimit = max(1, pageLimit)
    }

    func reload(query: String, filter: SpecializationFilter) async {
        requestGeneration += 1
        let generation = requestGeneration

        let normalizedQuery = Self.normalizedQuery(query)
        activeQuery = normalizedQuery
        activeFilter = filter

        isLoading = true
        errorMessage = nil
        nextCursor = nil

        do {
            let page = try await fetchPage(query: normalizedQuery, filter: filter, cursor: nil)
            guard generation == requestGeneration else { return }
            results = deduplicatedSpecializations(page.items)
            nextCursor = page.nextCursor
        } catch {
            guard generation == requestGeneration else { return }
            results = []
            nextCursor = nil
            errorMessage = error.localizedDescription
        }

        if generation == requestGeneration {
            isLoading = false
        }
    }

    func loadMoreIfNeeded(currentId: Int, query: String, filter: SpecializationFilter) async {
        guard let nextCursor, !nextCursor.isEmpty else { return }
        guard !isLoading, !isLoadingMore else { return }
        guard results.last?.id == currentId else { return }

        let normalizedQuery = Self.normalizedQuery(query)
        guard normalizedQuery == activeQuery, filter == activeFilter else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await fetchPage(query: normalizedQuery, filter: filter, cursor: nextCursor)
            self.nextCursor = page.nextCursor
            let merged = results + page.items
            results = deduplicatedSpecializations(merged)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchPage(
        query: String,
        filter: SpecializationFilter,
        cursor: String?
    ) async throws -> SearchResultPage<CommunitySearchResult> {
        if query.isEmpty {
            return try await discoveryService.browseSpecializations(
                type: filter.specializationType,
                limit: pageLimit,
                cursor: cursor
            )
        }

        return try await communityService.searchCommunities(
            query: query,
            limit: pageLimit,
            cursor: cursor,
            kind: filter.searchKind
        )
    }

    private func deduplicatedSpecializations(_ items: [CommunitySearchResult]) -> [CommunitySearchResult] {
        var seenIds = Set<Int>()
        var unique: [CommunitySearchResult] = []

        for item in items where item.kind == .specialization && item.specializationType != .unknown {
            guard seenIds.insert(item.id).inserted else { continue }
            unique.append(item)
        }

        return unique
    }

    static func normalizedQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum SpecializationFilter: CaseIterable {
    case field

    var title: String {
        switch self {
        case .field:
            return "Field"
        }
    }

    var searchKind: CommunitySearchKind {
        switch self {
        case .field:
            return .field
        }
    }

    var specializationType: CommunitySpecializationType {
        switch self {
        case .field:
            return .field
        }
    }

    static func from(_ specializationType: CommunitySpecializationType?) -> SpecializationFilter? {
        switch specializationType {
        case .field:
            return .field
        case .major, .unknown, .none:
            return .field
        }
    }
}
