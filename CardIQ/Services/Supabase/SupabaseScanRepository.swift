import Foundation
import Supabase

/// Live `ScanRepository` backed by the Postgres `scan_records` table. Each scan
/// is stored under the signed-in user (RLS-scoped) with the Storage paths of the
/// captured images, forming the dataset behind the grading models.
final class SupabaseScanRepository: ScanRepository {
    private let client: SupabaseClient
    private let table = "scan_records"

    init(client: SupabaseClient) {
        self.client = client
    }

    func save(_ record: ScanCloudRecord) async throws {
        guard let session = try? await client.auth.session else {
            throw SupabaseServiceError.notAuthenticated
        }
        var row = record
        row.userId = session.user.id.uuidString
        try await client.from(table).upsert(row, onConflict: "scan_id").execute()
    }
}

/// Codable mirror of the `scan_records` table. Card / report / market are stored
/// as `jsonb`; `predicted/reported` grade columns back the future feedback loop.
struct ScanCloudRecord: Codable {
    var scanId: String
    var userId: String?
    var scanMode: String
    var cardIdentity: CardIdentity?
    var gradingReport: GradingReport?
    var marketSnapshot: MarketSnapshot?
    var frontImagePath: String?
    var backImagePath: String?
    var surfaceImagePath: String?
    var predictedGrade: Double?
    var reportedGrade: Double?
    var reportedCompany: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case scanId = "scan_id"
        case userId = "user_id"
        case scanMode = "scan_mode"
        case cardIdentity = "card_identity"
        case gradingReport = "grading_report"
        case marketSnapshot = "market_snapshot"
        case frontImagePath = "front_image_path"
        case backImagePath = "back_image_path"
        case surfaceImagePath = "surface_image_path"
        case predictedGrade = "predicted_grade"
        case reportedGrade = "reported_grade"
        case reportedCompany = "reported_company"
        case createdAt = "created_at"
    }
}
