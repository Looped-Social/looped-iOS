import Foundation

@MainActor
final class CommunityVerificationsViewModel: ObservableObject {
    @Published var items: [CommunityVerification] = []
    @Published var joinLimits: [SpecializationJoinLimit] = []
    @Published var joinedSpecializations: [DisplayCommunity] = []
    @Published var verificationSearchResults: [CommunitySearchResult] = []
    @Published var isSearchingVerificationCommunities = false
    @Published var verificationSearchError: String?
    @Published var specializationSearchResults: [CommunitySearchResult] = []
    @Published var isSearchingSpecializations = false
    @Published var specializationSearchError: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isUnverifying = false
    @Published var unverifyingCommunityId: Int?
    @Published private(set) var verificationSearchQuery: String = ""
    @Published private(set) var specializationSearchQuery: String = ""

    private let service: CommunityVerificationServiceProtocol
    private let communityService: CommunityServiceProtocol
    private let discoveryService: DiscoveryServiceProtocol
    private var verificationSearchGeneration = 0
    private var specializationSearchGeneration = 0
    private var fieldsIndexCache: [SpecializationIndexItem]?

    init(
        service: CommunityVerificationServiceProtocol = CommunityVerificationService(),
        communityService: CommunityServiceProtocol = CommunityService(),
        discoveryService: DiscoveryServiceProtocol = DiscoveryService()
    ) {
        self.service = service
        self.communityService = communityService
        self.discoveryService = discoveryService
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let verifications = service.fetchCommunityVerifications()
            async let limits = communityService.fetchSpecializationJoinLimits(type: nil)
            async let joined = communityService.fetchJoinedSpecializations(type: nil)
            items = try await verifications
            joinLimits = ((try? await limits) ?? []).filter { $0.specializationType == .field }
            joinedSpecializations = ((try? await joined) ?? []).filter { $0.specializationType == .field }
        } catch {
            errorMessage = error.localizedDescription
            items = []
            joinLimits = []
            joinedSpecializations = []
        }
    }

    func unverify(communityId: Int) async -> Bool {
        guard !isUnverifying else { return false }
        isUnverifying = true
        unverifyingCommunityId = communityId
        errorMessage = nil
        defer {
            isUnverifying = false
            unverifyingCommunityId = nil
        }

        do {
            _ = try await service.unverifyCommunity(communityId: communityId)
            NotificationCenter.default.post(
                name: .communityStateChanged,
                object: nil,
                userInfo: [LoopedNotificationUserInfoKey.communityId: communityId]
            )
            await load()
            return true
        } catch {
            errorMessage = mapError(error)
            return false
        }
    }

    func searchVerificationCommunities(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        verificationSearchQuery = trimmed
        verificationSearchGeneration += 1
        let generation = verificationSearchGeneration

        // Avoid firing network calls while the user just started typing.
        guard trimmed.count >= 2 else {
            verificationSearchResults = []
            verificationSearchError = nil
            isSearchingVerificationCommunities = false
            return
        }

        isSearchingVerificationCommunities = true
        verificationSearchError = nil
        async let companiesPage = try? communityService.searchCommunities(
            query: trimmed,
            limit: 20,
            cursor: nil,
            kind: .company
        )
        let companies = await companiesPage

        guard generation == verificationSearchGeneration else { return }
        if companies == nil {
            guard generation == verificationSearchGeneration else { return }
            verificationSearchResults = []
            verificationSearchError = "Couldn't load companies."
            isSearchingVerificationCommunities = false
            return
        }

        let verifiedCommunityIds = Set(items.filter(\.isActive).map(\.communityId))
        var seen = Set<Int>()
        let combined = (companies?.items ?? [])
            .filter { result in
                result.kind == .company
                && !verifiedCommunityIds.contains(result.id)
            }
            .filter { seen.insert($0.id).inserted }
            .sorted { lhs, rhs in
                if lhs.memberCount != rhs.memberCount {
                    return lhs.memberCount > rhs.memberCount
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        verificationSearchResults = combined
        isSearchingVerificationCommunities = false
    }

    func searchSpecializations(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        specializationSearchQuery = trimmed
        specializationSearchGeneration += 1
        let generation = specializationSearchGeneration

        guard trimmed.count >= 2 else {
            specializationSearchResults = []
            specializationSearchError = nil
            isSearchingSpecializations = false
            return
        }

        isSearchingSpecializations = true
        specializationSearchError = nil
        let fieldsIndex = await loadSpecializationIndexes()

        guard generation == specializationSearchGeneration else { return }
        if fieldsIndex == nil {
            specializationSearchResults = []
            specializationSearchError = "Couldn't load fields."
            isSearchingSpecializations = false
            return
        }

        let joinedIds = Set(joinedSpecializations.map(\.id))
        let fieldResults = (fieldsIndex ?? [])
            .filter { matchesSpecializationQuery(item: $0, query: trimmed) }
            .map { item in
                specializationResult(
                    from: item,
                    type: .field,
                    isJoined: joinedIds.contains(item.id)
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        specializationSearchResults = Array(fieldResults.prefix(30))
        isSearchingSpecializations = false
    }

    private func loadSpecializationIndexes() async -> [SpecializationIndexItem]? {
        if let fieldsIndexCache {
            return fieldsIndexCache
        }

        async let fieldsFetch = try? discoveryService.fetchFieldsIndex()
        let fields = await fieldsFetch
        if let fields {
            fieldsIndexCache = fields
        }

        return fields ?? fieldsIndexCache
    }

    private func matchesSpecializationQuery(item: SpecializationIndexItem, query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return true }
        if item.name.lowercased().contains(normalizedQuery) {
            return true
        }
        if let shortName = item.shortName?.lowercased(), shortName.contains(normalizedQuery) {
            return true
        }
        return false
    }

    private func specializationResult(
        from item: SpecializationIndexItem,
        type: CommunitySpecializationType,
        isJoined: Bool
    ) -> CommunitySearchResult {
        CommunitySearchResult(
            id: item.id,
            name: item.name,
            shortName: item.shortName,
            description: "",
            kind: .specialization,
            specializationType: type,
            memberCount: 0,
            imageUrl: nil,
            icon: item.icon,
            isFollowing: false,
            isJoined: isJoined
        )
    }

    private func mapError(_ error: Error) -> String {
        guard case let APIError.apiError(_, apiError, message) = error else {
            return error.localizedDescription
        }

        switch apiError {
        case "user_not_provisioned":
            return "Your account isn’t fully set up yet. Try again in a moment."
        case "community_not_found", "community_unavailable":
            return "That community no longer exists."
        default:
            if let message, !message.isEmpty {
                return message
            }
            return apiError
        }
    }
}
