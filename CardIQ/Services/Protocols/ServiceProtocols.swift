import Foundation
import SwiftUI

protocol AuthenticationService {
    func signInWithApple() async throws -> AppUser
    func signIn(email: String, password: String) async throws -> AppUser
    func signUp(email: String, password: String) async throws -> AppUser
    func signOut() async throws
    func currentUser() async -> AppUser?
    func deleteAccount() async throws
}

protocol CardIdentificationService {
    func identify(frontImage: Data, backImage: Data?) async throws -> [CardIdentity]
    func search(query: String) async throws -> [CardIdentity]
    func allCards() async -> [CardIdentity]
}

protocol CardGradingService {
    func analyze(cardId: String, frontImage: Data, backImage: Data, surfaceImage: Data?) async throws -> GradingReport
}

protocol MarketDataService {
    func snapshot(for cardId: String) async throws -> MarketSnapshot
    func priceHistory(for cardId: String, range: TimeRange) async throws -> [PriceHistoryPoint]
    func trendingCards() async throws -> [CardIdentity]
}

protocol ImageQualityService {
    func assess(image: Data, captureType: CaptureType) async throws -> ImageQualityReport
}

enum CaptureType: String {
    case front
    case back
    case surface
}

protocol CollectionRepository {
    func fetchAll() async throws -> [CollectionItem]
    func save(_ item: CollectionItem) async throws
    func update(_ item: CollectionItem) async throws
    func delete(_ itemId: String) async throws
    func item(for id: String) async throws -> CollectionItem?
}

protocol SubscriptionService {
    func availablePlans() async throws -> [SubscriptionPlan]
    func currentTier() async -> SubscriptionTier
    func purchase(planId: String) async throws -> SubscriptionTier
    func restorePurchases() async throws -> SubscriptionTier
    func remainingScans() async -> Int
    func consumeScan() async throws
}

protocol ImageStorageService {
    func save(image: Data, identifier: String) async throws -> String
    func load(path: String) async throws -> Data
    func delete(path: String) async throws
}

protocol AnalyticsService {
    func track(_ event: AnalyticsEvent)
}

protocol GradeROICalculator {
    func calculate(
        gradingReport: GradingReport,
        marketSnapshot: MarketSnapshot,
        input: ROIInput
    ) -> GradeROIResult

    func outcomes(
        gradingReport: GradingReport,
        marketSnapshot: MarketSnapshot,
        input: ROIInput
    ) -> [GradeOutcome]
}

protocol MarketChatService {
    func sendMessage(_ text: String, context: MarketChatContext) async throws -> MarketChatResponse
}

struct MarketChatContext {
    var recentCards: [CardIdentity]
    var collectionCardIds: [String]
}

struct MarketChatResponse {
    var text: String
    var referencedCards: [CardIdentity]
    var dataPulls: [MarketChatDataPull]
}

struct MarketChatDataPull: Identifiable {
    let id = UUID().uuidString
    var label: String
    var cardName: String
    var value: String
    var changePercent: Double?
}
