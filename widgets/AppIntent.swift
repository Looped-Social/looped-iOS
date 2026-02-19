import AppIntents
import WidgetKit

struct WidgetCommunityEntity: AppEntity, Identifiable, Hashable {
    let id: Int
    let name: String
    let shortName: String?
    let memberCount: Int

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Community")
    }

    static var defaultQuery = WidgetCommunityQuery()

    var displayRepresentation: DisplayRepresentation {
        if let shortName, !shortName.isEmpty {
            return DisplayRepresentation(
                title: "\(shortName)",
                subtitle: "\(name)"
            )
        }
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(memberCount) members"
        )
    }
}

struct WidgetCommunityQuery: EntityQuery {
    func entities(for identifiers: [WidgetCommunityEntity.ID]) async throws -> [WidgetCommunityEntity] {
        let idSet = Set(identifiers)
        let cached = WidgetSnapshotRepository.load()
        let snapshot = cached.verifiedCommunities.isEmpty ? await WidgetSummaryService.latestSnapshot() : cached
        return snapshot
            .verifiedCommunities
            .map { WidgetCommunityEntity(id: $0.id, name: $0.name, shortName: $0.shortName, memberCount: $0.memberCount) }
            .filter { idSet.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WidgetCommunityEntity] {
        let cached = WidgetSnapshotRepository.load()
        let snapshot = cached.verifiedCommunities.isEmpty ? await WidgetSummaryService.latestSnapshot() : cached
        return snapshot
            .verifiedCommunities
            .map { WidgetCommunityEntity(id: $0.id, name: $0.name, shortName: $0.shortName, memberCount: $0.memberCount) }
    }

    func defaultResult() async -> WidgetCommunityEntity? {
        let cached = WidgetSnapshotRepository.load()
        let snapshot = cached.verifiedCommunities.isEmpty ? await WidgetSummaryService.latestSnapshot() : cached
        if let selectedCommunityId = snapshot.selectedCommunityId,
           let selected = snapshot.verifiedCommunities.first(where: { $0.id == selectedCommunityId }) {
            return WidgetCommunityEntity(
                id: selected.id,
                name: selected.name,
                shortName: selected.shortName,
                memberCount: selected.memberCount
            )
        }
        guard let first = snapshot.verifiedCommunities.first else { return nil }
        return WidgetCommunityEntity(
            id: first.id,
            name: first.name,
            shortName: first.shortName,
            memberCount: first.memberCount
        )
    }
}

struct VerifiedCommunitySelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Verified Community" }
    static var description: IntentDescription {
        IntentDescription("Choose a community for this widget. Leave empty for automatic selection.")
    }

    @Parameter(title: "Community")
    var community: WidgetCommunityEntity?
}
