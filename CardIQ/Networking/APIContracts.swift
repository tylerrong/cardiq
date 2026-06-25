import Foundation

enum APIEndpoint {
    case createScan
    case uploadFrontImage(scanId: String)
    case uploadBackImage(scanId: String)
    case uploadSurfaceImage(scanId: String)
    case analyzeScan(scanId: String)
    case getScan(scanId: String)
    case identifyCard
    case searchCards
    case getCard(cardId: String)
    case getMarket(cardId: String)
    case getSales(cardId: String)
    case calculateROI
    case getCollection
    case addToCollection
    case updateCollectionItem(itemId: String)
    case deleteCollectionItem(itemId: String)
    case submitOfficialGrade(scanId: String)
}

struct CreateScanRequest: Codable, Sendable {
    let deviceId: String
    let captureTimestamp: Date
}

struct CreateScanResponse: Codable, Sendable {
    let scanId: String
    let uploadURLs: UploadURLs
}

struct UploadURLs: Codable, Sendable {
    let frontImage: String
    let backImage: String
    let surfaceImage: String?
}

struct AnalyzeScanRequest: Codable, Sendable {
    let scanId: String
    let requestedAnalyses: [String]
}

struct AnalyzeScanResponse: Codable, Sendable {
    let scanId: String
    let cardIdentity: CardIdentity
    let gradingReport: GradingReport
    let marketSnapshot: MarketSnapshot
}

struct IdentifyCardRequest: Codable, Sendable {
    let frontImageData: String
    let backImageData: String?
}

struct IdentifyCardResponse: Codable, Sendable {
    let matches: [CardIdentity]
}

struct SearchCardsRequest: Codable, Sendable {
    let query: String
    let limit: Int?
    let offset: Int?
}

struct SearchCardsResponse: Codable, Sendable {
    let results: [CardIdentity]
    let totalCount: Int
}

struct CalculateROIRequest: Codable, Sendable {
    let cardId: String
    let gradingReport: GradingReport
    let marketSnapshot: MarketSnapshot
    let purchasePrice: Double
    let gradingCompany: String
    let gradingFee: Double
    let shippingCost: Double
    let insuranceCost: Double
    let sellingFeePercentage: Double
}

struct CalculateROIResponse: Codable, Sendable {
    let result: GradeROIResult
}

struct AddToCollectionRequest: Codable, Sendable {
    let scanId: String?
    let cardId: String
    let purchasePrice: Double?
    let purchaseDate: Date?
    let quantity: Int
    let notes: String?
}

struct CollectionResponse: Codable, Sendable {
    let items: [CollectionItemResponse]
}

struct CollectionItemResponse: Codable, Sendable {
    let itemId: String
    let cardIdentity: CardIdentity
    let purchasePrice: Double?
    let currentValue: Double
    let gainLoss: Double
    let dateAdded: Date
}

struct SubmitOfficialGradeRequest: Codable, Sendable {
    let gradingCompany: String
    let officialGrade: Double
    let certificationNumber: String
    let dateReceived: Date
    let allowAnonymizedData: Bool
}

struct SubmitOfficialGradeResponse: Codable, Sendable {
    let predictedGrade: Double
    let officialGrade: Double
    let difference: Double
    let updatedValuation: Double
}

protocol APIClient: Sendable {
    func createScan(_ request: CreateScanRequest) async throws -> CreateScanResponse
    func uploadImage(endpoint: APIEndpoint, imageData: Data) async throws
    func analyzeScan(_ request: AnalyzeScanRequest) async throws -> AnalyzeScanResponse
    func identifyCard(_ request: IdentifyCardRequest) async throws -> IdentifyCardResponse
    func searchCards(_ request: SearchCardsRequest) async throws -> SearchCardsResponse
    func calculateROI(_ request: CalculateROIRequest) async throws -> CalculateROIResponse
}

final class MockAPIClient: APIClient {
    func createScan(_ request: CreateScanRequest) async throws -> CreateScanResponse {
        CreateScanResponse(scanId: UUID().uuidString, uploadURLs: UploadURLs(frontImage: "mock://upload/front", backImage: "mock://upload/back", surfaceImage: nil))
    }

    func uploadImage(endpoint: APIEndpoint, imageData: Data) async throws {}

    func analyzeScan(_ request: AnalyzeScanRequest) async throws -> AnalyzeScanResponse {
        let card = MockSeedData.cards[0]
        return AnalyzeScanResponse(
            scanId: request.scanId,
            cardIdentity: card,
            gradingReport: MockSeedData.gradingReport(for: card.id),
            marketSnapshot: MockSeedData.marketSnapshot(for: card.id)
        )
    }

    func identifyCard(_ request: IdentifyCardRequest) async throws -> IdentifyCardResponse {
        IdentifyCardResponse(matches: Array(MockSeedData.cards.prefix(5)))
    }

    func searchCards(_ request: SearchCardsRequest) async throws -> SearchCardsResponse {
        let results = MockSeedData.cards.filter { $0.name.localizedCaseInsensitiveContains(request.query) }
        return SearchCardsResponse(results: results, totalCount: results.count)
    }

    func calculateROI(_ request: CalculateROIRequest) async throws -> CalculateROIResponse {
        let calculator = DefaultGradeROICalculator()
        let input = ROIInput(
            purchasePrice: request.purchasePrice,
            gradingCompany: request.gradingCompany,
            gradingFee: request.gradingFee,
            shippingCost: request.shippingCost,
            insuranceCost: request.insuranceCost,
            sellingFeePercentage: request.sellingFeePercentage,
            requiredMarginPercentage: 20
        )
        let result = calculator.calculate(gradingReport: request.gradingReport, marketSnapshot: request.marketSnapshot, input: input)
        return CalculateROIResponse(result: result)
    }
}
