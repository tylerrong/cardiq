import Foundation

/// No-op scan repository used when Supabase is not configured.
final class MockScanRepository: ScanRepository {
    func save(_ record: ScanCloudRecord) async throws {}
}
