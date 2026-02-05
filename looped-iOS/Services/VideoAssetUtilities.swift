@preconcurrency import AVFoundation
import UIKit

enum VideoAssetUtilities {
    static func basicMetadata(for url: URL) async -> (width: Int, height: Int, durationSeconds: Int) {
        let asset = AVURLAsset(url: url)

        let duration = (try? await asset.load(.duration)).map(\.seconds) ?? 0
        let durationSeconds = duration.isFinite && duration > 0 ? Int(duration.rounded()) : 0

        guard let track = (try? await asset.loadTracks(withMediaType: .video)).flatMap({ $0.first }) else {
            return (width: 0, height: 0, durationSeconds: durationSeconds)
        }

        let naturalSize = (try? await track.load(.naturalSize)) ?? .zero
        let transform = (try? await track.load(.preferredTransform)) ?? .identity
        let transformed = naturalSize.applying(transform)
        let width = Int(abs(transformed.width).rounded())
        let height = Int(abs(transformed.height).rounded())
        return (width: max(width, 0), height: max(height, 0), durationSeconds: max(durationSeconds, 0))
    }

    static func metadataWithSize(for url: URL) async -> (width: Int, height: Int, durationSeconds: Int, sizeBytes: Int64) {
        let base = await basicMetadata(for: url)
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        return (
            width: base.width,
            height: base.height,
            durationSeconds: base.durationSeconds,
            sizeBytes: max(size, 0)
        )
    }

    static func duration(for url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let seconds = (try? await asset.load(.duration)).map(\.seconds) ?? 0
        return seconds.isFinite && seconds > 0 ? seconds : 0
    }

    static func thumbnail(
        for url: URL,
        time: CMTime = CMTime(seconds: 0.1, preferredTimescale: 600),
        maximumSize: CGSize? = nil
    ) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        if let maximumSize {
            generator.maximumSize = maximumSize
        }

        if let image = await generateImage(with: generator, time: time) {
            return image
        }
        return await generateImage(with: generator, time: .zero)
    }

    private static func generateImage(with generator: AVAssetImageGenerator, time: CMTime) async -> UIImage? {
        await withCheckedContinuation { continuation in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, _ in
                guard let cgImage else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: UIImage(cgImage: cgImage))
            }
        }
    }
}
