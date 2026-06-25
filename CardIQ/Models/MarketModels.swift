import Foundation

struct MarketSnapshot: Codable, Sendable {
    var rawEstimatedValue: Double
    var psa8EstimatedValue: Double
    var psa9EstimatedValue: Double
    var psa10EstimatedValue: Double
    var thirtyDayChangePercentage: Double
    var ninetyDayChangePercentage: Double
    var oneYearChangePercentage: Double
    var salesVolume30Days: Int
    var liquidityScore: Double
    var recentSales: [ComparableSale]
    var updatedAt: Date
}

struct ComparableSale: Identifiable, Codable, Sendable {
    let id: String
    var marketplace: String
    var title: String
    var salePrice: Double
    var shippingPrice: Double
    var saleDate: Date
    var condition: String
    var gradingCompany: String?
    var grade: Double?
    var matchQuality: MatchQuality
    var imageURL: String?
}

enum MatchQuality: String, Codable, CaseIterable, Sendable {
    case exact
    case strong
    case partial
    case weak

    var displayName: String {
        rawValue.capitalized
    }

    var badgeColor: String {
        switch self {
        case .exact: "positive"
        case .strong: "accentPrimary"
        case .partial: "warning"
        case .weak: "textTertiary"
        }
    }
}

struct PriceHistoryPoint: Codable, Sendable, Identifiable {
    var id: Date { date }
    var date: Date
    var price: Double
}

enum TimeRange: String, CaseIterable, Sendable {
    case thirtyDays = "30D"
    case ninetyDays = "90D"
    case oneYear = "1Y"
    case allTime = "All"

    var displayName: String { rawValue }
}
