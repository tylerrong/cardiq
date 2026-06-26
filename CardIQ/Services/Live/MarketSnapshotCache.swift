import Foundation

/// In-memory cache for market snapshots, shared across card cells.
///
/// Without this, every visible card cell fires its own `snapshot(for:)` network
/// call on each render/scroll — a browse grid floods the network and stutters.
/// This caches by card id and coalesces concurrent requests for the same card,
/// so repeated cells, re-renders, and scroll-backs are instant.
@MainActor
final class MarketSnapshotCache {
    static let shared = MarketSnapshotCache()

    private var cache: [String: MarketSnapshot] = [:]
    private var inFlight: [String: Task<MarketSnapshot?, Never>] = [:]

    func snapshot(for cardId: String) async -> MarketSnapshot? {
        if let cached = cache[cardId] { return cached }
        if let task = inFlight[cardId] { return await task.value }

        let task = Task { () -> MarketSnapshot? in
            try? await ServiceContainer.shared.marketData.snapshot(for: cardId)
        }
        inFlight[cardId] = task
        let result = await task.value
        inFlight[cardId] = nil
        if let result { cache[cardId] = result }
        return result
    }
}
