import Foundation

// MARK: - Live Market Data via JustTCG (TCGplayer prices)

/// `MarketDataService` backed by JustTCG, which relays TCGplayer pricing.
/// Resolves a card's name/set/number via the pokemontcg.io catalog, then queries
/// JustTCG for the Near Mint price. Falls back are handled by `FallbackMarketDataService`.
final class JustTCGMarketDataService: MarketDataService {
    private let justTCG: JustTCGClient
    private let catalog: PokemonTCGClient

    init(apiKey: String, catalog: PokemonTCGClient = PokemonTCGClient()) {
        self.justTCG = JustTCGClient(apiKey: apiKey)
        self.catalog = catalog
    }

    func snapshot(for cardId: String) async throws -> MarketSnapshot {
        let card = try await resolveIdentity(cardId)
        guard let variant = try await justTCG.bestVariant(
            name: card.name, set: card.setName, number: card.number, game: card.game
        ) else {
            throw CIQError.marketDataUnavailable
        }
        return JustTCGSnapshotBuilder.snapshot(
            name: card.name,
            variant: variant,
            imageURL: card.imageURL
        )
    }

    func priceHistory(for cardId: String, range: TimeRange) async throws -> [PriceHistoryPoint] {
        let card = try await resolveIdentity(cardId)
        guard let variant = try await justTCG.bestVariant(
            name: card.name, set: card.setName, number: card.number, game: card.game
        ) else {
            return []
        }
        return (variant.priceHistory ?? []).map {
            PriceHistoryPoint(date: Date(timeIntervalSince1970: $0.t), price: $0.p)
        }
    }

    /// What JustTCG needs to find a card, resolved from the local catalog when
    /// possible (works for Japanese cards, whose ids the pokemontcg.io catalog
    /// doesn't know), with a network lookup as the fallback.
    private struct ResolvedCard {
        var name: String
        var setName: String?
        var number: String?
        var imageURL: String?
        var game: String
    }

    private func resolveIdentity(_ cardId: String) async throws -> ResolvedCard {
        if let local = await CardCatalogStore.shared.identity(for: cardId) {
            return ResolvedCard(
                name: local.name,
                setName: local.setName,
                number: local.cardNumber.split(separator: "/").first.map(String.init),
                imageURL: local.imageURL,
                game: local.language == "ja" ? "pokemon-japan" : "pokemon"
            )
        }
        let card = try await catalog.card(id: cardId)
        return ResolvedCard(
            name: card.name,
            setName: card.set?.name,
            number: card.number,
            imageURL: card.images?.large ?? card.images?.small,
            game: "pokemon"
        )
    }

    func trendingCards() async throws -> [CardIdentity] {
        (try? await catalog.searchRaw(query: "(set.id:sv6 OR set.id:sv7 OR set.id:sv8) rarity:\"Special Illustration Rare\"", pageSize: 10)) ?? []
    }
}

// MARK: - JustTCG API Client

final class JustTCGClient {
    private let baseURL = URL(string: "https://api.justtcg.com/v1")!
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// Resolve the best (Near Mint / Normal) pricing variant for a card.
    ///
    /// NOTE: JustTCG's GET /cards is primarily identifier-based (tcgplayerId, cardId).
    /// The name/set/number query below is a best-effort lookup pending verification
    /// with a live key — once a key is available, confirm the exact search params
    /// (or switch to a tcgplayerId mapping) against the live API.
    func bestVariant(name: String, set: String?, number: String?, game: String = "pokemon") async throws -> JustTCGVariant? {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("cards"),
            resolvingAgainstBaseURL: false
        )!
        var items = [
            URLQueryItem(name: "game", value: game),
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "condition", value: "NM")
        ]
        if let set { items.append(URLQueryItem(name: "set", value: set)) }
        if let number { items.append(URLQueryItem(name: "number", value: number)) }
        comps.queryItems = items

        var request = URLRequest(url: comps.url!)
        request.timeoutInterval = 15
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw CIQError.marketDataUnavailable
            }
            let decoded = try JSONDecoder().decode(JustTCGResponse.self, from: data)
            let variants = decoded.data.flatMap { $0.variants }
            // Prefer Normal printing with a positive price; else any priced variant.
            return variants.first {
                ($0.printing ?? "Normal").localizedCaseInsensitiveContains("normal") && ($0.price ?? 0) > 0
            } ?? variants.first { ($0.price ?? 0) > 0 }
        } catch let error as CIQError {
            throw error
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw CIQError.networkTimeout
        } catch {
            throw CIQError.marketDataUnavailable
        }
    }
}

// MARK: - JustTCG DTOs

struct JustTCGResponse: Decodable {
    let data: [JustTCGCard]
}

struct JustTCGCard: Decodable {
    let id: String?
    let name: String?
    let set: String?
    let setName: String?
    let number: String?
    let tcgplayerId: String?
    let variants: [JustTCGVariant]

    enum CodingKeys: String, CodingKey {
        case id, name, set, number, tcgplayerId, variants
        case setName = "set_name"
    }
}

struct JustTCGVariant: Decodable {
    let condition: String?
    let printing: String?
    let price: Double?
    let priceChange24hr: Double?
    let lastUpdated: Double?
    let priceHistory: [PricePoint]?

    struct PricePoint: Decodable {
        let p: Double
        let t: Double
    }
}

// MARK: - Snapshot Builder

enum JustTCGSnapshotBuilder {
    // Heuristic graded multipliers (JustTCG has no graded data — placeholder, same as pokemontcg path).
    private static let psa8Multiplier = 1.1
    private static let psa9Multiplier = 1.8
    private static let psa10Multiplier = 4.0

    static func snapshot(name: String, variant: JustTCGVariant, imageURL: String?) -> MarketSnapshot {
        let raw = variant.price ?? 0
        let history = variant.priceHistory ?? []
        let updated = variant.lastUpdated.map { Date(timeIntervalSince1970: $0) } ?? Date()

        var sales: [ComparableSale] = []
        if raw > 0 {
            sales.append(ComparableSale(
                id: "justtcg-\(name)",
                marketplace: "TCGplayer",
                title: "\(name) — TCGplayer market (raw)",
                salePrice: raw,
                shippingPrice: 0,
                saleDate: updated,
                condition: variant.condition ?? "Near Mint",
                gradingCompany: nil,
                grade: nil,
                matchQuality: .exact,
                imageURL: imageURL
            ))
        }

        return MarketSnapshot(
            rawEstimatedValue: raw,
            psa8EstimatedValue: raw * psa8Multiplier,
            psa9EstimatedValue: raw * psa9Multiplier,
            psa10EstimatedValue: raw * psa10Multiplier,
            thirtyDayChangePercentage: thirtyDayChange(history),
            ninetyDayChangePercentage: 0,
            oneYearChangePercentage: 0,
            salesVolume30Days: 0,
            liquidityScore: raw > 0 ? 0.7 : 0.2,
            recentSales: sales,
            updatedAt: updated
        )
    }

    private static func thirtyDayChange(_ history: [JustTCGVariant.PricePoint]) -> Double {
        guard history.count > 1, let first = history.first, let last = history.last, first.p > 0 else { return 0 }
        return ((last.p - first.p) / first.p) * 100
    }
}

// MARK: - Fallback Composite

/// Tries `primary` first; falls back to `fallback` when the primary throws or
/// returns an unpriced/empty result. Lets JustTCG lead with pokemontcg.io as backstop.
final class FallbackMarketDataService: MarketDataService {
    private let primary: any MarketDataService
    private let fallback: any MarketDataService

    init(primary: any MarketDataService, fallback: any MarketDataService) {
        self.primary = primary
        self.fallback = fallback
    }

    func snapshot(for cardId: String) async throws -> MarketSnapshot {
        if let snapshot = try? await primary.snapshot(for: cardId), snapshot.rawEstimatedValue > 0 {
            return snapshot
        }
        return try await fallback.snapshot(for: cardId)
    }

    func priceHistory(for cardId: String, range: TimeRange) async throws -> [PriceHistoryPoint] {
        if let history = try? await primary.priceHistory(for: cardId, range: range), !history.isEmpty {
            return history
        }
        return (try? await fallback.priceHistory(for: cardId, range: range)) ?? []
    }

    func trendingCards() async throws -> [CardIdentity] {
        if let cards = try? await primary.trendingCards(), !cards.isEmpty {
            return cards
        }
        return try await fallback.trendingCards()
    }
}

// MARK: - Factory

enum MarketDataFactory {
    /// Returns the live market service: JustTCG (with pokemontcg.io fallback) when a
    /// key is configured, otherwise pokemontcg.io alone.
    static func make() -> any MarketDataService {
        let pokemon = PokemonTCGMarketDataService()
        if let key = PricingConfig.justTCGAPIKey, !key.isEmpty {
            return FallbackMarketDataService(
                primary: JustTCGMarketDataService(apiKey: key),
                fallback: pokemon
            )
        }
        return pokemon
    }
}
