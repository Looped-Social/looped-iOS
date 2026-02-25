import Foundation

struct ProfileCompletionStatus: Equatable {
    enum MissingItem: String, CaseIterable, Hashable {
        case photo
        case bio
        case specialization

        var title: String {
            switch self {
            case .photo:
                return "Add a profile photo"
            case .bio:
                return "Add a bio"
            case .specialization:
                return "Select a display specialization"
            }
        }
    }

    let shouldPrompt: Bool
    let missingPhoto: Bool
    let missingBio: Bool
    let missingSpecialization: Bool
    let dismissedAt: Date?
    let completedAt: Date?

    init(dto: ProfileCompletionDTO) {
        shouldPrompt = dto.shouldPrompt ?? false
        missingPhoto = dto.missingPhoto ?? false
        missingBio = dto.missingBio ?? false
        missingSpecialization = dto.missingSpecialization ?? false
        dismissedAt = dto.dismissedAt
        completedAt = dto.completedAt
    }

    var missingItems: [MissingItem] {
        var items: [MissingItem] = []
        if missingPhoto { items.append(.photo) }
        if missingBio { items.append(.bio) }
        if missingSpecialization { items.append(.specialization) }
        return items
    }

    func dismissing(at dismissedAt: Date = Date()) -> ProfileCompletionStatus {
        ProfileCompletionStatus(
            shouldPrompt: false,
            missingPhoto: missingPhoto,
            missingBio: missingBio,
            missingSpecialization: missingSpecialization,
            dismissedAt: dismissedAt,
            completedAt: completedAt
        )
    }

    init(
        shouldPrompt: Bool,
        missingPhoto: Bool,
        missingBio: Bool,
        missingSpecialization: Bool,
        dismissedAt: Date?,
        completedAt: Date?
    ) {
        self.shouldPrompt = shouldPrompt
        self.missingPhoto = missingPhoto
        self.missingBio = missingBio
        self.missingSpecialization = missingSpecialization
        self.dismissedAt = dismissedAt
        self.completedAt = completedAt
    }
}
