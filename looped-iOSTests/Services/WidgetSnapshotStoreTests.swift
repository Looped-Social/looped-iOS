import Foundation
import Testing
@testable import looped_iOS

@Suite
struct WidgetSnapshotStoreTests {
    @Test
    func decodingLegacySnapshotAppliesSafeDefaults() throws {
        let data = Data(
            """
            {
              "unreadMessageCount": 3,
              "messageRequestCount": 1,
              "unreadMentionCount": 2,
              "verifiedCommunities": [
                {
                  "id": 42,
                  "name": "Engineering",
                  "shortName": "Eng",
                  "memberCount": 612
                }
              ],
              "selectedCommunityId": 42
            }
            """.utf8
        )

        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: data)

        #expect(snapshot.snapshotTTLSeconds == 900)
        #expect(snapshot.profileStats.followers == 0)
        #expect(snapshot.profileStats.following == 0)
        #expect(snapshot.profileStats.likesReceived == 0)
        #expect(snapshot.trendingPost == nil)
        #expect(snapshot.serverTime == nil)
        #expect(snapshot.verifiedCommunities.first?.newActivityCount == 0)
    }

    @Test
    func saveMergesLocalCountsWithoutDroppingServerCommunityActivity() {
        clearSharedSnapshot()
        defer { clearSharedSnapshot() }

        let seeded = WidgetSnapshot(
            updatedAt: .now,
            serverTime: .now,
            snapshotTTLSeconds: 900,
            unreadMessageCount: 10,
            messageRequestCount: 2,
            unreadMentionCount: 1,
            profileStats: .init(followers: 11, following: 7, likesReceived: 101),
            trendingPost: .init(
                postId: 77,
                communityName: "Engineering",
                contentPreview: "Quarterly planning thread",
                likeCount: 22,
                commentCount: 8,
                mediaThumbnailUrl: nil
            ),
            verifiedCommunities: [
                .init(id: 42, name: "Engineering", shortName: "Eng", memberCount: 612, newActivityCount: 9)
            ],
            selectedCommunityId: 42
        )
        WidgetSnapshotStore.save(seeded)

        WidgetSnapshotStore.save(
            unreadMessageCount: 4,
            messageRequestCount: 1,
            unreadMentionCount: 3,
            verifiedCommunities: [
                community(id: 42, name: "Engineering", shortName: "Eng", members: 620),
                community(id: 84, name: "Design", shortName: nil, members: 180)
            ],
            selectedCommunityId: nil
        )

        let merged = WidgetSnapshotStore.load()
        #expect(merged.unreadMessageCount == 4)
        #expect(merged.messageRequestCount == 1)
        #expect(merged.unreadMentionCount == 3)
        #expect(merged.profileStats == .init(followers: 11, following: 7, likesReceived: 101))
        #expect(merged.trendingPost?.postId == 77)
        #expect(merged.serverTime != nil)
        #expect(merged.selectedCommunityId == 42)

        let engineering = merged.verifiedCommunities.first(where: { $0.id == 42 })
        let design = merged.verifiedCommunities.first(where: { $0.id == 84 })
        #expect(engineering?.newActivityCount == 9)
        #expect(design?.newActivityCount == 0)
    }

    private func clearSharedSnapshot() {
        WidgetSnapshotStore.save(.empty)
    }

    private func community(id: Int, name: String, shortName: String?, members: Int) -> CommunitySummary {
        CommunitySummary(
            id: id,
            name: name,
            shortName: shortName,
            kind: .company,
            memberCount: members,
            isPinned: false,
            sortOrder: nil,
            canPost: true
        )
    }
}
