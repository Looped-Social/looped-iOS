import Foundation
import AVFoundation

enum VideoTranscoderError: LocalizedError {
    case exportUnavailable
    case exportFailed(String?)

    var errorDescription: String? {
        switch self {
        case .exportUnavailable:
            return "We couldn't process that video. Try another one."
        case .exportFailed(let message):
            return message ?? "We couldn't process that video. Try another one."
        }
    }
}

enum VideoTranscoder {
    static func ensureMP4(at url: URL) async throws -> URL {
        if url.pathExtension.lowercased() == "mp4" {
            return url
        }

        let presetCandidates = [
            AVAssetExportPresetPassthrough,
            AVAssetExportPreset1920x1080,
            AVAssetExportPresetHighestQuality,
            AVAssetExportPreset1280x720,
            AVAssetExportPresetMediumQuality,
        ]

        let asset = AVURLAsset(url: url)
        guard let export = presetCandidates.compactMap({ preset in
            AVAssetExportSession(asset: asset, presetName: preset)
        }).first(where: { $0.supportedFileTypes.contains(.mp4) }) else {
            throw VideoTranscoderError.exportUnavailable
        }

        let outputUrl = TemporaryMediaFile.makeURL(extension: "mp4")

        try? FileManager.default.removeItem(at: outputUrl)
        export.shouldOptimizeForNetworkUse = true

        try await export.export(to: outputUrl, as: .mp4)

        return outputUrl
    }
}
