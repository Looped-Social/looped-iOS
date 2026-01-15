import Foundation
import UIKit

enum ImageUploadTranscoder {
    struct Output: Sendable {
        let data: Data
        let mimeType: String
        let width: Int
        let height: Int
    }

    struct Settings: Sendable {
        let maxDimension: CGFloat
        let maxBytes: Int
        let jpegStartQuality: CGFloat
        let jpegMinQuality: CGFloat
        let jpegQualityStep: CGFloat

        init(
            maxDimension: CGFloat = 1600,
            maxBytes: Int = 1_800_000,
            jpegStartQuality: CGFloat = 0.82,
            jpegMinQuality: CGFloat = 0.6,
            jpegQualityStep: CGFloat = 0.06
        ) {
            self.maxDimension = maxDimension
            self.maxBytes = maxBytes
            self.jpegStartQuality = jpegStartQuality
            self.jpegMinQuality = jpegMinQuality
            self.jpegQualityStep = jpegQualityStep
        }
    }

    static func makeUploadPayload(from image: UIImage, settings: Settings = Settings()) -> Output? {
        autoreleasepool {
            let resized = resizedImageIfNeeded(image, maxDimension: settings.maxDimension)
            let width = Int(resized.size.width * resized.scale)
            let height = Int(resized.size.height * resized.scale)

            if imageHasAlpha(resized) {
                if let png = resized.pngData(), png.count <= settings.maxBytes {
                    return Output(data: png, mimeType: "image/png", width: width, height: height)
                }
                let flattened = flattenedImage(resized, backgroundColor: .white)
                guard let jpeg = jpegDataUnderLimit(flattened, settings: settings) else { return nil }
                return Output(data: jpeg, mimeType: "image/jpeg", width: width, height: height)
            }

            guard let jpeg = jpegDataUnderLimit(resized, settings: settings) else { return nil }
            return Output(data: jpeg, mimeType: "image/jpeg", width: width, height: height)
        }
    }

    private static func jpegDataUnderLimit(_ image: UIImage, settings: Settings) -> Data? {
        var quality = settings.jpegStartQuality
        var best: Data? = nil

        while quality >= settings.jpegMinQuality {
            guard let data = image.jpegData(compressionQuality: quality) else { return best }
            best = data
            if data.count <= settings.maxBytes { return data }
            quality -= settings.jpegQualityStep
        }

        return best
    }

    private static func flattenedImage(_ image: UIImage, backgroundColor: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func resizedImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let maxPixel = max(pixelWidth, pixelHeight)
        guard maxPixel > maxDimension, maxPixel > 0 else { return image }

        let scaleFactor = maxDimension / maxPixel
        let newSize = CGSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private static func imageHasAlpha(_ image: UIImage) -> Bool {
        guard let alphaInfo = image.cgImage?.alphaInfo else { return false }
        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }
}

