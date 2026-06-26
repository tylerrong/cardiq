import Foundation

/// Live `MarketDataService` backed by pokemontcg.io, which embeds TCGplayer (USD)
/// and Cardmarket (EUR) pricing in each card payload.
///
/// Real vs. derived (be honest about this in the UI):
/// - `rawEstimatedValue`        → TCGplayer market price (REAL).
/// - `thirtyDayChangePercentage`→ Cardmarket avg1 vs avg30 (REAL-ish trend).
/// - `recentSales`              → TCGplayer price tiers as reference points (real prices, not literal sales).
/// - `psa8/9/10EstimatedValue`  → heuristic multipliers on raw (PLACEHOLDER until real graded comps).
/// - `salesVolume30Days`, 90d/1y change → not exposed by this source; left at 0 (honest unknown).
final class PokemonTCGMarketDataService: MarketDataService {
    private let client: PokemonTCGClient

    init(client: PokemonTCGClient = PokemonTCGClient()) {
        self.client = client
    }

    func snapshot(for cardId: String) async throws -> MarketSnapshot {
        let card = try await client.card(id: cardId)
        return MarketSnapshotBuilder.snapshot(from: card)
    }

    func priceHistory(for cardId: String, range: TimeRange) async throws -> [PriceHistoryPoint] {
        let card = try await client.card(id: cardId)
        return MarketSnapshotBuilder.priceHistory(from: card)
    }

    func trendingCards() async throws -> [CardIdentity] {
        (try? await client.searchRaw(query: "rarity:\"Special Illustration Rare\"", pageSize: 10)) ?? []
    }
}

enum MarketSnapshotBuilder {
    // Heuristic graded multipliers on a raw NM price. Placeholder pending real
    // PSA/CGC sold comps; modern Pokémon chase cards vary widely by card.
    private static let psa8Multiplier = 1.1
    private static let psa9Multiplier = 1.8
    private static let psa10Multiplier = 4.0

    static func snapshot(from card: PokemonTCGCard) -> MarketSnapshot {
        let raw = rawValue(from: card.tcgplayer)
        return MarketSnapshot(
            rawEstimatedValue: raw,
            psa8EstimatedValue: raw * psa8Multiplier,
            psa9EstimatedValue: raw * psa9Multiplier,
            psa10EstimatedValue: raw * psa10Multiplier,
            thirtyDayChangePercentage: thirtyDayChange(from: card.cardmarket),
            ninetyDayChangePercentage: 0,
            oneYearChangePercentage: 0,
            salesVolume30Days: 0,
            liquidityScore: raw > 0 ? 0.6 : 0.2,
            recentSales: referenceSales(from: card),
            updatedAt: parseDate(card.tcgplayer?.updatedAt) ?? Date()
        )
    }

    static func priceHistory(from card: PokemonTCGCard) -> [PriceHistoryPoint] {
        guard let cm = card.cardmarket?.prices else { return [] }
        // Small real-ish series from Cardmarket rolling averages (avg30 → avg7 → avg1 → trend).
        let now = Date()
        var points: [PriceHistoryPoint] = []
        if let avg30 = cm.avg30 { points.append(.init(date: now.addingTimeInterval(-30 * 86_400), price: avg30)) }
        if let avg7 = cm.avg7 { points.append(.init(date: now.addingTimeInterval(-7 * 86_400), price: avg7)) }
        if let avg1 = cm.avg1 { points.append(.init(date: now.addingTimeInterval(-86_400), price: avg1)) }
        if let trend = cm.trendPrice { points.append(.init(date: now, price: trend)) }
        return points
    }

    // MARK: - Helpers

    private static func rawValue(from tcg: PokemonTCGCard.TCGPlayer?) -> Double {
        guard let prices = tcg?.prices else { return 0 }
        // Prefer holofoil, then reverse holo, then normal — typical chase finishes first.
        let tier = prices["holofoil"] ?? prices["reverseHolofoil"] ?? prices["normal"] ?? prices.values.first
        return tier?.market ?? tier?.mid ?? tier?.low ?? 0
    }

    private static func thirtyDayChange(from cm: PokemonTCGCard.Cardmarket?) -> Double {
        guard let p = cm?.prices, let avg30 = p.avg30, let avg1 = p.avg1, avg30 > 0 else { return 0 }
        return ((avg1 - avg30) / avg30) * 100
    }

    private static func referenceSales(from card: PokemonTCGCard) -> [ComparableSale] {
        guard let prices = card.tcgplayer?.prices else { return [] }
        let tier = prices["holofoil"] ?? prices["reverseHolofoil"] ?? prices["normal"] ?? prices.values.first
        guard let tier else { return [] }

        let now = Date()
        let entries: [(String, Double?)] = [
            ("TCGplayer market", tier.market),
            ("TCGplayer mid", tier.mid),
            ("TCGplayer low", tier.low),
            ("TCGplayer high", tier.high)
        ]

        return entries.enumerated().compactMap { item in
            let index = item.offset
            guard let price = item.element.1, price > 0 else { return nil }
            return ComparableSale(
                id: "\(card.id)-\(index)",
                marketplace: "TCGplayer",
                title: "\(card.name) — \(item.element.0) (raw)",
                salePrice: price,
                shippingPrice: 0,
                saleDate: now.addingTimeInterval(Double(-index) * 86_400),
                condition: "Near Mint (raw)",
                gradingCompany: nil,
                grade: nil,
                matchQuality: index == 0 ? .exact : .strong,
                imageURL: card.images?.large ?? card.images?.small
            )
        }
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)
    }
}
