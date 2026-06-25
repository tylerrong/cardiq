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

    init(
        auth: any AuthenticationService = MockAuthenticationService(),
        cardIdentification: any CardIdentificationService = MockCardIdentificationService(),
        cardGrading: any CardGradingService = MockCardGradingService(),
        marketData: any MarketDataService = MockMarketDataService(),
        imageQuality: any ImageQualityService = MockImageQualityService(),
        subscription: any SubscriptionService = MockSubscriptionService(),
        imageStorage: any ImageStorageService = MockImageStorageService(),
        analytics: any AnalyticsService = MockAnalyticsService(),
        roiCalculator: any GradeROICalculator = DefaultGradeROICalculator(),
        marketChat: any MarketChatService = MockMarketChatService()
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
    }
}
