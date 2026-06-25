import Foundation

struct AppUser: Codable, Sendable {
    var id: String
    var name: String
    var email: String
    var subscriptionTier: SubscriptionTier
    var freeScansRemaining: Int
    var preferredGradingCompany: String
    var defaultSellingFeePercentage: Double
    var createdAt: Date

    static let free = AppUser(
        id: "user_mock_001",
        name: "Collector",
        email: "",
        subscriptionTier: .free,
        freeScansRemaining: 3,
        preferredGradingCompany: "PSA",
        defaultSellingFeePercentage: 13,
        createdAt: Date()
    )
}

enum SubscriptionTier: String, Codable, Sendable, CaseIterable {
    case free
    case collectorPro
    case dealer

    var displayName: String {
        switch self {
        case .free: "Free"
        case .collectorPro: "Collector Pro"
        case .dealer: "Dealer"
        }
    }

    var scanLimit: Int {
        switch self {
        case .free: 3
        case .collectorPro: 50
        case .dealer: 500
        }
    }
}

enum CollectorType: String, Codable, CaseIterable, Sendable {
    case casual
    case investor
    case flipper
    case dealer

    var displayName: String {
        switch self {
        case .casual: "Casual Collector"
        case .investor: "Investor"
        case .flipper: "Flipper"
        case .dealer: "Dealer"
        }
    }

    var description: String {
        switch self {
        case .casual: "I collect cards I love and want to protect my favorites."
        case .investor: "I buy and hold cards as long-term investments."
        case .flipper: "I buy undervalued cards and sell for profit."
        case .dealer: "I run a business buying and selling cards."
        }
    }

    var icon: String {
        switch self {
        case .casual: "heart.fill"
        case .investor: "chart.line.uptrend.xyaxis"
        case .flipper: "arrow.triangle.2.circlepath"
        case .dealer: "storefront.fill"
        }
    }
}

struct SubscriptionPlan: Identifiable, Sendable {
    let id: String
    var tier: SubscriptionTier
    var name: String
    var monthlyPrice: Double
    var yearlyPrice: Double
    var features: [String]
    var scanLimit: Int
    var isComingSoon: Bool
}
