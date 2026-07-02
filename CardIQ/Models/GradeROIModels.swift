import Foundation

struct GradeROIResult: Codable, Sendable {
    var gradingCompany: String
    var gradingFee: Double
    var shippingCost: Double
    var insuranceCost: Double
    var sellingFeePercentage: Double
    var totalCostBasis: Double
    var expectedGradedValue: Double
    var expectedNetProceeds: Double
    var expectedProfit: Double
    var expectedROI: Double
    var maximumRecommendedBuyPrice: Double
    var recommendation: GradeRecommendation
    var explanation: String
}

enum GradeRecommendation: String, Codable, Sendable {
    case grade
    case considerGrading
    case sellRaw
    case hold
    case insufficientData

    var displayName: String {
        switch self {
        case .grade: "Grade This Card"
        case .considerGrading: "Consider Grading"
        case .sellRaw: "Sell Raw"
        case .hold: "Hold"
        case .insufficientData: "Insufficient Data"
        }
    }

    var icon: String {
        switch self {
        case .grade: "checkmark.seal.fill"
        case .considerGrading: "hand.thumbsup.fill"
        case .sellRaw: "tag.fill"
        case .hold: "clock.fill"
        case .insufficientData: "questionmark.circle.fill"
        }
    }

    var colorName: String {
        switch self {
        case .grade: "positive"
        case .considerGrading: "accentPrimary"
        case .sellRaw: "warning"
        case .hold: "textSecondary"
        case .insufficientData: "textTertiary"
        }
    }
}

struct GradeOutcome: Identifiable, Sendable {
    var id: String { label }
    var label: String
    var estimatedSalePrice: Double
    var totalCosts: Double
    var estimatedNetProceeds: Double
    var profit: Double
    var roi: Double
    var probability: Double
}

struct ROIInput: Sendable {
    var purchasePrice: Double
    var gradingCompany: String
    var gradingFee: Double
    var shippingCost: Double
    var insuranceCost: Double
    var sellingFeePercentage: Double
    var requiredMarginPercentage: Double

    /// Baseline inputs, honoring the user's Grading Defaults from Profile
    /// (falls back to PSA / $25 / $15 / 13% when unset).
    static var `default`: ROIInput {
        let defaults = UserDefaults.standard
        return ROIInput(
            purchasePrice: 0,
            gradingCompany: defaults.string(forKey: "preferredGradingCompany") ?? "PSA",
            gradingFee: defaults.object(forKey: "defaultGradingFee") as? Double ?? 25,
            shippingCost: defaults.object(forKey: "defaultShippingCost") as? Double ?? 15,
            insuranceCost: 5,
            sellingFeePercentage: defaults.object(forKey: "defaultSellingFee") as? Double ?? 13,
            requiredMarginPercentage: 20
        )
    }
}
