import Foundation
import Supabase

/// Loaded Supabase credentials. Returns `nil` when the app has not been
/// configured yet (no `Supabase-Info.plist`, or placeholder values), which lets
/// the app fall back to mock services and keep running.
struct SupabaseConfig {
    let url: URL
    let anonKey: String

    static let current: SupabaseConfig? = load()

    private static func load() -> SupabaseConfig? {
        guard
            let plistURL = Bundle.main.url(forResource: "Supabase-Info", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: plistURL) as? [String: Any],
            let urlString = (dict["SUPABASE_URL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            let anonKey = (dict["SUPABASE_ANON_KEY"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !urlString.isEmpty, !anonKey.isEmpty,
            !urlString.hasPrefix("YOUR_"), !anonKey.hasPrefix("YOUR_"),
            let url = URL(string: urlString)
        else {
            return nil
        }
        return SupabaseConfig(url: url, anonKey: anonKey)
    }
}

/// Owns the shared `SupabaseClient` and decides whether live Supabase services
/// or mocks should back the app, based on whether credentials are present.
enum SupabaseManager {
    /// The shared client, or `nil` when the app is not configured for Supabase.
    /// Uses an explicit UserDefaults-backed session store: the default Keychain
    /// store can fail (e.g. unsigned simulator builds with no app-identifier
    /// entitlement), which silently drops the session so later authenticated
    /// calls see no user.
    static let client: SupabaseClient? = {
        guard let config = SupabaseConfig.current else { return nil }
        return SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: config.anonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(storage: UserDefaultsLocalStorage())
            )
        )
    }()

    static var isConfigured: Bool { client != nil }

    // MARK: - Service factories (live when configured, mock otherwise)

    static func makeAuth() -> any AuthenticationService {
        client.map { SupabaseAuthenticationService(client: $0) } ?? MockAuthenticationService()
    }

    static func makeImageStorage() -> any ImageStorageService {
        client.map { SupabaseImageStorageService(client: $0) } ?? MockImageStorageService()
    }

    static func makeCollectionRepository() -> any CollectionRepository {
        client.map { SupabaseCollectionRepository(client: $0) } ?? MockCollectionRepository()
    }

    static func makeScanRepository() -> any ScanRepository {
        client.map { SupabaseScanRepository(client: $0) } ?? MockScanRepository()
    }
}

/// Session storage backed by UserDefaults. Reliable across signed/unsigned
/// builds and simulators where the default Keychain store may be unavailable.
struct UserDefaultsLocalStorage: AuthLocalStorage {
    private let defaults = UserDefaults.standard

    func store(key: String, value: Data) throws { defaults.set(value, forKey: key) }
    func retrieve(key: String) throws -> Data? { defaults.data(forKey: key) }
    func remove(key: String) throws { defaults.removeObject(forKey: key) }
}

/// Errors surfaced by the live Supabase service implementations.
enum SupabaseServiceError: LocalizedError {
    case notAuthenticated
    case appleSignInFailed
    case missingIdentityToken
    case emailConfirmationRequired

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "You need to be signed in to do that."
        case .appleSignInFailed: "Sign in with Apple did not complete."
        case .missingIdentityToken: "Apple did not return an identity token."
        case .emailConfirmationRequired: "Account created. Check your email to confirm, then sign in."
        }
    }
}
