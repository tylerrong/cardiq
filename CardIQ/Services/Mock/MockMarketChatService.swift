import Foundation

final class MockMarketChatService: MarketChatService {
    func sendMessage(_ text: String, context: MarketChatContext) async throws -> MarketChatResponse {
        try await Task.sleep(for: .milliseconds(Int.random(in: 600...1200)))

        let lowered = text.lowercased()

        if lowered.contains("trending") || lowered.contains("hot") || lowered.contains("popular") {
            return trendingResponse()
        }
        if lowered.contains("cheapest") || lowered.contains("budget") || lowered.contains("under") {
            return budgetResponse()
        }
        if lowered.contains("best") && (lowered.contains("grade") || lowered.contains("grading") || lowered.contains("invest")) {
            return gradingPicksResponse()
        }
        if lowered.contains("charizard") {
            return charizardResponse()
        }
        if lowered.contains("pikachu") {
            return pikachuResponse()
        }
        if lowered.contains("drop") || lowered.contains("falling") || lowered.contains("losing") || lowered.contains("down") {
            return decliningResponse()
        }
        if lowered.contains("roi") || lowered.contains("profit") || lowered.contains("worth grading") {
            return roiResponse()
        }
        if lowered.contains("portfolio") || lowered.contains("collection") || lowered.contains("my cards") {
            return portfolioResponse(context: context)
        }
        if lowered.contains("compare") || lowered.contains("vs") || lowered.contains("versus") {
            return compareResponse()
        }

        return generalResponse(query: text)
    }

    private func trendingResponse() -> MarketChatResponse {
        MarketChatResponse(
            text: "Here are the hottest cards right now based on 30-day price movement and sales volume:\n\n**Pikachu ex SIR** from Twilight Masquerade is up 15% this month with strong demand. **Rayquaza ex Hyper Rare** from Stellar Crown is also surging at +12%, driven by competitive play demand.\n\nCharizard ex SAR from Obsidian Flames continues its steady climb at +5.2% — it's a collector staple that rarely dips.",
            referencedCards: [MockSeedData.cards[3], MockSeedData.cards[11], MockSeedData.cards[0]],
            dataPulls: [
                MarketChatDataPull(label: "Raw", cardName: "Pikachu ex SIR", value: "$95.00", changePercent: 15.0),
                MarketChatDataPull(label: "Raw", cardName: "Rayquaza ex HR", value: "$110.00", changePercent: 12.0),
                MarketChatDataPull(label: "Raw", cardName: "Charizard ex SAR", value: "$185.00", changePercent: 5.2),
            ]
        )
    }

    private func budgetResponse() -> MarketChatResponse {
        MarketChatResponse(
            text: "Looking for value picks? Here are some cards with strong grading upside at lower buy-in prices:\n\n**Eevee Illustration Rare** (SV05) at $18 raw has a PSA 10 value of $110 — that's a 6x multiplier if you hit the grade. **Koraidon ex** (SV01) at $12 raw is one of the cheapest ex cards with PSA 10 potential at $95.\n\nBulbasaur from 151 at just $1.50 is almost not worth grading individually, but in bulk it can work.",
            referencedCards: [MockSeedData.cards[6], MockSeedData.cards[7], MockSeedData.cards[10]],
            dataPulls: [
                MarketChatDataPull(label: "Raw → PSA 10", cardName: "Eevee IR", value: "$18 → $110", changePercent: nil),
                MarketChatDataPull(label: "Raw → PSA 10", cardName: "Koraidon ex", value: "$12 → $95", changePercent: nil),
                MarketChatDataPull(label: "Raw → PSA 10", cardName: "Bulbasaur 151", value: "$1.50 → $35", changePercent: nil),
            ]
        )
    }

    private func gradingPicksResponse() -> MarketChatResponse {
        MarketChatResponse(
            text: "Based on current market spreads, these cards have the best grading economics:\n\n**Umbreon ex SIR** has the highest PSA 10 probability in our database at 40%, with a raw-to-gem spread of $145 → $620. After grading costs (~$45), the expected profit is substantial.\n\n**Pikachu ex SIR** is close behind at 45% PSA 10 probability with a $95 → $475 spread. Near-perfect centering makes this the safer pick.\n\nAvoid grading **Miraidon ex SAR** right now — the centering issues we see typically cap it at PSA 8, and the PSA 8 value ($70) barely covers grading costs above the raw price ($55).",
            referencedCards: [MockSeedData.cards[1], MockSeedData.cards[3], MockSeedData.cards[2]],
            dataPulls: [
                MarketChatDataPull(label: "PSA 10 Prob", cardName: "Umbreon ex SIR", value: "40%", changePercent: nil),
                MarketChatDataPull(label: "PSA 10 Prob", cardName: "Pikachu ex SIR", value: "45%", changePercent: nil),
                MarketChatDataPull(label: "PSA 10 Prob", cardName: "Miraidon ex SAR", value: "2%", changePercent: nil),
            ]
        )
    }

    private func charizardResponse() -> MarketChatResponse {
        let market = MockSeedData.marketSnapshot(for: "sv4-227")
        return MarketChatResponse(
            text: "**Charizard ex SAR** (Obsidian Flames 227/197) is one of the most liquid modern chase cards.\n\nThe raw market is at **\(market.rawEstimatedValue.currencyFormatted)** with 127 sales in the last 30 days. PSA 10 copies are trading at **\(market.psa10EstimatedValue.currencyFormatted)** — that's a 4.6x grading multiplier.\n\nThe card is up 5.2% this month and 35% over the past year. Long-term demand for Charizard cards has historically been very resilient. This is a strong hold or grade candidate if your copy is in good shape.",
            referencedCards: [MockSeedData.cards[0]],
            dataPulls: [
                MarketChatDataPull(label: "Raw", cardName: "Charizard ex SAR", value: market.rawEstimatedValue.currencyFormatted, changePercent: 5.2),
                MarketChatDataPull(label: "PSA 9", cardName: "Charizard ex SAR", value: market.psa9EstimatedValue.currencyFormatted, changePercent: nil),
                MarketChatDataPull(label: "PSA 10", cardName: "Charizard ex SAR", value: market.psa10EstimatedValue.currencyFormatted, changePercent: nil),
                MarketChatDataPull(label: "30D Volume", cardName: "Charizard ex SAR", value: "127 sales", changePercent: nil),
            ]
        )
    }

    private func pikachuResponse() -> MarketChatResponse {
        let market = MockSeedData.marketSnapshot(for: "sv6-230")
        return MarketChatResponse(
            text: "**Pikachu ex SIR** (Twilight Masquerade 230/167) is the standout Pikachu of the Scarlet & Violet era.\n\nCurrently at **\(market.rawEstimatedValue.currencyFormatted)** raw with a PSA 10 value of **\(market.psa10EstimatedValue.currencyFormatted)**. This card has been on a tear — up 15% in 30 days and 45% year-over-year.\n\nThe illustration quality and Pikachu's icon status drive consistent collector demand. With 45% PSA 10 probability and excellent centering typically seen in this print run, this is one of the best grading candidates in the current market.",
            referencedCards: [MockSeedData.cards[3]],
            dataPulls: [
                MarketChatDataPull(label: "Raw", cardName: "Pikachu ex SIR", value: market.rawEstimatedValue.currencyFormatted, changePercent: 15.0),
                MarketChatDataPull(label: "PSA 10", cardName: "Pikachu ex SIR", value: market.psa10EstimatedValue.currencyFormatted, changePercent: nil),
                MarketChatDataPull(label: "1Y Change", cardName: "Pikachu ex SIR", value: "+45.0%", changePercent: 45.0),
            ]
        )
    }

    private func decliningResponse() -> MarketChatResponse {
        MarketChatResponse(
            text: "A few cards in the database are showing price softness:\n\n**Miraidon ex SAR** is down 8% this month and 20% over the past year. Post-rotation competitive play demand has faded.\n\n**Gardevoir ex FA** is off 1.5% this month — typical for a mid-tier full art as newer sets compete for attention.\n\n**Koraidon ex** continues to slide at -4% monthly. At $12 raw, it may be nearing a floor, but there's no catalyst for a reversal yet.\n\nIf you hold any of these, consider whether the capital is better deployed elsewhere.",
            referencedCards: [MockSeedData.cards[2], MockSeedData.cards[5], MockSeedData.cards[7]],
            dataPulls: [
                MarketChatDataPull(label: "Raw", cardName: "Miraidon ex SAR", value: "$55.00", changePercent: -8.0),
                MarketChatDataPull(label: "Raw", cardName: "Gardevoir ex FA", value: "$22.00", changePercent: -1.5),
                MarketChatDataPull(label: "Raw", cardName: "Koraidon ex", value: "$12.00", changePercent: -4.0),
            ]
        )
    }

    private func roiResponse() -> MarketChatResponse {
        MarketChatResponse(
            text: "Here's a quick ROI snapshot for the top grading candidates:\n\nAssuming $25 PSA fee + $15 shipping + $5 insurance ($45 total grading cost):\n\n**Pikachu ex SIR**: Expected graded value ~$312, expected profit ~$178 after selling fees. **Strong grade recommendation.**\n\n**Charizard ex SAR**: Expected graded value ~$445, expected profit ~$220. **Grade if centering is clean.**\n\n**Umbreon ex SIR**: Expected graded value ~$370, expected profit ~$180. **Grade — high PSA 10 odds.**\n\nUse the Grade ROI calculator on any scanned card for a detailed breakdown with your actual purchase price.",
            referencedCards: [MockSeedData.cards[3], MockSeedData.cards[0], MockSeedData.cards[1]],
            dataPulls: [
                MarketChatDataPull(label: "Expected Profit", cardName: "Pikachu ex SIR", value: "+$178", changePercent: nil),
                MarketChatDataPull(label: "Expected Profit", cardName: "Charizard ex SAR", value: "+$220", changePercent: nil),
                MarketChatDataPull(label: "Expected Profit", cardName: "Umbreon ex SIR", value: "+$180", changePercent: nil),
            ]
        )
    }

    private func portfolioResponse(context: MarketChatContext) -> MarketChatResponse {
        let count = context.collectionCardIds.count
        if count == 0 {
            return MarketChatResponse(
                text: "You don't have any cards in your collection yet. Scan a card or add one manually to start tracking your portfolio. Once you have cards, I can give you personalized market insights, recommend which to grade, and alert you to price movements.",
                referencedCards: [],
                dataPulls: []
            )
        }
        return MarketChatResponse(
            text: "Based on your collection of \(count) cards:\n\nYour strongest performer is likely **Charizard ex SAR** if you picked it up at the prices I'm seeing — it's up 35% over the past year.\n\nI'd recommend scanning any ungraded cards to see if they're worth sending to PSA. The Pikachu ex SIR and Umbreon ex SIR in particular have strong grading economics right now.\n\nWant me to pull detailed data on any specific card in your collection?",
            referencedCards: [MockSeedData.cards[0], MockSeedData.cards[3]],
            dataPulls: [
                MarketChatDataPull(label: "Collection", cardName: "Total Cards", value: "\(count)", changePercent: nil),
            ]
        )
    }

    private func compareResponse() -> MarketChatResponse {
        MarketChatResponse(
            text: "Let me compare two popular chase cards:\n\n**Charizard ex SAR** vs **Umbreon ex SIR**\n\n| Metric | Charizard | Umbreon |\n|--------|-----------|----------|\n| Raw | $185 | $145 |\n| PSA 10 | $850 | $620 |\n| 30D Volume | 127 | 89 |\n| Liquidity | 85% | 78% |\n| PSA 10 Prob | 25% | 40% |\n\nCharizard has the higher ceiling but Umbreon has better PSA 10 odds. For pure grading ROI, Umbreon may be the smarter play. For long-term hold value, Charizard's brand power is hard to beat.\n\nWant me to compare specific cards? Just ask \"compare X vs Y\".",
            referencedCards: [MockSeedData.cards[0], MockSeedData.cards[1]],
            dataPulls: [
                MarketChatDataPull(label: "PSA 10", cardName: "Charizard ex SAR", value: "$850", changePercent: nil),
                MarketChatDataPull(label: "PSA 10", cardName: "Umbreon ex SIR", value: "$620", changePercent: nil),
            ]
        )
    }

    private func generalResponse(query: String) -> MarketChatResponse {
        MarketChatResponse(
            text: "I can help you with market intelligence for modern Pokémon cards. Here are some things you can ask me:\n\n• **\"What's trending?\"** — See the hottest cards right now\n• **\"Tell me about Charizard\"** — Deep dive on any card\n• **\"Best cards to grade?\"** — Top grading ROI picks\n• **\"What's dropping?\"** — Cards losing value\n• **\"Compare X vs Y\"** — Side-by-side analysis\n• **\"Budget picks under $20\"** — Value opportunities\n• **\"Is it worth grading?\"** — ROI breakdown\n• **\"How's my portfolio?\"** — Collection insights\n\nWhat would you like to know?",
            referencedCards: [],
            dataPulls: []
        )
    }
}
