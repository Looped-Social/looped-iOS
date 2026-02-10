import SwiftUI
import UIKit

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
