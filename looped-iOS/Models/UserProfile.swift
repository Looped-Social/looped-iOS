import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let backendId: Int?
    let username: String
    let displayName: String?
    let handle: String // @handle format
    let company: String
    let jobTitle: String
    let bio: String?
    let profileImageURL: String?
    let isVerified: Bool
    let isAnonymous: Bool
    let yearsInLoop: Int
    let followingCount: Int
    let followersCount: Int
    let postsCount: Int
    let commentsCount: Int
    let showFollowerCount: Bool
    let isCurrentUser: Bool
    let displayCommunity: DisplayCommunity?
    let displaySpecialization: DisplayCommunity?
    let createdAt: Date
    let updatedAt: Date

    var formattedHandle: String {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "@looped" }
        return "@\(trimmed)"
    }

    var formattedYearsInLoop: String {
        let suffix = yearsInLoop == 1 ? "" : "s"
        return String(yearsInLoop) + " year" + suffix + " in the Loop"
    }

    var formattedJobTitle: String {
        if let specializationLine = displaySpecializationLine {
            return specializationLine
        }
        return resolvedJobTitle + " @ " + resolvedCompany
    }

    func formattedJobTitle(preferShortNames: Bool) -> String {
        if let specializationLine = displaySpecializationLine(preferShortNames: preferShortNames) {
            return specializationLine
        }
        return resolvedJobTitle + " @ " + resolvedCompany
    }

    var displaySpecializationLine: String? {
        let rawSpecialization = displaySpecialization?.name ?? ""
        let specialization = rawSpecialization.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawCommunity = displayCommunity?.name ?? ""
        let community = rawCommunity.trimmingCharacters(in: .whitespacesAndNewlines)

        if !community.isEmpty {
            let resolvedSpecialization = specialization.isEmpty ? "Member" : specialization
            return resolvedSpecialization + " @ " + community
        }
        if !specialization.isEmpty {
            return specialization
        }
        return nil
    }

    func displaySpecializationLine(preferShortNames: Bool) -> String? {
        let specialization = CommunityLabelText.preferredName(
            preferShortNames: preferShortNames,
            name: displaySpecialization?.name,
            shortName: displaySpecialization?.shortName
        )
        let community = CommunityLabelText.preferredName(
            preferShortNames: preferShortNames,
            name: displayCommunity?.name,
            shortName: displayCommunity?.shortName
        )

        if let community {
            return "\(specialization ?? "Member") @ \(community)"
        }
        if let specialization {
            return specialization
        }
        return nil
    }

    var resolvedDisplayName: String {
        let rawDisplayName = displayName ?? ""
        let trimmedDisplayName = rawDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDisplayName.isEmpty { return "Looped User" }
        return trimmedDisplayName
    }

    var resolvedCompany: String {
        let trimmedCompany = company.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCompany.isEmpty { return "Looped" }
        return trimmedCompany
    }

    var resolvedJobTitle: String {
        let trimmedJobTitle = jobTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedJobTitle.isEmpty { return "Team Member" }
        return trimmedJobTitle
    }

}

extension UserProfile {
    func updatingFollowersCount(_ value: Int) -> UserProfile {
        UserProfile(
            id: id,
            backendId: backendId,
            username: username,
            displayName: displayName,
            handle: handle,
            company: company,
            jobTitle: jobTitle,
            bio: bio,
            profileImageURL: profileImageURL,
            isVerified: isVerified,
            isAnonymous: isAnonymous,
            yearsInLoop: yearsInLoop,
            followingCount: followingCount,
            followersCount: value,
            postsCount: postsCount,
            commentsCount: commentsCount,
            showFollowerCount: showFollowerCount,
            isCurrentUser: isCurrentUser,
            displayCommunity: displayCommunity,
            displaySpecialization: displaySpecialization,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func from(user: User, isCurrentUser: Bool = false) -> UserProfile {
        let now = Date()
        let createdAt = user.createdAt ?? now
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        let createdYear = calendar.component(.year, from: createdAt)
        let yearsInLoop = max(0, currentYear - createdYear)
        let username = user.username ?? user.handle
        let resolvedDisplayName = user.displayName ?? "Looped User"
        let resolvedCompany = user.companyName ?? "Looped"
        let followingCount = user.followingCount ?? 0
        let followersCount = user.followerCount ?? 0
        let postsCount = user.postsCount ?? 0
        let commentsCount = user.commentsCount ?? 0
        let showFollowerCount = user.showFollowerCount ?? true
        let updatedAt = user.updatedAt ?? now

        return UserProfile(
            id: user.id,
            backendId: user.backendId,
            username: username,
            displayName: resolvedDisplayName,
            handle: user.handle,
            company: resolvedCompany,
            jobTitle: "Team Member",
            bio: user.bio,
            profileImageURL: user.profileImageURL,
            isVerified: user.isVerified,
            isAnonymous: user.isAnonymous,
            yearsInLoop: yearsInLoop,
            followingCount: followingCount,
            followersCount: followersCount,
            postsCount: postsCount,
            commentsCount: commentsCount,
            showFollowerCount: showFollowerCount,
            isCurrentUser: isCurrentUser,
            displayCommunity: user.displayCommunity,
            displaySpecialization: user.displaySpecialization,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
