import Foundation
import Observation
import SwiftData

struct HomeMover: Identifiable {
    var id: String { card.id }
    let card: CardIdentity
    let currentValue: Double
    let change: Double

    var changeFormatted: String {
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(change.percentFormatted)"
    }
}

@Observable
@MainActor
final class HomeViewModel {
    var totalValue: Double = 0
    var totalInvested: Double = 0
    var unrealizedGainLoss: Double = 0
    var freeScansRemaining: Int = 3
    var recommendedForGrading: [CardIdentity] = []
    var recentScans: [CardIdentity] = []
    var biggestMovers: [HomeMover] = []

    var collectorType: CollectorType?

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 5..<12: timeGreeting = "Good Morning"
        case 12..<17: timeGreeting = "Good Afternoon"
        default: timeGreeting = "Good Evening"
        }
        return timeGreeting
    }

    var dashboardSubtitle: String {
        switch collectorType {
        case .investor: "Here's your portfolio performance."
        case .flipper: "Here's your flip pipeline."
        case .dealer: "Here's your inventory overview."
        default: "Here's your collection overview."
        }
    }

    private let services = ServiceContainer.shared

    func load(modelContext: ModelContext) async {
        let scans = await services.subscription.remainingScans()
        freeScansRemaining = scans

        loadFromCollection(modelContext: modelContext)
    }

    private func loadFromCollection(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<CollectionItem>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        let items = (try? modelContext.fetch(descriptor)) ?? []

        if items.isEmpty {
            loadFallbackData()
            return
        }

        var totalVal = 0.0
        var totalInv = 0.0
        var movers: [HomeMover] = []
        var recent: [CardIdentity] = []
        var gradeRecommendations: [CardIdentity] = []

        for item in items {
            totalVal += item.currentValue
            if let purchase = item.purchasePrice {
                totalInv += purchase
            }

            if let card = item.cardIdentity {
                if recent.count < 5 {
                    recent.append(card)
                }

                if let market = item.marketSnapshot {
                    movers.append(HomeMover(
                        card: card,
                        currentValue: item.currentValue,
                        change: market.thirtyDayChangePercentage
                    ))
                }

                if item.officialGrade == nil, let report = item.gradingReport {
                    if report.psa10Probability >= 0.2 || report.psa9Probability >= 0.4 {
                        gradeRecommendations.append(card)
                    }
                }
            }
        }

        totalValue = totalVal
        totalInvested = totalInv
        unrealizedGainLoss = totalVal - totalInv

        recentScans = recent
        biggestMovers = movers.sorted { abs($0.change) > abs($1.change) }.prefix(4).map { $0 }
        recommendedForGrading = Array(gradeRecommendations.prefix(5))

        if recommendedForGrading.isEmpty {
            recommendedForGrading = [MockSeedData.cards[0], MockSeedData.cards[1], MockSeedData.cards[3]]
        }
    }

    private func loadFallbackData() {
        let items = MockSeedData.sampleCollectionItems
        var totalVal = 0.0
        var totalInv = 0.0

        for item in items {
            let market = MockSeedData.marketSnapshot(for: item.card.id)
            let value: Double
            if let grade = item.grade {
                switch grade {
                case 10: value = market.psa10EstimatedValue
                case 9...9.5: value = market.psa9EstimatedValue
                case 8...8.5: value = market.psa8EstimatedValue
                default: value = market.rawEstimatedValue
                }
            } else {
                value = market.rawEstimatedValue
            }
            totalVal += value
            if let purchase = item.purchase {
                totalInv += purchase
            }
        }

        totalValue = totalVal
        totalInvested = totalInv
        unrealizedGainLoss = totalVal - totalInv

        recommendedForGrading = [MockSeedData.cards[0], MockSeedData.cards[1], MockSeedData.cards[3]]
        recentScans = Array(MockSeedData.cards.prefix(4))
        biggestMovers = [
            HomeMover(card: MockSeedData.cards[3], currentValue: 95.0, change: 15.0),
            HomeMover(card: MockSeedData.cards[11], currentValue: 110.0, change: 12.0),
            HomeMover(card: MockSeedData.cards[0], currentValue: 185.0, change: 5.2),
            HomeMover(card: MockSeedData.cards[2], currentValue: 55.0, change: -8.0),
        ]
    }
}
