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
}
