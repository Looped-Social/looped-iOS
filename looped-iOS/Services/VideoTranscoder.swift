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

        let asset = AVAsset(url: url)
        let compatiblePresets = Set(AVAssetExportSession.exportPresets(compatibleWith: asset))
        let presetCandidates = [
            AVAssetExportPresetPassthrough,
            AVAssetExportPreset1920x1080,
            AVAssetExportPresetHighestQuality,
            AVAssetExportPreset1280x720,
            AVAssetExportPresetMediumQuality,
        ]
        let chosenPreset = presetCandidates.first(where: { compatiblePresets.contains($0) })

        guard let chosenPreset,
              let export = AVAssetExportSession(asset: asset, presetName: chosenPreset),
              export.supportedFileTypes.contains(.mp4) else {
            throw VideoTranscoderError.exportUnavailable
        }

        let outputUrl = TemporaryMediaFile.makeURL(extension: "mp4")

        try? FileManager.default.removeItem(at: outputUrl)
        export.outputURL = outputUrl
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true

        try await withCheckedThrowingContinuation { continuation in
            export.exportAsynchronously {
                switch export.status {
                case .completed:
                    continuation.resume(returning: ())
                case .failed:
                    continuation.resume(throwing: VideoTranscoderError.exportFailed(export.error?.localizedDescription))
                case .cancelled:
                    continuation.resume(throwing: VideoTranscoderError.exportFailed("Video export was cancelled."))
                default:
                    continuation.resume(throwing: VideoTranscoderError.exportFailed(export.error?.localizedDescription))
                }
            }
        }

        return outputUrl
    }
}
