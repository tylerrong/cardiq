import Foundation
import Supabase

/// Live `CollectionRepository` backed by a Postgres `collection_items` table.
/// Card identity, grading report, and market snapshot are stored as `jsonb`
/// columns; everything else maps to scalar columns. Row-level security scopes
/// every query to the signed-in user.
final class SupabaseCollectionRepository: CollectionRepository {
    private let client: SupabaseClient
    private let table = "collection_items"

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchAll() async throws -> [CollectionItem] {
        let userId = try currentUserId()
        let rows: [CollectionItemRow] = try await client
            .from(table)
            .select()
            .eq("user_id", value: userId)
            .order("date_added", ascending: false)
            .execute()
            .value
        return rows.map { $0.makeCollectionItem() }
    }

    func save(_ item: CollectionItem) async throws {
        let userId = try currentUserId()
        let row = CollectionItemRow(item: item, userId: userId)
        try await client.from(table).upsert(row, onConflict: "item_id").execute()
    }

    func update(_ item: CollectionItem) async throws {
        try await save(item)
    }

    func delete(_ itemId: String) async throws {
        let userId = try currentUserId()
        try await client
            .from(table)
            .delete()
            .eq("item_id", value: itemId)
            .eq("user_id", value: userId)
            .execute()
    }

    func item(for id: String) async throws -> CollectionItem? {
        let userId = try currentUserId()
        let rows: [CollectionItemRow] = try await client
            .from(table)
            .select()
            .eq("item_id", value: id)
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first?.makeCollectionItem()
    }

    private func currentUserId() throws -> String {
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw SupabaseServiceError.notAuthenticated
        }
        return userId
    }
}

/// Codable mirror of the `collection_items` table.
struct CollectionItemRow: Codable {
    var itemId: String
    var userId: String?
    var cardIdentity: CardIdentity?
    var gradingReport: GradingReport?
    var marketSnapshot: MarketSnapshot?
    var frontImagePath: String?
    var backImagePath: String?
    var surfaceImagePath: String?
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

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case userId = "user_id"
        case cardIdentity = "card_identity"
        case gradingReport = "grading_report"
        case marketSnapshot = "market_snapshot"
        case frontImagePath = "front_image_path"
        case backImagePath = "back_image_path"
        case surfaceImagePath = "surface_image_path"
        case purchasePrice = "purchase_price"
        case purchaseDate = "purchase_date"
        case quantity
        case notes
        case officialGrade = "official_grade"
        case officialGradingCompany = "official_grading_company"
        case officialCertNumber = "official_cert_number"
        case officialGradeDate = "official_grade_date"
        case allowAnonymizedData = "allow_anonymized_data"
        case dateAdded = "date_added"
        case scanId = "scan_id"
    }

    init(item: CollectionItem, userId: String?) {
        self.itemId = item.itemId
        self.userId = userId
        self.cardIdentity = item.cardIdentity
        self.gradingReport = item.gradingReport
        self.marketSnapshot = item.marketSnapshot
        self.frontImagePath = item.frontImageLocalPath
        self.backImagePath = item.backImageLocalPath
        self.surfaceImagePath = item.surfaceImageLocalPath
        self.purchasePrice = item.purchasePrice
        self.purchaseDate = item.purchaseDate
        self.quantity = item.quantity
        self.notes = item.notes
        self.officialGrade = item.officialGrade
        self.officialGradingCompany = item.officialGradingCompany
        self.officialCertNumber = item.officialCertNumber
        self.officialGradeDate = item.officialGradeDate
        self.allowAnonymizedData = item.allowAnonymizedData
        self.dateAdded = item.dateAdded
        self.scanId = item.scanId
    }

    func makeCollectionItem() -> CollectionItem {
        let item = CollectionItem(
            itemId: itemId,
            cardIdentity: cardIdentity,
            purchasePrice: purchasePrice,
            purchaseDate: purchaseDate,
            quantity: quantity,
            notes: notes,
            dateAdded: dateAdded
        )
        item.gradingReport = gradingReport
        item.marketSnapshot = marketSnapshot
        item.frontImageLocalPath = frontImagePath
        item.backImageLocalPath = backImagePath
        item.surfaceImageLocalPath = surfaceImagePath
        item.officialGrade = officialGrade
        item.officialGradingCompany = officialGradingCompany
        item.officialCertNumber = officialCertNumber
        item.officialGradeDate = officialGradeDate
        item.allowAnonymizedData = allowAnonymizedData
        item.scanId = scanId
        return item
    }
}
