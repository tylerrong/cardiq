import Foundation

/// Uploads a completed scan's images to Supabase Storage and persists a record
/// to the cloud `scan_records` table — the foundation of the grading dataset and
/// the user's cross-device scan history. Fire-and-forget; no-ops when Supabase
/// isn't configured or the user isn't signed in, so the scan flow is never blocked.
@MainActor
enum ScanSync {
    private static var enabled: Bool { SupabaseManager.isConfigured }
    private static var imageStorage: any ImageStorageService { ServiceContainer.shared.imageStorage }
    private static var repo: any ScanRepository { ServiceContainer.shared.scanRepository }

    static func record(
        scanId: String = UUID().uuidString,
        mode: ScanMode,
        card: CardIdentity,
        report: GradingReport?,
        market: MarketSnapshot?,
        front: Data?,
        back: Data?,
        surface: Data?
    ) {
        guard enabled else { return }
        Task {
            do {
                let frontPath = try await upload(front, identifier: "\(scanId)-front")
                let backPath = try await upload(back, identifier: "\(scanId)-back")
                let surfacePath = try await upload(surface, identifier: "\(scanId)-surface")

                let row = ScanCloudRecord(
                    scanId: scanId,
                    userId: nil,                 // set by the repository from the session
                    scanMode: mode.rawValue,
                    cardIdentity: card,
                    gradingReport: report,
                    marketSnapshot: market,
                    frontImagePath: frontPath,
                    backImagePath: backPath,
                    surfaceImagePath: surfacePath,
                    predictedGrade: report?.estimatedGrade,
                    reportedGrade: nil,
                    reportedCompany: nil,
                    createdAt: Date()
                )
                try await repo.save(row)
            } catch {
                NSLog("ScanSync record failed: \(error)")
            }
        }
    }

    /// Uploads non-empty image data and returns its Storage path. Skips the
    /// Simulator's placeholder bytes and missing captures.
    private static func upload(_ data: Data?, identifier: String) async throws -> String? {
        guard let data, data.count > 256 else { return nil }
        return try await imageStorage.save(image: data, identifier: identifier)
    }
}
