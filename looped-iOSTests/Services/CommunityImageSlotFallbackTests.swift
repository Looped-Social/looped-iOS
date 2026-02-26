import Foundation
import Testing
@testable import looped_iOS

struct CommunityImageSlotFallbackTests {
    @Test
    func communitySearchDTO_decodesNewImageSlots() throws {
        let dto = try decodeCommunitySearchDTO(
            from: """
            {
              "id": 101,
              "name": "UNC",
              "short_name": "UNC",
              "description": "School community",
              "kind": "school",
              "specialization_type": null,
              "member_count": 4200,
              "banner_image_url": "https://cdn.example.com/banner.png",
              "profile_image_url": "https://cdn.example.com/profile.png",
              "image_url": "https://cdn.example.com/legacy.png",
              "icon": null,
              "is_following": true,
              "is_joined": false
            }
            """
        )

        let result = CommunitySearchResult(dto: dto)

        #expect(result.bannerImageUrl == "https://cdn.example.com/banner.png")
        #expect(result.profileImageUrl == "https://cdn.example.com/profile.png")
        #expect(result.imageUrl == "https://cdn.example.com/legacy.png")
        #expect(result.bannerDisplayImageUrl == "https://cdn.example.com/banner.png")
        #expect(result.profileDisplayImageUrl == "https://cdn.example.com/profile.png")
    }

    @Test
    func communitySearchResult_legacyImageFallsBackForBothSlots() throws {
        let dto = try decodeCommunitySearchDTO(
            from: """
            {
              "id": 102,
              "name": "Airbnb",
              "short_name": "Airbnb",
              "description": "Company community",
              "kind": "company",
              "specialization_type": null,
              "member_count": 2400,
              "image_url": "https://cdn.example.com/legacy-only.png",
              "icon": null,
              "is_following": false,
              "is_joined": false
            }
            """
        )

        let result = CommunitySearchResult(dto: dto)

        #expect(result.bannerImageUrl == nil)
        #expect(result.profileImageUrl == nil)
        #expect(result.bannerDisplayImageUrl == "https://cdn.example.com/legacy-only.png")
        #expect(result.profileDisplayImageUrl == "https://cdn.example.com/legacy-only.png")
    }

    @Test
    func communityDetailsDTO_decodesNewSlots_forProfileData() throws {
        let dto = try decodeCommunityDetailsDTO(
            from: """
            {
              "id": 501,
              "name": "NC State",
              "short_name": "NCSU",
              "description": "School",
              "kind": "school",
              "specialization_type": null,
              "member_count": 9000,
              "banner_image_url": "https://cdn.example.com/school-banner.png",
              "profile_image_url": "https://cdn.example.com/school-profile.png",
              "image_url": "https://cdn.example.com/school-legacy.png",
              "icon": null,
              "is_following": true,
              "is_joined": false,
              "join_limit": null
            }
            """
        )

        let profileData = CommunityProfileData(details: dto)

        #expect(profileData.bannerDisplayImageUrl == "https://cdn.example.com/school-banner.png")
        #expect(profileData.profileDisplayImageUrl == "https://cdn.example.com/school-profile.png")
    }

    @Test
    func communityProfileData_detailsWithLegacyImage_resetsSlotsToLegacyFallback() {
        let fallback = CommunityProfileData(
            id: 33,
            name: "Fallback",
            shortName: nil,
            description: "",
            kind: .company,
            specializationType: .unknown,
            memberCount: 10,
            bannerImageUrl: "https://cdn.example.com/old-banner.png",
            profileImageUrl: "https://cdn.example.com/old-profile.png",
            imageUrl: "https://cdn.example.com/old-legacy.png",
            isFollowing: false,
            isJoined: false,
            joinLimit: nil
        )

        let details = CommunityDetailsDTO(
            id: 33,
            name: "Updated",
            shortName: nil,
            description: "",
            kind: "company",
            specializationType: nil,
            memberCount: 11,
            bannerImageUrl: nil,
            profileImageUrl: nil,
            imageUrl: "https://cdn.example.com/new-legacy.png",
            icon: nil,
            isFollowing: true,
            isJoined: false,
            joinLimit: nil,
            viewer: nil
        )

        let merged = CommunityProfileData(details: details, fallback: fallback)

        #expect(merged.bannerImageUrl == nil)
        #expect(merged.profileImageUrl == nil)
        #expect(merged.bannerDisplayImageUrl == "https://cdn.example.com/new-legacy.png")
        #expect(merged.profileDisplayImageUrl == "https://cdn.example.com/new-legacy.png")
    }

    @Test
    func communityProfileData_detailsWithoutAnyImage_keepsFallbackSlots() {
        let fallback = CommunityProfileData(
            id: 44,
            name: "Fallback",
            shortName: nil,
            description: "",
            kind: .school,
            specializationType: .unknown,
            memberCount: 10,
            bannerImageUrl: "https://cdn.example.com/fallback-banner.png",
            profileImageUrl: "https://cdn.example.com/fallback-profile.png",
            imageUrl: "https://cdn.example.com/fallback-legacy.png",
            isFollowing: true,
            isJoined: false,
            joinLimit: nil
        )

        let details = CommunityDetailsDTO(
            id: 44,
            name: "Fallback",
            shortName: nil,
            description: "",
            kind: "school",
            specializationType: nil,
            memberCount: 10,
            bannerImageUrl: nil,
            profileImageUrl: nil,
            imageUrl: nil,
            icon: nil,
            isFollowing: nil,
            isJoined: nil,
            joinLimit: nil,
            viewer: nil
        )

        let merged = CommunityProfileData(details: details, fallback: fallback)

        #expect(merged.bannerDisplayImageUrl == "https://cdn.example.com/fallback-banner.png")
        #expect(merged.profileDisplayImageUrl == "https://cdn.example.com/fallback-profile.png")
    }
}

private func decodeCommunitySearchDTO(from json: String) throws -> CommunitySearchDTO {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(CommunitySearchDTO.self, from: Data(json.utf8))
}

private func decodeCommunityDetailsDTO(from json: String) throws -> CommunityDetailsDTO {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(CommunityDetailsDTO.self, from: Data(json.utf8))
}
