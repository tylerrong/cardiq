import Foundation

/// Local, disk-cached copy of the pokemontcg.io card catalog.
///
/// Find Card previously hit the live API on every keystroke — slow, rate-limited,
/// and silently empty on failure. Instead we download the catalog once (newest
/// sets first, saved incrementally so partial progress survives relaunch) and
/// serve search from memory: instant, complete, offline-friendly. A refresh runs
/// when the cache is older than 7 days to pick up new sets.
actor CardCatalogStore {
    static let shared = CardCatalogStore()

    private(set) var cards: [CardIdentity] = []
    private var searchKeys: [String] = []       // precomputed lowercase haystacks, index-aligned with `cards`
    private var isComplete = false
    private var lastRefreshed: Date?
    private var isDownloading = false
    private var loadedFromDisk = false

    /// Some cards are available to search against (partial is fine — newest first).
    var isReady: Bool { !cards.isEmpty }

    /// The whole catalog is on disk — local misses are authoritative.
    var hasFullCatalog: Bool { isComplete }

    // MARK: - Bootstrap

    /// Load the disk cache, then top up from the network if incomplete or stale.
    /// Call once at launch; safe to call again (no-ops while a download runs).
    func bootstrap(client: PokemonTCGClient = PokemonTCGClient()) async {
        loadFromDiskIfNeeded()
        let stale = lastRefreshed.map { Date().timeIntervalSince($0) > 7 * 86_400 } ?? true
        guard !isDownloading, (!isComplete || stale) else { return }
        await download(client: client, fullRefresh: isComplete && stale)
    }

    // MARK: - Search

    /// Instant tokenized search over name / set / number. Every token must match;
    /// name-prefix matches rank first.
    func search(_ query: String, limit: Int = 50) -> [CardIdentity] {
        loadFromDiskIfNeeded()
        let tokens = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return [] }

        var prefixHits: [CardIdentity] = []
        var containsHits: [CardIdentity] = []
        for (i, key) in searchKeys.enumerated() {
            guard tokens.allSatisfy({ key.contains($0) }) else { continue }
            if cards[i].name.lowercased().hasPrefix(tokens[0]) {
                prefixHits.append(cards[i])
            } else {
                containsHits.append(cards[i])
            }
            if prefixHits.count >= limit { break }
        }
        return Array((prefixHits + containsHits).prefix(limit))
    }

    /// Default browse feed: the newest cards in the catalog (stored newest-first).
    func browse(limit: Int = 30) -> [CardIdentity] {
        loadFromDiskIfNeeded()
        return Array(cards.prefix(limit))
    }

    // MARK: - Download (paginated, incremental, newest-first)

    private func download(client: PokemonTCGClient, fullRefresh: Bool) async {
        isDownloading = true
        defer { isDownloading = false }

        var fetched: [CardIdentity] = fullRefresh ? [] : cards
        var seen = Set(fetched.map(\.id))
        var page = fullRefresh ? 1 : (fetched.count / Self.pageSize) + 1
        var consecutiveFailures = 0

        while true {
            do {
                let (batch, totalCount) = try await client.fetchCatalogPage(page: page, pageSize: Self.pageSize)
                consecutiveFailures = 0
                let fresh = batch.filter { seen.insert($0.id).inserted }
                fetched.append(contentsOf: fresh)
                apply(fetched, complete: fetched.count >= totalCount || batch.isEmpty)
                saveToDisk()
                if isComplete { break }
                page += 1
                // Pace requests to stay well under the keyless rate limit.
                try? await Task.sleep(for: .milliseconds(1500))
            } catch {
                consecutiveFailures += 1
                // Back off on rate limits / flakes; give up after a few misses —
                // partial progress is saved and resumes next launch.
                if consecutiveFailures >= 3 { break }
                try? await Task.sleep(for: .seconds(10))
            }
        }
        lastRefreshed = Date()
        saveToDisk()
    }

    private func apply(_ newCards: [CardIdentity], complete: Bool) {
        cards = newCards
        searchKeys = newCards.map { "\($0.name) \($0.setName) \($0.setCode) \($0.cardNumber)".lowercased() }
        isComplete = complete
    }

    // MARK: - Disk persistence

    private static let pageSize = 250

    private struct CacheFile: Codable {
        var cards: [CardIdentity]
        var isComplete: Bool
        var lastRefreshed: Date?
    }

    private var cacheURL: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("card-catalog-v1.json")
    }

    private func loadFromDiskIfNeeded() {
        guard !loadedFromDisk else { return }
        loadedFromDisk = true
        guard let url = cacheURL,
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(CacheFile.self, from: data)
        else { return }
        apply(file.cards, complete: file.isComplete)
        lastRefreshed = file.lastRefreshed
    }

    private func saveToDisk() {
        guard let url = cacheURL else { return }
        let file = CacheFile(cards: cards, isComplete: isComplete, lastRefreshed: lastRefreshed)
        if let data = try? JSONEncoder().encode(file) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
