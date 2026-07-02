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

/// A collection card worth grading, paired with its real predicted report
/// (from the scan or add flow) so the rail doesn't re-derive it.
struct HomeGradingCandidate: Identifiable {
    var id: String { card.id }
    let card: CardIdentity
    let report: GradingReport
}

struct HomeRecentCard: Identifiable {
    var id: String { card.id }
    let card: CardIdentity
    let report: GradingReport?
}

@Observable
@MainActor
final class HomeViewModel {
    var totalValue: Double = 0
    var totalInvested: Double = 0
    var unrealizedGainLoss: Double = 0
    var freeScansRemaining: Int = 3
    var recommendedForGrading: [HomeGradingCandidate] = []
    var recentScans: [HomeRecentCard] = []
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

    /// Everything on Home derives from the user's real collection. An empty
    /// collection means an empty (honest) dashboard — the sections hide and
    /// the scan CTA carries the screen. No demo data.
    private func loadFromCollection(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<CollectionItem>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        let items = (try? modelContext.fetch(descriptor)) ?? []

        var totalVal = 0.0
        var totalInv = 0.0
        var movers: [HomeMover] = []
        var recent: [HomeRecentCard] = []
        var gradeRecommendations: [HomeGradingCandidate] = []

        for item in items {
            totalVal += item.currentValue
            if let purchase = item.purchasePrice {
                totalInv += purchase
            }

            if let card = item.cardIdentity {
                if recent.count < 5 {
                    recent.append(HomeRecentCard(card: card, report: item.gradingReport))
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
                        gradeRecommendations.append(HomeGradingCandidate(card: card, report: report))
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
    }
}
