import Foundation

enum MockSeedData {

    static let cards: [CardIdentity] = [
        CardIdentity(
            id: "sv4-227", category: .pokemon, name: "Charizard ex",
            setName: "Obsidian Flames", setCode: "SV04", cardNumber: "227/197",
            year: 2023, variant: "Special Art Rare", rarity: .specialArt,
            language: "en", isFirstEdition: false, isHolo: true, isReverseHolo: false,
            imageURL: nil, identificationConfidence: 0.97
        ),
        CardIdentity(
            id: "sv3pt5-207", category: .pokemon, name: "Umbreon ex",
            setName: "151", setCode: "SV3.5", cardNumber: "207/165",
            year: 2023, variant: "Special Illustration Rare", rarity: .specialIllustrationRare,
            language: "en", isFirstEdition: false, isHolo: true, isReverseHolo: false,
            imageURL: nil, identificationConfidence: 0.95
        ),
        CardIdentity(
            id: "sv1-254", category: .pokemon, name: "Miraidon ex",
            setName: "Scarlet & Violet", setCode: "SV01", cardNumber: "254/198",
            year: 2023, variant: "Special Art Rare", rarity: .specialArt,
            language: "en", isFirstEdition: false, isHolo: true, isReverseHolo: false,
            imageURL: nil, identificationConfidence: 0.94
        ),
        CardIdentity(
            id: "sv6-230", category: .pokemon, name: "Pikachu ex",
            setName: "Twilight Masquerade", setCode: "SV06", cardNumber: "230/167",
            year: 2024, variant: "Special Illustration Rare", rarity: .specialIllustrationRare,
            language: "en", isFirstEdition: false, isHolo: true, isReverseHolo: false,
            imageURL: nil, identificationConfidence: 0.96
        ),
        CardIdentity(
            id: "sv3-197", category: .pokemon, name: "Mew ex",
            setName: "Obsidian Flames", setCode: "SV04", cardNumber: "197/197",
            year: 2023, variant: "Full Art", rarity: .fullArt,
            language: "en", isFirstEdition: false, isHolo: true, isReverseHolo: false,
            imageURL: nil, identificationConfidence: 0.93
        ),
        CardIdentity(
            id: "sv2-191", category: .pokemon, name: "Gardevoir ex",
            setName: "Paldea Evolved", setCode: "SV02", cardNumber: "191/193",
            year: 2023, variant: "Full Art", rarity: .fullArt,
            language: "en", isFirstEdition: false, isHolo: true, isReverseHolo: false,
            imageURL: nil, identificationConfidence: 0.92
        ),
        CardIdentity(
            id: "sv5-208", category: .pokemon, name: "Eevee",
            setName: "Temporal Forces", setCode: "SV05", cardNumber: "208/162",
            year: 2024, variant: "Illustration Rare", rarity: .illustrationRare,
            language: "en", isFirstEdition: false, isHolo: true, isReverseHolo: false,
            imageURL: nil, identificationConfidence: 0.91
        ),
        CardIdentity(
            id: "sv1-198", category: .pokemon, name: "Koraidon ex",
            setName: "Scarlet & Violet", setCode: "SV01", cardNumber: "198/198",
            year: 2023, variant: "Ultra Rare", rarity: .ultraRare,
            language: "en", isFirstEdition: false, isHolo: true, isReverseHolo: false,
            imageURL: nil, identificationConfidence: 0.95
        ),
        CardIdentity(
            id: "sv6pt5-175", category: .pokemon, name: "Mewtwo ex",
            setName: "Shrouded Fable", setCode: "SV6.5", cardNumber: "175/064",
            year: 2024, variant: "Special Art Rare", rarity: .specialArt,
            language: "en", isFirstEdition: false, isHolo: true, isReverseHolo: false,
            imageURL: nil, identificationConfidence: 0.96
        ),
        CardIdentity(
            id: "sv4-rh-025", category: .pokemon, name: "Charmander",
            setName: "Obsidian Flames", setCode: "SV04", cardNumber: "025/197",
            year: 2023, variant: nil, rarity: .reverseHolo,
            language: "en", isFirstEdition: false, isHolo: false, isReverseHolo: true,
            imageURL: nil, identificationConfidence: 0.98
        ),
        CardIdentity(
            id: "sv3pt5-001", category: .pokemon, name: "Bulbasaur",
            setName: "151", setCode: "SV3.5", cardNumber: "001/165",
            year: 2023, variant: nil, rarity: .common,
            language: "en", isFirstEdition: false, isHolo: false, isReverseHolo: false,
            imageURL: nil, identificationConfidence: 0.99
        ),
        CardIdentity(
            id: "sv7-243", category: .pokemon, name: "Rayquaza ex",
            setName: "Stellar Crown", setCode: "SV07", cardNumber: "243/175",
            year: 2024, variant: "Hyper Rare", rarity: .hyperRare,
            language: "en", isFirstEdition: false, isHolo: true, isReverseHolo: false,
            imageURL: nil, identificationConfidence: 0.94
        ),
    ]

    static func marketSnapshot(for cardId: String) -> MarketSnapshot {
        let values = marketValues[cardId] ?? (raw: 25.0, psa8: 40.0, psa9: 75.0, psa10: 200.0)
        let now = Date()
        return MarketSnapshot(
            rawEstimatedValue: values.raw,
            psa8EstimatedValue: values.psa8,
            psa9EstimatedValue: values.psa9,
            psa10EstimatedValue: values.psa10,
            thirtyDayChangePercentage: changePercentages[cardId]?.thirty ?? 2.5,
            ninetyDayChangePercentage: changePercentages[cardId]?.ninety ?? 8.0,
            oneYearChangePercentage: changePercentages[cardId]?.year ?? -5.0,
            salesVolume30Days: salesVolumes[cardId] ?? 45,
            liquidityScore: liquidityScores[cardId] ?? 0.7,
            recentSales: comparableSales(for: cardId),
            updatedAt: now
        )
    }

    private static let marketValues: [String: (raw: Double, psa8: Double, psa9: Double, psa10: Double)] = [
        "sv4-227": (raw: 185.0, psa8: 260.0, psa9: 350.0, psa10: 850.0),
        "sv3pt5-207": (raw: 145.0, psa8: 210.0, psa9: 280.0, psa10: 620.0),
        "sv1-254": (raw: 55.0, psa8: 80.0, psa9: 120.0, psa10: 310.0),
        "sv6-230": (raw: 95.0, psa8: 140.0, psa9: 200.0, psa10: 475.0),
        "sv3-197": (raw: 35.0, psa8: 55.0, psa9: 85.0, psa10: 220.0),
        "sv2-191": (raw: 22.0, psa8: 38.0, psa9: 60.0, psa10: 165.0),
        "sv5-208": (raw: 18.0, psa8: 30.0, psa9: 48.0, psa10: 110.0),
        "sv1-198": (raw: 12.0, psa8: 22.0, psa9: 38.0, psa10: 95.0),
        "sv6pt5-175": (raw: 72.0, psa8: 105.0, psa9: 160.0, psa10: 380.0),
        "sv4-rh-025": (raw: 2.50, psa8: 6.0, psa9: 12.0, psa10: 22.0),
        "sv3pt5-001": (raw: 1.50, psa8: 4.0, psa9: 8.0, psa10: 15.0),
        "sv7-243": (raw: 110.0, psa8: 160.0, psa9: 230.0, psa10: 520.0),
    ]

    private static let changePercentages: [String: (thirty: Double, ninety: Double, year: Double)] = [
        "sv4-227": (thirty: 5.2, ninety: 12.0, year: 35.0),
        "sv3pt5-207": (thirty: -2.1, ninety: 3.5, year: 18.0),
        "sv1-254": (thirty: -8.0, ninety: -12.0, year: -20.0),
        "sv6-230": (thirty: 15.0, ninety: 22.0, year: 45.0),
        "sv3-197": (thirty: 1.0, ninety: -3.0, year: -10.0),
        "sv2-191": (thirty: -1.5, ninety: -5.0, year: -15.0),
        "sv5-208": (thirty: 3.0, ninety: 8.0, year: 12.0),
        "sv1-198": (thirty: -4.0, ninety: -10.0, year: -25.0),
        "sv6pt5-175": (thirty: 8.0, ninety: 18.0, year: 30.0),
        "sv4-rh-025": (thirty: 0.5, ninety: 2.0, year: 5.0),
        "sv3pt5-001": (thirty: 0.0, ninety: 1.0, year: 3.0),
        "sv7-243": (thirty: 12.0, ninety: 25.0, year: 40.0),
    ]

    private static let salesVolumes: [String: Int] = [
        "sv4-227": 285, "sv3pt5-207": 195, "sv1-254": 160, "sv6-230": 175,
        "sv3-197": 120, "sv2-191": 105, "sv5-208": 65, "sv1-198": 90,
        "sv6pt5-175": 145, "sv4-rh-025": 45, "sv3pt5-001": 30, "sv7-243": 110,
    ]

    private static let liquidityScores: [String: Double] = [
        "sv4-227": 0.85, "sv3pt5-207": 0.78, "sv1-254": 0.90, "sv6-230": 0.65,
        "sv3-197": 0.92, "sv2-191": 0.88, "sv5-208": 0.75, "sv1-198": 0.95,
        "sv6pt5-175": 0.55, "sv4-rh-025": 0.98, "sv3pt5-001": 0.99, "sv7-243": 0.45,
    ]

    static func comparableSales(for cardId: String) -> [ComparableSale] {
        let base = marketValues[cardId] ?? (raw: 25.0, psa8: 40.0, psa9: 75.0, psa10: 200.0)
        let now = Date()
        let card = cards.first { $0.id == cardId }
        let cardName = card?.name ?? "Pokémon Card"

        return [
            ComparableSale(id: "\(cardId)-s1", marketplace: "eBay", title: "\(cardName) PSA 10 Gem Mint", salePrice: base.psa10 * 1.02, shippingPrice: 5.99, saleDate: now.addingTimeInterval(-86400 * 2), condition: "Graded", gradingCompany: "PSA", grade: 10, matchQuality: .exact, imageURL: nil),
            ComparableSale(id: "\(cardId)-s2", marketplace: "eBay", title: "\(cardName) PSA 9 Mint", salePrice: base.psa9 * 0.98, shippingPrice: 4.99, saleDate: now.addingTimeInterval(-86400 * 3), condition: "Graded", gradingCompany: "PSA", grade: 9, matchQuality: .exact, imageURL: nil),
            ComparableSale(id: "\(cardId)-s3", marketplace: "TCGPlayer", title: "\(cardName) Near Mint", salePrice: base.raw * 1.05, shippingPrice: 0.99, saleDate: now.addingTimeInterval(-86400 * 1), condition: "Near Mint", gradingCompany: nil, grade: nil, matchQuality: .exact, imageURL: nil),
            ComparableSale(id: "\(cardId)-s4", marketplace: "eBay", title: "\(cardName) PSA 10", salePrice: base.psa10 * 0.95, shippingPrice: 6.99, saleDate: now.addingTimeInterval(-86400 * 5), condition: "Graded", gradingCompany: "PSA", grade: 10, matchQuality: .exact, imageURL: nil),
            ComparableSale(id: "\(cardId)-s5", marketplace: "TCGPlayer", title: "\(cardName) Lightly Played", salePrice: base.raw * 0.85, shippingPrice: 0.99, saleDate: now.addingTimeInterval(-86400 * 4), condition: "Lightly Played", gradingCompany: nil, grade: nil, matchQuality: .strong, imageURL: nil),
            ComparableSale(id: "\(cardId)-s6", marketplace: "eBay", title: "\(cardName) PSA 8 NM-MT", salePrice: base.psa8 * 1.03, shippingPrice: 4.50, saleDate: now.addingTimeInterval(-86400 * 6), condition: "Graded", gradingCompany: "PSA", grade: 8, matchQuality: .exact, imageURL: nil),
            ComparableSale(id: "\(cardId)-s7", marketplace: "eBay", title: "\(cardName) CGC 9.5", salePrice: base.psa9 * 0.90, shippingPrice: 5.50, saleDate: now.addingTimeInterval(-86400 * 7), condition: "Graded", gradingCompany: "CGC", grade: 9.5, matchQuality: .strong, imageURL: nil),
            ComparableSale(id: "\(cardId)-s8", marketplace: "Mercari", title: "\(cardName) Raw NM", salePrice: base.raw * 0.92, shippingPrice: 3.99, saleDate: now.addingTimeInterval(-86400 * 8), condition: "Near Mint", gradingCompany: nil, grade: nil, matchQuality: .strong, imageURL: nil),
            ComparableSale(id: "\(cardId)-s9", marketplace: "eBay", title: "\(cardName) BGS 9", salePrice: base.psa9 * 0.85, shippingPrice: 7.99, saleDate: now.addingTimeInterval(-86400 * 10), condition: "Graded", gradingCompany: "BGS", grade: 9, matchQuality: .partial, imageURL: nil),
            ComparableSale(id: "\(cardId)-s10", marketplace: "eBay", title: "\(cardName) Japanese Ver PSA 10", salePrice: base.psa10 * 0.70, shippingPrice: 8.99, saleDate: now.addingTimeInterval(-86400 * 12), condition: "Graded", gradingCompany: "PSA", grade: 10, matchQuality: .weak, imageURL: nil),
        ]
    }

    static func priceHistory(for cardId: String, range: TimeRange) -> [PriceHistoryPoint] {
        let base = marketValues[cardId]?.raw ?? 25.0
        let days: Int
        switch range {
        case .thirtyDays: days = 30
        case .ninetyDays: days = 90
        case .oneYear: days = 365
        case .allTime: days = 730
        }
        let now = Date()
        return (0..<days).compactMap { i -> PriceHistoryPoint? in
            guard i % max(days / 60, 1) == 0 else { return nil }
            let date = now.addingTimeInterval(-Double(days - i) * 86400)
            let noise = sin(Double(i) * 0.3) * (base * 0.08)
            let trend = Double(i) / Double(days) * (base * 0.1)
            return PriceHistoryPoint(date: date, price: max(base * 0.7 + trend + noise, base * 0.5))
        }
    }

    static func gradingReport(for cardId: String, qualityMultiplier: Double = 1.0) -> GradingReport {
        let config = gradingConfigs[cardId] ?? defaultGradingConfig
        let adjustedGrade = min(10, config.grade * qualityMultiplier)

        let q = qualityMultiplier
        let q2 = q * q
        let p10 = config.psa10 * q2
        let p9 = config.psa9 * q
        let p8 = config.psa8 * max(q, 0.5)
        let pSum = p10 + p9 + p8
        let p7 = max(0, 1.0 - pSum)

        return GradingReport(
            estimatedGrade: adjustedGrade,
            confidence: config.confidence * max(q, 0.5),
            psa10Probability: p10,
            psa9Probability: p9,
            psa8Probability: p8,
            psa7OrLowerProbability: p7,
            frontCenteringHorizontal: config.frontCH,
            frontCenteringVertical: config.frontCV,
            backCenteringHorizontal: config.backCH,
            backCenteringVertical: config.backCV,
            cornerScore: config.corners * q,
            edgeScore: config.edges * q,
            surfaceScore: config.surface * q,
            printQualityScore: config.print * q,
            detectedDefects: config.defects,
            explanation: config.explanation,
            createdAt: Date()
        )
    }

    struct GradingConfig {
        let grade: Double
        let confidence: Double
        let psa10: Double
        let psa9: Double
        let psa8: Double
        let frontCH: Double
        let frontCV: Double
        let backCH: Double
        let backCV: Double
        let corners: Double
        let edges: Double
        let surface: Double
        let print: Double
        let defects: [DetectedDefect]
        let explanation: String
    }

    private static let defaultGradingConfig = GradingConfig(
        grade: 8.5, confidence: 0.78,
        psa10: 0.05, psa9: 0.30, psa8: 0.45,
        frontCH: 0.54, frontCV: 0.51, backCH: 0.56, backCV: 0.52,
        corners: 8.0, edges: 8.5, surface: 9.0, print: 9.0,
        defects: [
            DetectedDefect(id: "def-1", type: .cornerWhitening, severity: .minor, confidence: 0.85, locationDescription: "Bottom-right corner", normalizedBoundingBox: CIQRect(x: 0.88, y: 0.92, width: 0.1, height: 0.08), explanation: "Slight whitening visible on the bottom-right corner. This is a common wear indicator that typically limits a card to PSA 9 or below."),
        ],
        explanation: "This card presents in strong overall condition with minor corner whitening limiting the grade potential. Centering is within acceptable PSA 9 tolerances."
    )

    private static let gradingConfigs: [String: GradingConfig] = [
        "sv4-227": GradingConfig(
            grade: 9.0, confidence: 0.82,
            psa10: 0.08, psa9: 0.52, psa8: 0.30,
            frontCH: 0.52, frontCV: 0.51, backCH: 0.54, backCV: 0.52,
            corners: 9.0, edges: 9.0, surface: 9.5, print: 9.5,
            defects: [
                DetectedDefect(id: "sv4-227-d1", type: .cornerWhitening, severity: .minor, confidence: 0.72, locationDescription: "Top-left corner", normalizedBoundingBox: CIQRect(x: 0.02, y: 0.02, width: 0.08, height: 0.06), explanation: "Very faint whitening at the top-left corner under magnification. May or may not be caught during grading."),
                DetectedDefect(id: "sv4-227-d2", type: .offCentering, severity: .minor, confidence: 0.65, locationDescription: "Front horizontal", normalizedBoundingBox: nil, explanation: "Slight off-centering on the front, measuring approximately 52/48. Within PSA 10 tolerances of 55/45."),
            ],
            explanation: "Excellent condition Charizard ex SAR. Centering is well within PSA 10 tolerances. Minor corner whitening at top-left is borderline and may not prevent a 10. Strong candidate for grading."
        ),
        "sv3pt5-207": GradingConfig(
            grade: 9.5, confidence: 0.85,
            psa10: 0.55, psa9: 0.32, psa8: 0.10,
            frontCH: 0.51, frontCV: 0.50, backCH: 0.52, backCV: 0.51,
            corners: 9.5, edges: 9.5, surface: 10.0, print: 9.5,
            defects: [
                DetectedDefect(id: "sv3pt5-207-d1", type: .printLine, severity: .minor, confidence: 0.55, locationDescription: "Back left edge", normalizedBoundingBox: CIQRect(x: 0.0, y: 0.3, width: 0.05, height: 0.2), explanation: "Possible faint print line on the back. Low confidence — may be a lighting artifact. If present, unlikely to affect grade significantly."),
            ],
            explanation: "Near-perfect Umbreon ex SIR. Outstanding centering and clean surfaces. One potential print line on the back but low confidence. Very strong PSA 10 candidate."
        ),
        "sv1-254": GradingConfig(
            grade: 7.5, confidence: 0.80,
            psa10: 0.01, psa9: 0.06, psa8: 0.38,
            frontCH: 0.58, frontCV: 0.55, backCH: 0.60, backCV: 0.54,
            corners: 7.5, edges: 8.0, surface: 8.5, print: 9.0,
            defects: [
                DetectedDefect(id: "sv1-254-d1", type: .offCentering, severity: .moderate, confidence: 0.92, locationDescription: "Front horizontal and vertical", normalizedBoundingBox: nil, explanation: "Significant off-centering at 58/42 horizontal. This exceeds PSA 9 tolerances of 55/45 and will likely cap the grade at PSA 8."),
                DetectedDefect(id: "sv1-254-d2", type: .cornerWhitening, severity: .moderate, confidence: 0.88, locationDescription: "Bottom-left and bottom-right corners", normalizedBoundingBox: CIQRect(x: 0.02, y: 0.90, width: 0.96, height: 0.10), explanation: "Visible whitening on both bottom corners, consistent with handling wear."),
                DetectedDefect(id: "sv1-254-d3", type: .edgeChipping, severity: .minor, confidence: 0.70, locationDescription: "Top edge", normalizedBoundingBox: CIQRect(x: 0.3, y: 0.0, width: 0.4, height: 0.03), explanation: "Minor edge wear along the top. Consistent with pack-fresh handling."),
            ],
            explanation: "This Miraidon ex has notable centering issues that will cap the grade. Combined with corner whitening, a PSA 8 is the most likely outcome. Grading is unlikely to be profitable at current market values."
        ),
        "sv6-230": GradingConfig(
            grade: 9.5, confidence: 0.88,
            psa10: 0.60, psa9: 0.28, psa8: 0.09,
            frontCH: 0.50, frontCV: 0.51, backCH: 0.51, backCV: 0.50,
            corners: 9.5, edges: 9.5, surface: 9.5, print: 10.0,
            defects: [],
            explanation: "Exceptional Pikachu ex SIR with near-perfect centering and no detected defects. Factory-fresh surfaces and sharp corners. This is a premier PSA 10 candidate."
        ),
        "sv4-rh-025": GradingConfig(
            grade: 6.5, confidence: 0.75,
            psa10: 0.0, psa9: 0.05, psa8: 0.15,
            frontCH: 0.62, frontCV: 0.58, backCH: 0.55, backCV: 0.53,
            corners: 6.0, edges: 7.0, surface: 7.5, print: 8.0,
            defects: [
                DetectedDefect(id: "rh025-d1", type: .offCentering, severity: .severe, confidence: 0.95, locationDescription: "Front horizontal 62/38", normalizedBoundingBox: nil, explanation: "Severe off-centering at 62/38. This is within PSA 8 tolerance (65/35) but exceeds PSA 9 (60/40). Combined with other defects, centering further limits the grade."),
                DetectedDefect(id: "rh025-d2", type: .cornerWhitening, severity: .moderate, confidence: 0.90, locationDescription: "All four corners", normalizedBoundingBox: CIQRect(x: 0, y: 0, width: 1, height: 1), explanation: "Whitening visible on all four corners. Consistent with played condition."),
                DetectedDefect(id: "rh025-d3", type: .surfaceWear, severity: .moderate, confidence: 0.82, locationDescription: "Center of card face", normalizedBoundingBox: CIQRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6), explanation: "Light surface scratching visible across the holo pattern. Common in reverse holo cards that have been handled."),
            ],
            explanation: "This reverse holo Charmander shows significant play wear. Off-centering, corner whitening on all corners, and surface scratches make professional grading inadvisable at current market values."
        ),
    ]

    static let sampleCollectionItems: [(card: CardIdentity, purchase: Double?, grade: Double?, gradeCompany: String?)] = [
        (cards[0], 120.0, nil, nil),
        (cards[1], 95.0, nil, nil),
        (cards[2], 85.0, 8.0, "PSA"),
        (cards[3], 45.0, nil, nil),
        (cards[4], 25.0, nil, nil),
        (cards[5], 18.0, 9.0, "PSA"),
        (cards[6], 12.0, nil, nil),
        (cards[7], 8.0, 10.0, "PSA"),
    ]

    static func goodImageQualityReport() -> ImageQualityReport {
        ImageQualityReport(
            overallScore: 0.92,
            isBlurry: false,
            hasGlare: false,
            isCropped: false,
            isSleeved: false,
            isSlabbed: false,
            lightingScore: 0.88,
            frontCardCoverage: 0.85,
            backCardCoverage: 0.83,
            retakeInstructions: []
        )
    }

    static func poorImageQualityReport() -> ImageQualityReport {
        ImageQualityReport(
            overallScore: 0.35,
            isBlurry: true,
            hasGlare: true,
            isCropped: false,
            isSleeved: true,
            isSlabbed: false,
            lightingScore: 0.40,
            frontCardCoverage: 0.70,
            backCardCoverage: 0.65,
            retakeInstructions: [
                "Hold the phone steady to reduce blur.",
                "Tilt the light to reduce glare on the card surface.",
                "Remove the card from its sleeve for accurate grading analysis.",
                "Move closer so the card fills more of the frame.",
            ]
        )
    }
}
