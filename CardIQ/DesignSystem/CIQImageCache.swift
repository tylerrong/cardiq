import SwiftUI
import ImageIO
import CoreGraphics

/// In-memory decoded-image cache + prefetcher for card art.
///
/// `AsyncImage` re-downloads/re-decodes on every cell appearance, so first view of
/// each image waits on the network. This caches the *decoded* image so a prefetched
/// or previously-seen image renders instantly (no loading flash), and exposes
/// `prefetch` so a screen can warm its card images before the cells render.
@MainActor
final class CIQImageCache {
    static let shared = CIQImageCache()

    private let cache = NSCache<NSURL, CGImageBox>()
    private var inFlight: [URL: Task<CGImage?, Never>] = [:]
    private let session: URLSession

    init() {
        cache.countLimit = 400
        let config = URLSessionConfiguration.default
        config.urlCache = .shared
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
    }

    /// pokemontcg.io serves a small (`.png`) and hi-res (`_hires.png`) image.
    /// Thumbnails should use the small one.
    static func thumbnailURL(for card: CardIdentity) -> URL? {
        guard let imageURL = card.imageURL else { return nil }
        return URL(string: imageURL.replacingOccurrences(of: "_hires.png", with: ".png"))
    }

    func cachedImage(for url: URL) -> CGImage? {
        cache.object(forKey: url as NSURL)?.image
    }

    func image(for url: URL) async -> CGImage? {
        if let cached = cachedImage(for: url) { return cached }
        if let task = inFlight[url] { return await task.value }

        let task = Task { [weak self] in await self?.load(url) }
        inFlight[url] = task
        let result = await task.value
        inFlight[url] = nil
        return result
    }

    /// Warm the cache for a batch of card thumbnails (call when a list's data loads).
    func prefetchThumbnails(for cards: [CardIdentity]) {
        for url in cards.compactMap({ Self.thumbnailURL(for: $0) }) {
            guard cachedImage(for: url) == nil, inFlight[url] == nil else { continue }
            let task = Task { [weak self] in await self?.load(url) }
            inFlight[url] = task
        }
    }

    private func load(_ url: URL) async -> CGImage? {
        guard let (data, _) = try? await session.data(from: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        cache.setObject(CGImageBox(image), forKey: url as NSURL)
        return image
    }
}

private final class CGImageBox {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}

/// Displays a cached card image, rendering instantly when the image is already
/// cached/prefetched and falling back to `placeholder` while loading or on failure.
struct CIQCachedImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { image = nil; return }
            if let cached = CIQImageCache.shared.cachedImage(for: url) {
                image = cached
            } else {
                image = await CIQImageCache.shared.image(for: url)
            }
        }
    }
}
