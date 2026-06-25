import Testing
import Foundation
@testable import CardIQ

@Suite("Grade Probability Tests")
struct GradeProbabilityTests {

    @Test("Probability totals approximately 100%")
    func probabilityTotals() async throws {
        for card in MockSeedData.cards {
            let report = MockSeedData.gradingReport(for: card.id)
            let total = report.probabilityTotal
            #expect(total > 0.95 && total < 1.05, "Probability total for \(card.id) was \(total)")
        }
    }

    @Test("All grades are in valid range")
    func gradesInRange() async throws {
        for card in MockSeedData.cards {
            let report = MockSeedData.gradingReport(for: card.id)
            #expect(report.estimatedGrade >= 1.0 && report.estimatedGrade <= 10.0)
        }
    }

    @Test("Deterministic mock results")
    func deterministicResults() async throws {
        let report1 = MockSeedData.gradingReport(for: "sv4-227")
        let report2 = MockSeedData.gradingReport(for: "sv4-227")
        #expect(report1.estimatedGrade == report2.estimatedGrade)
        #expect(report1.psa10Probability == report2.psa10Probability)
        #expect(report1.cornerScore == report2.cornerScore)
    }
}

@Suite("ROI Calculation Tests")
struct ROICalculationTests {
    let calculator = DefaultGradeROICalculator()

    @Test("Expected value calculation")
    func expectedValue() async throws {
        let report = MockSeedData.gradingReport(for: "sv4-227")
        let market = MockSeedData.marketSnapshot(for: "sv4-227")
        let input = ROIInput.default

        let result = calculator.calculate(gradingReport: report, marketSnapshot: market, input: input)

        let manualExpected =
            report.psa10Probability * market.psa10EstimatedValue +
            report.psa9Probability * market.psa9EstimatedValue +
            report.psa8Probability * market.psa8EstimatedValue +
            report.psa7OrLowerProbability * market.rawEstimatedValue

        #expect(abs(result.expectedGradedValue - manualExpected) < 0.01)
    }

    @Test("Selling fee calculation")
    func sellingFee() async throws {
        let report = MockSeedData.gradingReport(for: "sv4-227")
        let market = MockSeedData.marketSnapshot(for: "sv4-227")
        var input = ROIInput.default
        input.sellingFeePercentage = 13

        let result = calculator.calculate(gradingReport: report, marketSnapshot: market, input: input)
        let expectedFee = result.expectedGradedValue * 0.13
        let expectedNet = result.expectedGradedValue - expectedFee

        #expect(abs(result.expectedNetProceeds - expectedNet) < 0.01)
    }

    @Test("Maximum buy price calculation")
    func maxBuyPrice() async throws {
        let report = MockSeedData.gradingReport(for: "sv4-227")
        let market = MockSeedData.marketSnapshot(for: "sv4-227")
        let input = ROIInput.default

        let result = calculator.calculate(gradingReport: report, marketSnapshot: market, input: input)

        #expect(result.maximumRecommendedBuyPrice >= 0)
        #expect(result.maximumRecommendedBuyPrice <= result.expectedNetProceeds)
    }

    @Test("Outcomes table has four entries")
    func outcomesCount() async throws {
        let report = MockSeedData.gradingReport(for: "sv4-227")
        let market = MockSeedData.marketSnapshot(for: "sv4-227")
        let outcomes = calculator.outcomes(gradingReport: report, marketSnapshot: market, input: .default)

        #expect(outcomes.count == 4)
        #expect(outcomes[0].label == "Sell Raw")
        #expect(outcomes[1].label == "PSA 8")
        #expect(outcomes[2].label == "PSA 9")
        #expect(outcomes[3].label == "PSA 10")
    }

    @Test("Negative ROI for low-value cards")
    func negativeROI() async throws {
        let report = MockSeedData.gradingReport(for: "sv4-rh-025")
        let market = MockSeedData.marketSnapshot(for: "sv4-rh-025")
        var input = ROIInput.default
        input.purchasePrice = 5.0

        let result = calculator.calculate(gradingReport: report, marketSnapshot: market, input: input)

        #expect(result.recommendation == .sellRaw || result.recommendation == .hold)
    }
}

@Suite("Image Quality Tests")
struct ImageQualityTests {

    @Test("Good quality passes minimum")
    func goodQualityPasses() async throws {
        let report = MockSeedData.goodImageQualityReport()
        #expect(report.passesMinimumQuality)
        #expect(report.retakeInstructions.isEmpty)
    }

    @Test("Poor quality fails minimum")
    func poorQualityFails() async throws {
        let report = MockSeedData.poorImageQualityReport()
        #expect(!report.passesMinimumQuality)
        #expect(!report.retakeInstructions.isEmpty)
    }

    @Test("Quality gating prevents blurry images")
    func blurryGating() async throws {
        let report = MockSeedData.poorImageQualityReport()
        #expect(report.isBlurry)
        #expect(!report.passesMinimumQuality)
    }
}

@Suite("Collection Calculation Tests")
struct CollectionTests {

    @Test("Collection gain/loss calculation")
    func gainLossCalculation() async throws {
        let market = MockSeedData.marketSnapshot(for: "sv4-227")
        let purchasePrice = 120.0
        let currentValue = market.rawEstimatedValue
        let gainLoss = currentValue - purchasePrice
        let gainLossPct = ((currentValue - purchasePrice) / purchasePrice) * 100

        #expect(gainLoss == market.rawEstimatedValue - 120.0)
        #expect(abs(gainLossPct - ((market.rawEstimatedValue - 120.0) / 120.0) * 100) < 0.01)
    }

    @Test("Sample collection has expected count")
    func sampleCollectionCount() async throws {
        #expect(MockSeedData.sampleCollectionItems.count == 8)
    }
}

@Suite("Card Identification Tests")
struct IdentificationTests {

    @Test("Mock cards have valid confidence")
    func cardConfidence() async throws {
        for card in MockSeedData.cards {
            #expect(card.identificationConfidence > 0 && card.identificationConfidence <= 1.0)
        }
    }

    @Test("At least 12 mock cards")
    func mockCardCount() async throws {
        #expect(MockSeedData.cards.count >= 12)
    }

    @Test("Search finds cards by name")
    func searchByName() async throws {
        let service = MockCardIdentificationService()
        let results = try await service.search(query: "Charizard")
        #expect(!results.isEmpty)
        #expect(results.first?.name.contains("Charizard") == true)
    }

    @Test("Each card has at least 10 comparable sales")
    func comparableSalesCount() async throws {
        for card in MockSeedData.cards {
            let sales = MockSeedData.comparableSales(for: card.id)
            #expect(sales.count >= 10)
        }
    }
}

@Suite("Subscription Tests")
struct SubscriptionTests {

    @Test("Free tier has 3 scans")
    func freeScans() async throws {
        let service = MockSubscriptionService()
        let remaining = await service.remainingScans()
        #expect(remaining == 3)
    }

    @Test("Consuming scan decrements count")
    func consumeScan() async throws {
        let service = MockSubscriptionService()
        try await service.consumeScan()
        let remaining = await service.remainingScans()
        #expect(remaining == 2)
    }

    @Test("Scan limit throws when exhausted")
    func scanLimitExhausted() async throws {
        let service = MockSubscriptionService()
        try await service.consumeScan()
        try await service.consumeScan()
        try await service.consumeScan()
        do {
            try await service.consumeScan()
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is CIQError)
        }
    }
}

@Suite("Market Data Tests")
struct MarketDataTests {

    @Test("Market snapshot has valid values")
    func validMarketValues() async throws {
        for card in MockSeedData.cards {
            let market = MockSeedData.marketSnapshot(for: card.id)
            #expect(market.rawEstimatedValue > 0)
            #expect(market.psa8EstimatedValue >= market.rawEstimatedValue)
            #expect(market.psa9EstimatedValue >= market.psa8EstimatedValue)
            #expect(market.psa10EstimatedValue >= market.psa9EstimatedValue)
        }
    }

    @Test("Price history generates data points")
    func priceHistoryGenerated() async throws {
        let history = MockSeedData.priceHistory(for: "sv4-227", range: .thirtyDays)
        #expect(!history.isEmpty)
        #expect(history.count > 10)
    }

    @Test("PSA 8 premium is at least 30% over raw for high-value cards")
    func psa8PremiumRealistic() async throws {
        let highValueCards = ["sv4-227", "sv3pt5-207", "sv6-230", "sv6pt5-175", "sv7-243"]
        for cardId in highValueCards {
            let market = MockSeedData.marketSnapshot(for: cardId)
            let premium = market.psa8EstimatedValue / market.rawEstimatedValue
            #expect(premium >= 1.3, "PSA 8 premium for \(cardId) is only \(premium)x — should be >= 1.3x")
        }
    }

    @Test("Bulk card PSA 10 values are reasonable")
    func bulkPsa10Reasonable() async throws {
        let charmander = MockSeedData.marketSnapshot(for: "sv4-rh-025")
        #expect(charmander.psa10EstimatedValue <= 30, "Charmander RH PSA 10 at \(charmander.psa10EstimatedValue) is too high for a bulk card")

        let bulbasaur = MockSeedData.marketSnapshot(for: "sv3pt5-001")
        #expect(bulbasaur.psa10EstimatedValue <= 20, "Bulbasaur PSA 10 at \(bulbasaur.psa10EstimatedValue) is too high for a common")
    }

    @Test("High-value cards have higher sales volume than bulk")
    func salesVolumeOrdering() async throws {
        let charizard = MockSeedData.marketSnapshot(for: "sv4-227")
        let bulbasaur = MockSeedData.marketSnapshot(for: "sv3pt5-001")
        #expect(charizard.salesVolume30Days > bulbasaur.salesVolume30Days, "Charizard should have more sales than Bulbasaur common")
    }
}

@Suite("Grading Logic Consistency")
struct GradingLogicTests {

    @Test("Grade 9.0 card should have less than 15% PSA 10 probability")
    func grade9ProbabilityDistribution() async throws {
        let report = MockSeedData.gradingReport(for: "sv4-227")
        #expect(report.estimatedGrade >= 8.5 && report.estimatedGrade <= 9.5)
        #expect(report.psa10Probability < 0.15, "A 9.0 card should have < 15% PSA 10 (got \(report.psa10Probability))")
        #expect(report.psa9Probability > report.psa10Probability, "PSA 9 should be higher than PSA 10 for a 9.0 card")
    }

    @Test("Grade 9.5 card should have highest PSA 10 probability")
    func grade95ProbabilityDistribution() async throws {
        let pikachu = MockSeedData.gradingReport(for: "sv6-230")
        #expect(pikachu.estimatedGrade >= 9.0)
        #expect(pikachu.psa10Probability >= 0.50, "Near-perfect 9.5 card should have >= 50% PSA 10 (got \(pikachu.psa10Probability))")
        #expect(pikachu.psa10Probability > pikachu.psa9Probability, "PSA 10 should be most likely for a 9.5 card with perfect centering")
    }

    @Test("Grade 7.5 card should have near-zero PSA 10 probability")
    func grade75ProbabilityDistribution() async throws {
        let miraidon = MockSeedData.gradingReport(for: "sv1-254")
        #expect(miraidon.psa10Probability <= 0.02, "A 7.5 card should have <= 2% PSA 10 (got \(miraidon.psa10Probability))")
        #expect(miraidon.psa7OrLowerProbability > 0.40, "A 7.5 card should have > 40% PSA 7- (got \(miraidon.psa7OrLowerProbability))")
    }

    @Test("Category scores should correlate with estimated grade")
    func scoresCorrelateWithGrade() async throws {
        let high = MockSeedData.gradingReport(for: "sv6-230")
        let low = MockSeedData.gradingReport(for: "sv4-rh-025")

        #expect(high.cornerScore > low.cornerScore)
        #expect(high.edgeScore > low.edgeScore)
        #expect(high.surfaceScore > low.surfaceScore)
        #expect(high.estimatedGrade > low.estimatedGrade)
    }

    @Test("Cards with defects should have lower scores in defect area")
    func defectsMatchScores() async throws {
        let miraidon = MockSeedData.gradingReport(for: "sv1-254")
        let hasCornerDefect = miraidon.detectedDefects.contains { $0.type == .cornerWhitening }
        #expect(hasCornerDefect, "Miraidon should have corner whitening defect")
        #expect(miraidon.cornerScore <= 8.0, "Card with corner whitening should have corner score <= 8.0")

        let pikachu = MockSeedData.gradingReport(for: "sv6-230")
        #expect(pikachu.detectedDefects.isEmpty, "Pikachu 9.5 should have no defects")
        #expect(pikachu.cornerScore >= 9.0, "Defect-free card should have corner score >= 9.0")
    }

    @Test("Centering values produce correct PSA tolerance judgments")
    func centeringTolerances() async throws {
        let pikachu = MockSeedData.gradingReport(for: "sv6-230")
        let psa10Tolerance = 0.05
        #expect(abs(pikachu.frontCenteringHorizontal - 0.5) <= psa10Tolerance, "Pikachu centering should be within PSA 10 tolerance")

        let miraidon = MockSeedData.gradingReport(for: "sv1-254")
        #expect(abs(miraidon.frontCenteringHorizontal - 0.5) > psa10Tolerance, "Miraidon centering should exceed PSA 10 tolerance")
    }
}

@Suite("Quality Multiplier Logic")
struct QualityMultiplierTests {

    @Test("Quality 0.5 should dramatically reduce PSA 10 and PSA 9 probabilities")
    func poorQualityReducesProbabilities() async throws {
        let full = MockSeedData.gradingReport(for: "sv6-230", qualityMultiplier: 1.0)
        let poor = MockSeedData.gradingReport(for: "sv6-230", qualityMultiplier: 0.5)

        #expect(poor.psa10Probability < full.psa10Probability * 0.5, "PSA 10 should drop by more than half with 0.5 quality")
        #expect(poor.psa9Probability < full.psa9Probability, "PSA 9 should also decrease with poor quality")
        #expect(poor.psa7OrLowerProbability > full.psa7OrLowerProbability, "PSA 7- should increase with poor quality")
        #expect(poor.estimatedGrade < full.estimatedGrade, "Estimated grade should drop with poor quality")
    }

    @Test("Quality 0.5 should shift majority of probability to PSA 7-or-lower")
    func poorQualityShiftsMass() async throws {
        let poor = MockSeedData.gradingReport(for: "sv6-230", qualityMultiplier: 0.5)
        #expect(poor.psa7OrLowerProbability > 0.50, "With 0.5 quality, PSA 7- should be > 50% (got \(poor.psa7OrLowerProbability))")
    }

    @Test("Quality 1.0 produces identical results to default")
    func fullQualityIdentical() async throws {
        let full = MockSeedData.gradingReport(for: "sv4-227", qualityMultiplier: 1.0)
        let def = MockSeedData.gradingReport(for: "sv4-227")
        #expect(full.estimatedGrade == def.estimatedGrade)
        #expect(full.psa10Probability == def.psa10Probability)
        #expect(full.psa9Probability == def.psa9Probability)
    }

    @Test("Quality multiplier affects category scores")
    func qualityAffectsScores() async throws {
        let full = MockSeedData.gradingReport(for: "sv4-227", qualityMultiplier: 1.0)
        let poor = MockSeedData.gradingReport(for: "sv4-227", qualityMultiplier: 0.5)
        #expect(poor.cornerScore < full.cornerScore)
        #expect(poor.edgeScore < full.edgeScore)
        #expect(poor.surfaceScore < full.surfaceScore)
    }
}

@Suite("ROI Logic End-to-End")
struct ROIEndToEndTests {
    let calculator = DefaultGradeROICalculator()

    @Test("Charizard with $120 purchase price should recommend grading")
    func charizardGradingRecommendation() async throws {
        let report = MockSeedData.gradingReport(for: "sv4-227")
        let market = MockSeedData.marketSnapshot(for: "sv4-227")
        var input = ROIInput.default
        input.purchasePrice = 120.0

        let result = calculator.calculate(gradingReport: report, marketSnapshot: market, input: input)

        #expect(result.expectedGradedValue > market.rawEstimatedValue, "Expected graded value should exceed raw for a 9.0 card")
        #expect(result.recommendation == .grade || result.recommendation == .considerGrading,
                "Charizard at $120 purchase should recommend grading (got \(result.recommendation))")
    }

    @Test("Charmander bulk card should recommend sell raw")
    func charmanderSellRaw() async throws {
        let report = MockSeedData.gradingReport(for: "sv4-rh-025")
        let market = MockSeedData.marketSnapshot(for: "sv4-rh-025")
        var input = ROIInput.default
        input.purchasePrice = 2.0

        let result = calculator.calculate(gradingReport: report, marketSnapshot: market, input: input)

        #expect(result.recommendation == .sellRaw || result.recommendation == .hold,
                "Bulk card with grade 6.5 should not recommend grading (got \(result.recommendation))")
        #expect(result.expectedProfit < 0, "Grading a $2 bulk card should show negative expected profit")
    }

    @Test("Selling fee is applied to sale price not profit")
    func sellingFeeOnSalePrice() async throws {
        let report = MockSeedData.gradingReport(for: "sv4-227")
        let market = MockSeedData.marketSnapshot(for: "sv4-227")
        var input = ROIInput.default
        input.sellingFeePercentage = 13
        input.purchasePrice = 100

        let result = calculator.calculate(gradingReport: report, marketSnapshot: market, input: input)
        let expectedFee = result.expectedGradedValue * 0.13
        let expectedNet = result.expectedGradedValue - expectedFee

        #expect(abs(result.expectedNetProceeds - expectedNet) < 0.01, "Net proceeds should be graded value minus 13% fee")
        #expect(result.expectedNetProceeds < result.expectedGradedValue, "Net must be less than gross after fees")
    }

    @Test("Max buy price guarantees required margin")
    func maxBuyPriceMargin() async throws {
        let report = MockSeedData.gradingReport(for: "sv4-227")
        let market = MockSeedData.marketSnapshot(for: "sv4-227")
        var input = ROIInput.default
        input.requiredMarginPercentage = 20

        let result = calculator.calculate(gradingReport: report, marketSnapshot: market, input: input)

        let totalCostAtMaxBuy = result.maximumRecommendedBuyPrice + input.gradingFee + input.shippingCost + input.insuranceCost
        if totalCostAtMaxBuy > 0 {
            let profitAtMaxBuy = result.expectedNetProceeds - totalCostAtMaxBuy
            let roiAtMaxBuy = profitAtMaxBuy / totalCostAtMaxBuy * 100
            #expect(roiAtMaxBuy >= 18, "ROI at max buy price should be near 20% (got \(roiAtMaxBuy)%)")
        }
    }

    @Test("Outcome table is financially consistent")
    func outcomesConsistent() async throws {
        let report = MockSeedData.gradingReport(for: "sv4-227")
        let market = MockSeedData.marketSnapshot(for: "sv4-227")
        var input = ROIInput.default
        input.purchasePrice = 150

        let outcomes = calculator.outcomes(gradingReport: report, marketSnapshot: market, input: input)

        for outcome in outcomes {
            let expectedNet = outcome.estimatedSalePrice * (1 - input.sellingFeePercentage / 100)
            #expect(abs(outcome.estimatedNetProceeds - expectedNet) < 0.01, "\(outcome.label) net proceeds incorrect")
            #expect(abs(outcome.profit - (outcome.estimatedNetProceeds - outcome.totalCosts)) < 0.01, "\(outcome.label) profit calculation incorrect")
            if outcome.totalCosts > 0 {
                let expectedROI = (outcome.profit / outcome.totalCosts) * 100
                #expect(abs(outcome.roi - expectedROI) < 0.01, "\(outcome.label) ROI calculation incorrect")
            }
        }

        let raw = outcomes[0]
        #expect(raw.totalCosts < outcomes[1].totalCosts, "Raw should have lower costs than graded outcomes (no grading fee)")
    }

    @Test("Expected value equals probability-weighted sum")
    func expectedValueIsWeightedSum() async throws {
        let report = MockSeedData.gradingReport(for: "sv3pt5-207")
        let market = MockSeedData.marketSnapshot(for: "sv3pt5-207")

        let result = calculator.calculate(gradingReport: report, marketSnapshot: market, input: .default)

        let manual =
            report.psa10Probability * market.psa10EstimatedValue +
            report.psa9Probability * market.psa9EstimatedValue +
            report.psa8Probability * market.psa8EstimatedValue +
            report.psa7OrLowerProbability * market.rawEstimatedValue

        #expect(abs(result.expectedGradedValue - manual) < 0.01, "Expected value mismatch: got \(result.expectedGradedValue), manual calc \(manual)")
    }
}

@Suite("Cross-System Consistency")
struct CrossSystemTests {

    @Test("Home grading recommendations align with grading reports")
    func homeRecommendationsConsistent() async throws {
        let recommendedIds = ["sv4-227", "sv3pt5-207", "sv6-230"]
        for cardId in recommendedIds {
            let report = MockSeedData.gradingReport(for: cardId)
            let meetsThreshold = report.psa10Probability >= 0.08 || report.psa9Probability >= 0.30
            #expect(meetsThreshold, "Card \(cardId) is recommended but doesn't meet probability thresholds (PSA10: \(report.psa10Probability), PSA9: \(report.psa9Probability))")
        }

        let notRecommendedIds = ["sv4-rh-025", "sv1-254"]
        for cardId in notRecommendedIds {
            let report = MockSeedData.gradingReport(for: cardId)
            let market = MockSeedData.marketSnapshot(for: cardId)
            let calculator = DefaultGradeROICalculator()
            let result = calculator.calculate(gradingReport: report, marketSnapshot: market, input: .default)
            #expect(result.recommendation != .grade, "Card \(cardId) should NOT get a 'grade' recommendation (got \(result.recommendation))")
        }
    }

    @Test("Grading explanation matches the data")
    func explanationMatchesData() async throws {
        let pikachu = MockSeedData.gradingReport(for: "sv6-230")
        #expect(pikachu.detectedDefects.isEmpty)
        #expect(pikachu.explanation.contains("PSA 10"), "No-defect card explanation should mention PSA 10")

        let miraidon = MockSeedData.gradingReport(for: "sv1-254")
        #expect(!miraidon.detectedDefects.isEmpty)
        #expect(miraidon.explanation.lowercased().contains("centering"), "Off-center card explanation should mention centering")
    }

    @Test("Comparable sales prices are consistent with market values")
    func compSalesMatchMarket() async throws {
        for card in MockSeedData.cards {
            let market = MockSeedData.marketSnapshot(for: card.id)
            let rawSales = market.recentSales.filter { $0.grade == nil }
            for sale in rawSales {
                let ratio = sale.salePrice / market.rawEstimatedValue
                #expect(ratio > 0.7 && ratio < 1.3, "Raw sale for \(card.id) at \(sale.salePrice) is too far from market value \(market.rawEstimatedValue)")
            }
        }
    }

    @Test("PSA 10 exact-match sales align with PSA 10 market value")
    func psa10SalesMatchMarket() async throws {
        for card in MockSeedData.cards {
            let market = MockSeedData.marketSnapshot(for: card.id)
            let psa10ExactSales = market.recentSales.filter {
                $0.grade == 10 && $0.gradingCompany == "PSA" && $0.matchQuality == .exact
            }
            for sale in psa10ExactSales {
                let ratio = sale.salePrice / market.psa10EstimatedValue
                #expect(ratio > 0.8 && ratio < 1.2, "PSA 10 exact sale for \(card.id) at \(sale.salePrice) vs value \(market.psa10EstimatedValue)")
            }
        }
    }
}
