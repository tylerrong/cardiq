import Foundation
import SwiftData

@Model
final class WatchlistItem {
    @Attribute(.unique) var cardId: String
    var cardIdentityData: Data?
    var targetPrice: Double?
    var dateAdded: Date

    init(cardIdentity: CardIdentity, targetPrice: Double? = nil) {
        self.cardId = cardIdentity.id
        self.cardIdentityData = try? JSONEncoder().encode(cardIdentity)
        self.targetPrice = targetPrice
        self.dateAdded = Date()
    }

    var cardIdentity: CardIdentity? {
        get {
            guard let data = cardIdentityData else { return nil }
            return try? JSONDecoder().decode(CardIdentity.self, from: data)
        }
        set { cardIdentityData = try? JSONEncoder().encode(newValue) }
    }
}
