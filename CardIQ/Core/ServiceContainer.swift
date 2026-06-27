import Foundation

final class ServiceContainer {
    static let shared = ServiceContainer()

    let auth: any AuthenticationService
    let cardIdentification: any CardIdentificationService
    let cardGrading: any CardGradingService
    let marketData: any MarketDataService
    let imageQuality: any ImageQualityService
    let subscription: any SubscriptionService
    let imageStorage: any ImageStorageService
    let analytics: any AnalyticsService
    let roiCalculator: any GradeROICalculator
    let marketChat: any MarketChatService
    let collectionRepository: any CollectionRepository

    init(
        auth: any AuthenticationService = SupabaseManager.makeAuth(),
        cardIdentification: any CardIdentificationService = PokemonTCGCardIdentificationService(),
        cardGrading: any CardGradingService = MockCardGradingService(),
        marketData: any MarketDataService = MarketDataFactory.make(),
        imageQuality: any ImageQualityService = MockImageQualityService(),
        subscription: any SubscriptionService = MockSubscriptionService(),
        imageStorage: any ImageStorageService = SupabaseManager.makeImageStorage(),
        analytics: any AnalyticsService = MockAnalyticsService(),
        roiCalculator: any GradeROICalculator = DefaultGradeROICalculator(),
        marketChat: any MarketChatService = MockMarketChatService(),
        collectionRepository: any CollectionRepository = SupabaseManager.makeCollectionRepository()
    ) {
        self.auth = auth
        self.cardIdentification = cardIdentification
        self.cardGrading = cardGrading
        self.marketData = marketData
        self.imageQuality = imageQuality
        self.subscription = subscription
        self.imageStorage = imageStorage
        self.analytics = analytics
        self.roiCalculator = roiCalculator
        self.marketChat = marketChat
        self.collectionRepository = collectionRepository
    }
}
