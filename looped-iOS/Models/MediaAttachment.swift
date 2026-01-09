import Foundation
import UIKit

struct MediaAttachment: Codable, Identifiable, Equatable {
    let id: UUID
    let type: MediaType
    let url: String
    let thumbnailUrl: String?
    let width: Int?
    let height: Int?
    let duration: TimeInterval? // For videos
    let fileSize: Int64? // In bytes
    let createdAt: Date

    init(
        id: UUID = UUID(),
        type: MediaType,
        url: String,
        thumbnailUrl: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        duration: TimeInterval? = nil,
        fileSize: Int64? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.width = width
        self.height = height
        self.duration = duration
        self.fileSize = fileSize
        self.createdAt = createdAt
    }
}

enum MediaType: String, Codable, CaseIterable {
    case image = "image"
    case video = "video"
    case gif = "gif"
}

extension MediaAttachment {
    init(dto: MediaAttachmentDTO) {
        self.id = UUID()
        let trimmedType = dto.type?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedType: MediaType
        if let trimmedType, !trimmedType.isEmpty, let type = MediaType(rawValue: trimmedType) {
            resolvedType = type
        } else {
            let lowercased = dto.url.lowercased()
            resolvedType = lowercased.contains(".mp4") ? .video : .image
        }
        self.type = resolvedType
        self.url = dto.url
        self.thumbnailUrl = dto.thumbnailUrl
        self.width = dto.width
        self.height = dto.height
        self.duration = dto.durationSeconds
        self.fileSize = dto.sizeBytes
        self.createdAt = Date()
    }
}

// MARK: - Local Media Selection (before upload)
struct LocalMediaItem: Identifiable, Equatable {
    let id: UUID
    let type: MediaType
    let image: UIImage? // For images and video thumbnails
    let videoURL: URL? // For videos
    let duration: TimeInterval? // For videos

    init(
        id: UUID = UUID(),
        type: MediaType,
        image: UIImage? = nil,
        videoURL: URL? = nil,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.type = type
        self.image = image
        self.videoURL = videoURL
        self.duration = duration
    }

    static func == (lhs: LocalMediaItem, rhs: LocalMediaItem) -> Bool {
        lhs.id == rhs.id
    }
}
