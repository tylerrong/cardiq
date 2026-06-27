import Foundation

/// No-op collection repository used when Supabase is not configured. The app's
/// collection is persisted locally via SwiftData, so the cloud repository is a
/// fallback that simply does nothing until credentials are added.
final class MockCollectionRepository: CollectionRepository {
    func fetchAll() async throws -> [CollectionItem] { [] }
    func save(_ item: CollectionItem) async throws {}
    func update(_ item: CollectionItem) async throws {}
    func delete(_ itemId: String) async throws {}
    func item(for id: String) async throws -> CollectionItem? { nil }
}
