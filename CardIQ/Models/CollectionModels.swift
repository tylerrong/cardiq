import Foundation
import SwiftData

@Model
final class CollectionItem {
    @Attribute(.unique) var itemId: String
    var cardIdentityData: Data?
    var frontImageLocalPath: String?
    var backImageLocalPath: String?
    var surfaceImageLocalPath: String?
    var gradingReportData: Data?
    var marketSnapshotData: Data?
    var purchasePrice: Double?
    var purchaseDate: Date?
    var quantity: Int
    var notes: String?
    var officialGrade: Double?
    var officialGradingCompany: String?
    var officialCertNumber: String?
    var officialGradeDate: Date?
    var allowAnonymizedData: Bool
    var dateAdded: Date
    var scanId: String?

    init(
        itemId: String = UUID().uuidString,
        cardIdentity: CardIdentity? = nil,
        purchasePrice: Double? = nil,
        purchaseDate: Date? = nil,
        quantity: Int = 1,
        notes: String? = nil,
        dateAdded: Date = Date()
    ) {
        self.itemId = itemId
        self.quantity = quantity
        self.notes = notes
        self.dateAdded = dateAdded
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.allowAnonymizedData = false
        if let cardIdentity {
            self.cardIdentityData = try? JSONEncoder().encode(cardIdentity)
        }
    }

    var cardIdentity: CardIdentity? {
        get {
            guard let data = cardIdentityData else { return nil }
            return try? JSONDecoder().decode(CardIdentity.self, from: data)
        }
        set {
            cardIdentityData = try? JSONEncoder().encode(newValue)
        }
    }

    var gradingReport: GradingReport? {
        get {
            guard let data = gradingReportData else { return nil }
            return try? JSONDecoder().decode(GradingReport.self, from: data)
        }
        set {
            gradingReportData = try? JSONEncoder().encode(newValue)
        }
    }

    var marketSnapshot: MarketSnapshot? {
        get {
            guard let data = marketSnapshotData else { return nil }
            return try? JSONDecoder().decode(MarketSnapshot.self, from: data)
        }
        set {
            marketSnapshotData = try? JSONEncoder().encode(newValue)
        }
    }

    var currentValue: Double {
        if let officialGrade, let market = marketSnapshot {
            switch officialGrade {
            case 10: return market.psa10EstimatedValue
            case 9...9.5: return market.psa9EstimatedValue
            case 8...8.5: return market.psa8EstimatedValue
            default: return market.rawEstimatedValue
            }
        }
        return marketSnapshot?.rawEstimatedValue ?? 0
    }

    var gainLoss: Double {
        guard let purchase = purchasePrice else { return 0 }
        return currentValue - purchase
    }

    var gainLossPercentage: Double {
        guard let purchase = purchasePrice, purchase > 0 else { return 0 }
        return ((currentValue - purchase) / purchase) * 100
    }
}

enum CollectionSortOption: String, CaseIterable, Sendable {
    case highestValue
    case lowestValue
    case biggestGain
    case biggestLoss
    case recentlyAdded
    case alphabetical

    var displayName: String {
        switch self {
        case .highestValue: "Highest Value"
        case .lowestValue: "Lowest Value"
        case .biggestGain: "Biggest Gain"
        case .biggestLoss: "Biggest Loss"
        case .recentlyAdded: "Recently Added"
        case .alphabetical: "Alphabetical"
        }
    }
}

enum CollectionFilterOption: String, CaseIterable, Sendable {
    case all
    case raw
    case graded
    case pokemon
    case gainers
    case losers

    var displayName: String {
        switch self {
        case .all: "All"
        case .raw: "Raw"
        case .graded: "Graded"
        case .pokemon: "Pokémon"
        case .gainers: "Gainers"
        case .losers: "Losers"
        }
    }
}
