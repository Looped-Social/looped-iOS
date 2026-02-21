import Foundation

struct AppConfigDTO: Codable {
    let defaultProfileImageUrl: String?
    let minimumSupportedVersion: String?
    let minimumSupportedVersionMessage: String?
    let minimumSupportedVersionUpdateUrl: String?
}
