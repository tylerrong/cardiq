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

    /// Japanese catalog (TCGdex) — bundled snapshot, loaded alongside the
    /// English catalog. Kept separate so the English download/refresh
    /// bookkeeping (page counts, deltas) stays untouched.
    private var jaCards: [CardIdentity] = []
    private var jaSearchKeys: [String] = []

    /// Some cards are available to search against (partial is fine — newest first).
    var isReady: Bool { !cards.isEmpty }

    /// The whole catalog is on disk — local misses are authoritative.
    var hasFullCatalog: Bool { isComplete }

    // MARK: - Bootstrap

    /// Load the disk cache (or the snapshot bundled with the app), then top up
    /// from the network if incomplete or stale. Call once at launch; safe to
    /// call again (no-ops while a download runs).
    func bootstrap(client: PokemonTCGClient = PokemonTCGClient()) async {
        loadFromDiskIfNeeded()
        let stale = lastRefreshed.map { Date().timeIntervalSince($0) > 7 * 86_400 } ?? true
        guard !isDownloading, (!isComplete || stale) else { return }
        isDownloading = true
        defer { isDownloading = false }
        if isComplete {
            await topUp(client: client)     // cheap delta: only fetch until known cards
        } else {
            await download(client: client)  // finish the initial full download
        }
        lastRefreshed = Date()
        saveToDisk()
    }

    // MARK: - Search

    /// Instant tokenized search over name / set / number, across both the
    /// English and Japanese catalogs. Every token must match; name-prefix
    /// matches rank first. (CJK sequences survive the tokenizer — they're
    /// alphanumerics — so Japanese queries match Japanese names.)
    func search(_ query: String, limit: Int = 50) -> [CardIdentity] {
        loadFromDiskIfNeeded()
        let tokens = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return [] }

        var prefixHits: [CardIdentity] = []
        var containsHits: [CardIdentity] = []
        for (allCards, keys) in [(cards, searchKeys), (jaCards, jaSearchKeys)] {
            for (i, key) in keys.enumerated() {
                guard tokens.allSatisfy({ key.contains($0) }) else { continue }
                if allCards[i].name.lowercased().hasPrefix(tokens[0]) {
                    prefixHits.append(allCards[i])
                } else {
                    containsHits.append(allCards[i])
                }
                if prefixHits.count >= limit { break }
            }
        }
        return Array((prefixHits + containsHits).prefix(limit))
    }

    /// Collector-number lookup ("NNN/NNN") for scan identification. Numeric
    /// compare so OCR's "25/78" matches a zero-padded "025/078".
    func searchByNumber(_ number: String, total: String, language: String? = nil) -> [CardIdentity] {
        loadFromDiskIfNeeded()
        guard let num = Int(number), let tot = Int(total) else { return [] }
        let pools = language == "ja" ? [jaCards] : (language == "en" ? [cards] : [cards, jaCards])
        var hits: [CardIdentity] = []
        for pool in pools {
            for card in pool {
                let parts = card.cardNumber.split(separator: "/")
                guard parts.count == 2, Int(parts[0]) == num, Int(parts[1]) == tot else { continue }
                hits.append(card)
            }
        }
        return hits
    }

    /// Identity lookup by catalog id, across both languages (used by pricing to
    /// resolve name/set/number without a network hit).
    func identity(for id: String) -> CardIdentity? {
        loadFromDiskIfNeeded()
        return cards.first { $0.id == id } ?? jaCards.first { $0.id == id }
    }

    /// Default browse feed: the newest cards in the catalog (stored newest-first).
    func browse(limit: Int = 30) -> [CardIdentity] {
        loadFromDiskIfNeeded()
        return Array(cards.prefix(limit))
    }

    // MARK: - Download (paginated, incremental, newest-first)

    /// Initial download: fetch pages in concurrent batches of 4 for speed,
    /// saving after every batch so partial progress survives relaunch.
    private func download(client: PokemonTCGClient) async {
        var fetched: [CardIdentity] = cards
        var seen = Set(fetched.map(\.id))
        var nextPage = (fetched.count / Self.pageSize) + 1
        var failures = 0

        while true {
            let pages = Array(nextPage..<(nextPage + Self.concurrentPages))
            var batches: [Int: [CardIdentity]] = [:]
            var totalCount = Int.max
            await withTaskGroup(of: (Int, [CardIdentity], Int)?.self) { group in
                for page in pages {
                    group.addTask {
                        guard let (batch, total) = try? await client.fetchCatalogPage(page: page, pageSize: Self.pageSize)
                        else { return nil }
                        return (page, batch, total)
                    }
                }
                for await result in group {
                    if let (page, batch, total) = result {
                        batches[page] = batch
                        totalCount = min(totalCount, total)
                    }
                }
            }

            if batches.isEmpty {
                failures += 1
                // Rate limit / outage: back off, then give up until next launch —
                // everything fetched so far is already on disk.
                if failures >= 3 { break }
                try? await Task.sleep(for: .seconds(15))
                continue
            }
            failures = 0

            var sawShortPage = false
            for page in pages {
                guard let batch = batches[page] else { break }  // keep pages contiguous
                fetched.append(contentsOf: batch.filter { seen.insert($0.id).inserted })
                nextPage = page + 1
                if batch.count < Self.pageSize { sawShortPage = true }
            }
            apply(fetched, complete: sawShortPage || (totalCount != .max && fetched.count >= totalCount))
            saveToDisk()
            if isComplete { break }
            try? await Task.sleep(for: .milliseconds(400))
        }
    }

    /// Weekly refresh once the catalog is complete: pages are newest-first, so
    /// fetch from page 1 and stop at the first page with nothing new.
    private func topUp(client: PokemonTCGClient) async {
        var known = Set(cards.map(\.id))
        var fresh: [CardIdentity] = []
        var page = 1
        while page <= 20 {  // safety bound; a week of new sets is 1-2 pages
            guard let (batch, _) = try? await client.fetchCatalogPage(page: page, pageSize: Self.pageSize)
            else { break }
            let new = batch.filter { known.insert($0.id).inserted }
            fresh.append(contentsOf: new)
            if new.count < batch.count || batch.count < Self.pageSize { break }
            page += 1
            try? await Task.sleep(for: .milliseconds(400))
        }
        if !fresh.isEmpty {
            apply(fresh + cards, complete: true)
            saveToDisk()
        }
    }

    private func apply(_ newCards: [CardIdentity], complete: Bool) {
        cards = newCards
        searchKeys = newCards.map { "\($0.name) \($0.setName) \($0.setCode) \($0.cardNumber)".lowercased() }
        isComplete = complete
    }

    // MARK: - Disk persistence

    private static let pageSize = 250
    private static let concurrentPages = 4

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

        // Japanese catalog: always served from the bundled snapshot.
        if let file = Self.loadBundledSeed(named: "card-catalog-seed-ja") {
            jaCards = file.cards
            jaSearchKeys = file.cards.map { "\($0.name) \($0.setName) \($0.setCode) \($0.cardNumber)".lowercased() }
        }

        // English catalog: prefer the on-disk cache (has post-install refreshes)...
        if let url = cacheURL,
           let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(CacheFile.self, from: data),
           !file.cards.isEmpty {
            apply(file.cards, complete: file.isComplete)
            lastRefreshed = file.lastRefreshed
            return
        }

        // ...otherwise fall back to the snapshot bundled with the app, so the
        // full catalog is searchable immediately on first launch.
        if let file = Self.loadBundledSeed(named: "card-catalog-seed") {
            apply(file.cards, complete: file.isComplete)
            lastRefreshed = file.lastRefreshed
        }
    }

    private static func loadBundledSeed(named name: String) -> CacheFile? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(CacheFile.self, from: data)
    }

    private func saveToDisk() {
        guard let url = cacheURL else { return }
        let file = CacheFile(cards: cards, isComplete: isComplete, lastRefreshed: lastRefreshed)
        if let data = try? JSONEncoder().encode(file) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
