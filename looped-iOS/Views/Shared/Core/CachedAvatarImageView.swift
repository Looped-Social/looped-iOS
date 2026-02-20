import SwiftUI
import UIKit
import ImageIO

struct CachedAvatarImageView<Placeholder: View>: View {
    let url: URL
    let placeholder: Placeholder

    @StateObject private var loader: AvatarImageLoader

    init(url: URL, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder()
        _loader = StateObject(wrappedValue: AvatarImageLoader(url: url))
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .onAppear {
            loader.updateURL(url)
            loader.loadIfNeeded()
        }
        .onChange(of: url.absoluteString) { _, _ in
            loader.updateURL(url)
            loader.loadIfNeeded()
        }
    }
}

@MainActor
private final class AvatarImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    private var url: URL?
    private var task: Task<Void, Never>?

    init(url: URL?) {
        self.url = url
        if let url {
            image = AvatarImageCache.shared.image(for: url)
        }
    }

    func updateURL(_ newURL: URL?) {
        guard url != newURL else { return }
        task?.cancel()
        url = newURL
        if let newURL {
            image = AvatarImageCache.shared.image(for: newURL)
        } else {
            image = nil
        }
    }

    func loadIfNeeded() {
        guard image == nil, let url else { return }

        task?.cancel()
        task = Task { [weak self] in
            do {
                let request = URLRequest(
                    url: url,
                    cachePolicy: .returnCacheDataElseLoad,
                    timeoutInterval: 30
                )
                let (data, _) = try await URLSession.shared.data(for: request)
                guard !Task.isCancelled, let uiImage = UIImage(data: data) else { return }

                AvatarImageCache.shared.store(uiImage, for: url)

                await MainActor.run {
                    guard let self, self.url == url else { return }
                    self.image = uiImage
                }
            } catch {
                // Keep placeholder on failure.
            }
        }
    }
}

private final class AvatarImageCache {
    static let shared = AvatarImageCache()

    private let cache = NSCache<NSString, AvatarCachedImage>()
    private let ttl: TimeInterval = 30 * 60

    private init() {
        cache.countLimit = 400
        cache.totalCostLimit = 24 * 1024 * 1024
    }

    func image(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)
        if let cached = cache.object(forKey: key) {
            if Date().timeIntervalSince(cached.insertedAt) <= ttl {
                return cached.image
            }
            cache.removeObject(forKey: key)
        }

        let request = URLRequest(url: url)
        guard let cachedResponse = URLCache.shared.cachedResponse(for: request),
              let image = UIImage(data: cachedResponse.data) else {
            return nil
        }

        store(image, for: url)
        return image
    }

    func store(_ image: UIImage, for url: URL) {
        let cached = AvatarCachedImage(image: image, insertedAt: Date())
        cache.setObject(cached, forKey: cacheKey(for: url), cost: cost(for: image))
    }

    private func cacheKey(for url: URL) -> NSString {
        url.absoluteString as NSString
    }

    private func cost(for image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

private final class AvatarCachedImage {
    let image: UIImage
    let insertedAt: Date

    init(image: UIImage, insertedAt: Date) {
        self.image = image
        self.insertedAt = insertedAt
    }
}

enum LoopedAsyncImagePhase {
    case empty
    case success(Image)
    case failure
}

struct LoopedDownsampledAsyncImage<Content: View>: View {
    let url: URL?
    let maxPixelSize: CGFloat
    let content: (LoopedAsyncImagePhase) -> Content

    @StateObject private var loader = LoopedDownsampledImageLoader()

    init(
        url: URL?,
        maxPixelSize: CGFloat,
        @ViewBuilder content: @escaping (LoopedAsyncImagePhase) -> Content
    ) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.content = content
    }

    var body: some View {
        content(loader.phase)
            .onAppear {
                loader.load(url: url, maxPixelSize: maxPixelSize)
            }
            .onChange(of: url?.absoluteString) { _, _ in
                loader.load(url: url, maxPixelSize: maxPixelSize)
            }
            .onChange(of: maxPixelSize) { _, _ in
                loader.load(url: url, maxPixelSize: maxPixelSize)
            }
            .onDisappear {
                loader.cancel()
            }
    }
}

@MainActor
private final class LoopedDownsampledImageLoader: ObservableObject {
    @Published fileprivate(set) var phase: LoopedAsyncImagePhase = .empty

    private static let imageCache = NSCache<NSString, UIImage>()
    private static let maxDecodedPixels: CGFloat = 40_000_000
    private static let maxDownloadBytes = 30 * 1024 * 1024

    private var currentURL: URL?
    private var currentPixelSize: CGFloat = 0
    private var task: Task<Void, Never>?

    init() {
        Self.imageCache.countLimit = 300
        Self.imageCache.totalCostLimit = 80 * 1024 * 1024
    }

    func load(url: URL?, maxPixelSize: CGFloat) {
        let clampedPixelSize = max(64, min(maxPixelSize, 4096))
        if currentURL == url, abs(currentPixelSize - clampedPixelSize) < 1 {
            return
        }

        currentURL = url
        currentPixelSize = clampedPixelSize
        task?.cancel()

        guard let url else {
            phase = .failure
            return
        }

        if let cached = Self.imageCache.object(forKey: cacheKey(for: url, maxPixelSize: clampedPixelSize)) {
            phase = .success(Image(uiImage: cached))
            return
        }

        phase = .empty
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let request = URLRequest(
                    url: url,
                    cachePolicy: .returnCacheDataElseLoad,
                    timeoutInterval: 30
                )
                let (data, _) = try await URLSession.shared.data(for: request)
                guard !Task.isCancelled else { return }

                guard data.count <= Self.maxDownloadBytes else {
                    await MainActor.run {
                        guard self.currentURL == url else { return }
                        self.phase = .failure
                    }
                    return
                }

                guard let uiImage = Self.downsampledImage(
                    from: data,
                    maxPixelSize: clampedPixelSize
                ) else {
                    await MainActor.run {
                        guard self.currentURL == url else { return }
                        self.phase = .failure
                    }
                    return
                }

                Self.imageCache.setObject(
                    uiImage,
                    forKey: self.cacheKey(for: url, maxPixelSize: clampedPixelSize),
                    cost: self.cost(for: uiImage)
                )

                await MainActor.run {
                    guard self.currentURL == url else { return }
                    self.phase = .success(Image(uiImage: uiImage))
                }
            } catch {
                await MainActor.run {
                    guard self.currentURL == url else { return }
                    self.phase = .failure
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
    }

    private static func downsampledImage(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }

        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
           let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
           width > 0, height > 0 {
            let totalPixels = width * height
            if totalPixels > maxDecodedPixels {
                #if DEBUG
                print("LOOPED_MEDIA skipped oversized image \(Int(width))x\(Int(height))")
                #endif
                return nil
            }
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize)
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func cacheKey(for url: URL, maxPixelSize: CGFloat) -> NSString {
        "\(url.absoluteString)|\(Int(maxPixelSize.rounded()))" as NSString
    }

    private func cost(for image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
