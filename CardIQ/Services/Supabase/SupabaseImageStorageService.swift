import Foundation
import Supabase

/// Live `ImageStorageService` backed by Supabase Storage. Files are namespaced
/// under the signed-in user's id (`<uid>/<identifier>.jpg`) so row-level
/// storage policies can restrict access to the owner.
final class SupabaseImageStorageService: ImageStorageService {
    private let client: SupabaseClient
    private let bucket = "card-images"

    init(client: SupabaseClient) {
        self.client = client
    }

    func save(image: Data, identifier: String) async throws -> String {
        let path = try await storagePath(for: identifier)
        try await client.storage
            .from(bucket)
            .upload(path, data: image, options: FileOptions(contentType: "image/jpeg", upsert: true))
        return path
    }

    func load(path: String) async throws -> Data {
        try await client.storage.from(bucket).download(path: path)
    }

    func delete(path: String) async throws {
        _ = try await client.storage.from(bucket).remove(paths: [path])
    }

    private func storagePath(for identifier: String) async throws -> String {
        guard let session = try? await client.auth.session else {
            throw SupabaseServiceError.notAuthenticated
        }
        // Lowercased: the storage RLS policy compares the folder against
        // auth.uid()::text (lowercase), but Swift's uuidString is uppercase.
        return "\(session.user.id.uuidString.lowercased())/\(identifier).jpg"
    }
}
