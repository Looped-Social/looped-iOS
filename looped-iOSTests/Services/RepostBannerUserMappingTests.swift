import Foundation
import Testing
@testable import looped_iOS

struct RepostBannerUserMappingTests {
    @Test
    func mapsEnrichedReposterFieldsFromSnakeCasePayload() throws {
        let json = """
        {
          "user_id": 42,
          "username": "luke",
          "display_name": "Luke Miller",
          "handle": "luke",
          "profile_image_url": "https://cdn.example.com/u/42.jpg"
        }
        """

        let dto: RepostedByUserDTO = try decodeSnakeCaseJSON(json)
        let mapped = RepostBannerUser(dto: dto)

        #expect(mapped.userId == 42)
        #expect(mapped.username == "luke")
        #expect(mapped.displayName == "Luke Miller")
        #expect(mapped.handle == "luke")
        #expect(mapped.profileImageURL == "https://cdn.example.com/u/42.jpg")
    }

    @Test
    func mapsLegacyReposterPayloadWithoutNewFields() throws {
        let json = """
        {
          "user_id": 7,
          "username": "oldshape"
        }
        """

        let dto: RepostedByUserDTO = try decodeSnakeCaseJSON(json)
        let mapped = RepostBannerUser(dto: dto)

        #expect(mapped.userId == 7)
        #expect(mapped.username == "oldshape")
        #expect(mapped.displayName == nil)
        #expect(mapped.handle == nil)
        #expect(mapped.profileImageURL == nil)
    }

    @Test
    func decodesRepostersPagePayloadAndMapsCursor() throws {
        let json = """
        {
          "items": [
            {
              "repost_id": 456,
              "reposted_at": "2026-02-21T18:20:00Z",
              "user_id": 123,
              "username": "luke",
              "display_name": "Luke Miller",
              "handle": "luke",
              "profile_image_url": "https://cdn.example.com/avatar.jpg"
            }
          ],
          "next_cursor": "cursor-2"
        }
        """

        let dto: RepostersResponseDTO = try decodeSnakeCaseJSON(json, dateDecodingStrategy: .iso8601)
        let page = RepostersPage(items: dto.items.map(RepostBannerUser.init(dto:)), nextCursor: dto.nextCursor)

        #expect(page.items.count == 1)
        #expect(page.items[0].repostId == 456)
        #expect(page.items[0].repostedAt != nil)
        #expect(page.items[0].displayName == "Luke Miller")
        #expect(page.nextCursor == "cursor-2")
    }

    private func decodeSnakeCaseJSON<T: Decodable>(
        _ json: String,
        dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate
    ) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = dateDecodingStrategy
        return try decoder.decode(T.self, from: Data(json.utf8))
    }
}
