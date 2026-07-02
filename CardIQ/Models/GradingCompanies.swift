import Foundation

/// Grading companies the ROI engine models. Fees are current value/bulk-tier
/// prices; the multipliers translate the PSA-anchored graded-value estimates
/// into each company's typical market realization. Community heuristics until
/// per-company comps land — the same status as the PSA tier multipliers
/// themselves.
enum GradingCompanyProfile: String, CaseIterable, Identifiable, Codable {
    case psa, bgs, cgc, tag

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .psa: "PSA"
        case .bgs: "BGS"
        case .cgc: "CGC"
        case .tag: "TAG"
        }
    }

    /// Value/bulk-tier grading fee per card (USD).
    var fee: Double {
        switch self {
        case .psa: 24.99
        case .bgs: 27
        case .cgc: 18
        case .tag: 18
        }
    }

    /// Typical advertised turnaround, business days.
    var turnaroundDays: Int {
        switch self {
        case .psa: 45
        case .bgs: 40
        case .cgc: 25
        case .tag: 14
        }
    }

    /// Tier labels — the top tier differs by company scale (BGS gem is 9.5).
    var gemLabel: String {
        switch self {
        case .psa: "PSA 10"
        case .bgs: "BGS 9.5"
        case .cgc: "CGC 10"
        case .tag: "TAG 10"
        }
    }

    var nineLabel: String { "\(displayName) 9" }
    var eightLabel: String { "\(displayName) 8" }

    /// Market realization of each tier relative to the PSA-anchored estimate.
    /// PSA slabs carry the strongest premium for Pokemon; the discounts below
    /// reflect typical sold-comp gaps.
    private var tierMultipliers: (gem: Double, nine: Double, eight: Double) {
        switch self {
        case .psa: (1.0, 1.0, 1.0)
        case .bgs: (0.80, 0.85, 0.90)
        case .cgc: (0.75, 0.80, 0.85)
        case .tag: (0.70, 0.75, 0.80)
        }
    }

    /// The snapshot re-anchored to this company's expected sale prices.
    func adjusted(_ market: MarketSnapshot) -> MarketSnapshot {
        let m = tierMultipliers
        var copy = market
        copy.psa10EstimatedValue = market.psa10EstimatedValue * m.gem
        copy.psa9EstimatedValue = market.psa9EstimatedValue * m.nine
        copy.psa8EstimatedValue = market.psa8EstimatedValue * m.eight
        return copy
    }

    /// ROI inputs for grading with this company.
    func input(purchasePrice: Double) -> ROIInput {
        var input = ROIInput.default
        input.purchasePrice = purchasePrice
        input.gradingCompany = displayName
        input.gradingFee = fee
        return input
    }

    /// Resolve from a free-form company string ("PSA", "bgs", "Beckett"...).
    static func named(_ name: String) -> GradingCompanyProfile? {
        switch name.lowercased() {
        case "psa": .psa
        case "bgs", "beckett", "bvg": .bgs
        case "cgc": .cgc
        case "tag": .tag
        default: nil
        }
    }
}

/// One company's expected grading economics for a specific card.
struct CompanyGradingOutcome: Identifiable {
    var id: String { company.rawValue }
    let company: GradingCompanyProfile
    let result: GradeROIResult
}

enum GradingCompanyComparison {
    /// Expected outcome per company for this card and condition read, best
    /// expected profit first.
    static func outcomes(
        report: GradingReport,
        market: MarketSnapshot,
        purchasePrice: Double = 0
    ) -> [CompanyGradingOutcome] {
        let calculator = DefaultGradeROICalculator()
        return GradingCompanyProfile.allCases.map { company in
            CompanyGradingOutcome(
                company: company,
                result: calculator.calculate(
                    gradingReport: report,
                    marketSnapshot: company.adjusted(market),
                    input: company.input(purchasePrice: purchasePrice)
                )
            )
        }
        .sorted { $0.result.expectedProfit > $1.result.expectedProfit }
    }
}
