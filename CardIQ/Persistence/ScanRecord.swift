import Foundation
import SwiftData

@Model
final class ScanRecord {
    @Attribute(.unique) var scanId: String
    var cardIdentityData: Data?
    var gradingReportData: Data?
    var marketSnapshotData: Data?
    var scanDate: Date
    var savedToCollection: Bool

    init(
        scanId: String = UUID().uuidString,
        cardIdentity: CardIdentity? = nil,
        gradingReport: GradingReport? = nil,
        marketSnapshot: MarketSnapshot? = nil,
        scanDate: Date = Date(),
        savedToCollection: Bool = false
    ) {
        self.scanId = scanId
        self.scanDate = scanDate
        self.savedToCollection = savedToCollection
        self.cardIdentityData = try? JSONEncoder().encode(cardIdentity)
        self.gradingReportData = try? JSONEncoder().encode(gradingReport)
        self.marketSnapshotData = try? JSONEncoder().encode(marketSnapshot)
    }

    var cardIdentity: CardIdentity? {
        get {
            guard let data = cardIdentityData else { return nil }
            return try? JSONDecoder().decode(CardIdentity.self, from: data)
        }
        set { cardIdentityData = try? JSONEncoder().encode(newValue) }
    }

    var gradingReport: GradingReport? {
        get {
            guard let data = gradingReportData else { return nil }
            return try? JSONDecoder().decode(GradingReport.self, from: data)
        }
        set { gradingReportData = try? JSONEncoder().encode(newValue) }
    }

    var marketSnapshot: MarketSnapshot? {
        get {
            guard let data = marketSnapshotData else { return nil }
            return try? JSONDecoder().decode(MarketSnapshot.self, from: data)
        }
        set { marketSnapshotData = try? JSONEncoder().encode(newValue) }
    }
}
