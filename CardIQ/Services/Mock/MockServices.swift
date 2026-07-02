import Foundation
import SwiftData

final class MockAuthenticationService: AuthenticationService {
    private var user: AppUser? = AppUser.free

    func signInWithApple() async throws -> AppUser {
        let u = AppUser(
            id: "user_mock_001",
            name: "Collector",
            email: "collector@example.com",
            subscriptionTier: .free,
            freeScansRemaining: 3,
            preferredGradingCompany: "PSA",
            defaultSellingFeePercentage: 13,
            createdAt: Date()
        )
        user = u
        return u
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        var u = AppUser.free
        u.email = email
        user = u
        return u
    }

    func signUp(email: String, password: String) async throws -> AppUser {
        try await signIn(email: email, password: password)
    }

    func signOut() async throws {
        user = nil
    }

    func currentUser() async -> AppUser? {
        user
    }

    func deleteAccount() async throws {
        user = nil
    }
}

final class MockCardIdentificationService: CardIdentificationService {
    func identify(frontImage: Data, backImage: Data?) async throws -> [CardIdentity] {
        try await Task.sleep(for: .milliseconds(300))
        return Array(MockSeedData.cards.prefix(5))
    }

    func search(query: String) async throws -> [CardIdentity] {
        let lowered = query.lowercased()
        return MockSeedData.cards.filter {
            $0.name.lowercased().contains(lowered) ||
            $0.setName.lowercased().contains(lowered) ||
            $0.cardNumber.lowercased().contains(lowered)
        }
    }

    func allCards() async -> [CardIdentity] {
        MockSeedData.cards
    }
}

final class MockCardGradingService: CardGradingService {
    func analyze(cardId: String, frontImage: Data, backImage: Data, surfaceImage: Data?) async throws -> GradingReport {
        try await Task.sleep(for: .milliseconds(500))
        return MockSeedData.gradingReport(for: cardId)
    }
}

final class MockMarketDataService: MarketDataService {
    func snapshot(for cardId: String) async throws -> MarketSnapshot {
        try await Task.sleep(for: .milliseconds(200))
        return MockSeedData.marketSnapshot(for: cardId)
    }

    func priceHistory(for cardId: String, range: TimeRange) async throws -> [PriceHistoryPoint] {
        MockSeedData.priceHistory(for: cardId, range: range)
    }

    func trendingCards() async throws -> [CardIdentity] {
        [MockSeedData.cards[0], MockSeedData.cards[3], MockSeedData.cards[8], MockSeedData.cards[11]]
    }
}

final class MockImageQualityService: ImageQualityService {
    var shouldReturnPoor = false

    func assess(image: Data, captureType: CaptureType) async throws -> ImageQualityReport {
        try await Task.sleep(for: .milliseconds(200))
        return shouldReturnPoor
            ? MockSeedData.poorImageQualityReport()
            : MockSeedData.goodImageQualityReport()
    }
}

final class MockSubscriptionService: SubscriptionService {
    private var tier: SubscriptionTier = .free
    private var scansRemaining: Int = 3

    func availablePlans() async throws -> [SubscriptionPlan] {
        [
            SubscriptionPlan(
                id: "free", tier: .free, name: "Free",
                monthlyPrice: 0, yearlyPrice: 0,
                features: ["3 grading reports per month", "Basic market estimate", "Manual collection tracking"],
                scanLimit: 3, isComingSoon: false
            ),
            SubscriptionPlan(
                id: "collector_pro", tier: .collectorPro, name: "Collector Pro",
                monthlyPrice: 14.99, yearlyPrice: 119.99,
                features: ["50 grading reports per month", "Full grading breakdown", "Grade ROI calculator", "Market charts & comparable sales", "Collection valuation", "Export data"],
                scanLimit: 50, isComingSoon: false
            ),
            SubscriptionPlan(
                id: "dealer", tier: .dealer, name: "Dealer",
                monthlyPrice: 49.99, yearlyPrice: 399.99,
                features: ["Bulk card intake", "Maximum buy-price calculator", "Inventory export", "Team accounts", "500 scans per month"],
                scanLimit: 500, isComingSoon: true
            ),
        ]
    }

    func currentTier() async -> SubscriptionTier { tier }

    func purchase(planId: String) async throws -> SubscriptionTier {
        try await Task.sleep(for: .milliseconds(500))
        tier = .collectorPro
        scansRemaining = 50
        return tier
    }

    func restorePurchases() async throws -> SubscriptionTier {
        try await Task.sleep(for: .milliseconds(500))
        return tier
    }

    func remainingScans() async -> Int { scansRemaining }

    func consumeScan() async throws {
        guard scansRemaining > 0 else {
            throw CIQError.scanLimitReached
        }
        scansRemaining -= 1
    }
}

final class MockImageStorageService: ImageStorageService {
    private var store: [String: Data] = [:]

    func save(image: Data, identifier: String) async throws -> String {
        let path = "mock://images/\(identifier).jpg"
        store[path] = image
        return path
    }

    func load(path: String) async throws -> Data {
        guard let data = store[path] else {
            throw CIQError.storageFailure("Image not found at \(path)")
        }
        return data
    }

    func delete(path: String) async throws {
        store.removeValue(forKey: path)
    }
}

final class MockAnalyticsService: AnalyticsService {
    func track(_ event: AnalyticsEvent) {
        #if DEBUG
        print("[Analytics] \(event.name)")
        #endif
    }
}

struct DefaultGradeROICalculator: GradeROICalculator {
    func calculate(
        gradingReport: GradingReport,
        marketSnapshot: MarketSnapshot,
        input: ROIInput
    ) -> GradeROIResult {
        let totalGradingCost = input.gradingFee + input.shippingCost + input.insuranceCost
        let totalCostBasis = input.purchasePrice + totalGradingCost

        let expectedGradedValue =
            gradingReport.psa10Probability * marketSnapshot.psa10EstimatedValue +
            gradingReport.psa9Probability * marketSnapshot.psa9EstimatedValue +
            gradingReport.psa8Probability * marketSnapshot.psa8EstimatedValue +
            gradingReport.psa7OrLowerProbability * marketSnapshot.rawEstimatedValue

        let sellingFee = expectedGradedValue * (input.sellingFeePercentage / 100)
        let expectedNetProceeds = expectedGradedValue - sellingFee
        let expectedProfit = expectedNetProceeds - totalCostBasis

        let expectedROI: Double
        if totalCostBasis > 0 {
            expectedROI = (expectedProfit / totalCostBasis) * 100
        } else {
            expectedROI = expectedProfit > 0 ? 100 : 0
        }

        let rawNetProceeds = marketSnapshot.rawEstimatedValue * (1 - input.sellingFeePercentage / 100)
        let gradingUplift = expectedNetProceeds - rawNetProceeds - totalGradingCost

        let recommendation: GradeRecommendation
        if gradingUplift > totalGradingCost * 0.5 {
            recommendation = .grade
        } else if gradingUplift > totalGradingCost * 0.1 {
            recommendation = .considerGrading
        } else if gradingUplift > -totalGradingCost * 0.1 {
            recommendation = .hold
        } else {
            recommendation = .sellRaw
        }

        let maxBuyPrice = expectedNetProceeds - totalGradingCost - (expectedNetProceeds * input.requiredMarginPercentage / 100)

        let explanation: String
        switch recommendation {
        case .grade:
            let upliftFormatted = String(format: "$%.0f", gradingUplift)
            explanation = "Grade this card. Its expected graded value exceeds the raw value by \(upliftFormatted) after estimated costs."
        case .considerGrading:
            explanation = "Consider grading. There is a modest expected upside, but the margin is thin. A PSA 10 outcome would be significantly profitable."
        case .sellRaw:
            explanation = "Sell raw. The expected graded outcome does not provide enough upside to justify grading costs."
        case .hold:
            explanation = "Hold for now. The grading economics are borderline. Monitor market prices for a better entry point."
        case .insufficientData:
            explanation = "Insufficient market data to make a reliable recommendation."
        }

        return GradeROIResult(
            gradingCompany: input.gradingCompany,
            gradingFee: input.gradingFee,
            shippingCost: input.shippingCost,
            insuranceCost: input.insuranceCost,
            sellingFeePercentage: input.sellingFeePercentage,
            totalCostBasis: totalCostBasis,
            expectedGradedValue: expectedGradedValue,
            expectedNetProceeds: expectedNetProceeds,
            expectedProfit: expectedProfit,
            expectedROI: expectedROI,
            maximumRecommendedBuyPrice: max(0, maxBuyPrice),
            recommendation: recommendation,
            explanation: explanation
        )
    }

    func outcomes(
        gradingReport: GradingReport,
        marketSnapshot: MarketSnapshot,
        input: ROIInput
    ) -> [GradeOutcome] {
        let totalGradingCost = input.gradingFee + input.shippingCost + input.insuranceCost

        func outcome(label: String, salePrice: Double, probability: Double, includeGradingCost: Bool) -> GradeOutcome {
            let costs = input.purchasePrice + (includeGradingCost ? totalGradingCost : 0)
            let sellingFee = salePrice * (input.sellingFeePercentage / 100)
            let net = salePrice - sellingFee
            let profit = net - costs
            let roi = costs > 0 ? (profit / costs) * 100 : 0
            return GradeOutcome(
                label: label, estimatedSalePrice: salePrice, totalCosts: costs,
                estimatedNetProceeds: net, profit: profit, roi: roi, probability: probability
            )
        }

        // Tier labels follow the selected company's scale (BGS gem is 9.5).
        let company = GradingCompanyProfile.named(input.gradingCompany) ?? .psa
        return [
            outcome(label: "Sell Raw", salePrice: marketSnapshot.rawEstimatedValue, probability: 1.0, includeGradingCost: false),
            outcome(label: company.eightLabel, salePrice: marketSnapshot.psa8EstimatedValue, probability: gradingReport.psa8Probability, includeGradingCost: true),
            outcome(label: company.nineLabel, salePrice: marketSnapshot.psa9EstimatedValue, probability: gradingReport.psa9Probability, includeGradingCost: true),
            outcome(label: company.gemLabel, salePrice: marketSnapshot.psa10EstimatedValue, probability: gradingReport.psa10Probability, includeGradingCost: true),
        ]
    }
}
