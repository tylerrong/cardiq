import Foundation
import Supabase
import AuthenticationServices
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

/// Live `AuthenticationService` backed by Supabase Auth. Runs the native
/// Sign in with Apple flow, exchanges the Apple identity token for a Supabase
/// session, and mirrors a `profiles` row into the app's `AppUser`.
final class SupabaseAuthenticationService: AuthenticationService {
    private let client: SupabaseClient
    private let profilesTable = "profiles"

    init(client: SupabaseClient) {
        self.client = client
    }

    func signInWithApple() async throws -> AppUser {
        let rawNonce = Self.randomNonceString()
        let hashedNonce = Self.sha256(rawNonce)

        let coordinator = await AppleSignInCoordinator()
        let credential = try await coordinator.requestAuthorization(hashedNonce: hashedNonce)

        guard
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw SupabaseServiceError.missingIdentityToken
        }

        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: rawNonce)
        )

        let appleName = credential.fullName.flatMap { name in
            [name.givenName, name.familyName].compactMap { $0 }.joined(separator: " ")
        }
        return try await ensureProfile(for: session.user, appleName: appleName)
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        let session = try await client.auth.signIn(email: email, password: password)
        return try await ensureProfile(for: session.user, appleName: nil)
    }

    func signUp(email: String, password: String) async throws -> AppUser {
        let response = try await client.auth.signUp(email: email, password: password)
        // When "Confirm email" is enabled in Supabase, there is no session yet —
        // the user must verify via email before a profile can be created (RLS).
        guard let session = response.session else {
            throw SupabaseServiceError.emailConfirmationRequired
        }
        return try await ensureProfile(for: session.user, appleName: nil)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func currentUser() async -> AppUser? {
        // Awaited session reliably restores a persisted login across launches;
        // the synchronous `currentUser` can be nil even when a session exists.
        guard let session = try? await client.auth.session else { return nil }
        return try? await ensureProfile(for: session.user, appleName: nil)
    }

    /// Removes the user's profile row and signs out. Deleting the underlying
    /// auth identity requires the service role, so it is handled server-side
    /// (see SUPABASE_SETUP.md) — here we clear app data and end the session.
    func deleteAccount() async throws {
        if let user = client.auth.currentUser {
            try? await client.from(profilesTable).delete().eq("id", value: user.id.uuidString).execute()
        }
        try await client.auth.signOut()
    }

    // MARK: - Profile mapping

    /// The `profiles` row is created server-side by a trigger on `auth.users`
    /// (see supabase/schema.sql), so we only ever read here. If the row isn't
    /// readable yet — e.g. the access token hasn't propagated to PostgREST in the
    /// same instant a fresh sign-up completes — we fall back to a default built
    /// from the auth user, and the real row loads on the next `currentUser()`.
    private func ensureProfile(for user: User, appleName: String?) async throws -> AppUser {
        let userId = user.id.uuidString
        let existing: [ProfileRow]? = try? await client
            .from(profilesTable)
            .select()
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value

        if let row = existing?.first {
            return row.appUser
        }

        return AppUser(
            id: userId,
            name: (appleName?.isEmpty == false ? appleName : nil) ?? "Collector",
            email: user.email ?? "",
            subscriptionTier: .free,
            freeScansRemaining: SubscriptionTier.free.scanLimit,
            preferredGradingCompany: "PSA",
            defaultSellingFeePercentage: 13,
            createdAt: Date()
        )
    }

    // MARK: - Nonce helpers

    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }
            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}

/// Codable mirror of the `profiles` table.
struct ProfileRow: Codable {
    var id: String
    var name: String
    var email: String
    var subscriptionTier: String
    var freeScansRemaining: Int
    var preferredGradingCompany: String
    var defaultSellingFeePercentage: Double
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case subscriptionTier = "subscription_tier"
        case freeScansRemaining = "free_scans_remaining"
        case preferredGradingCompany = "preferred_grading_company"
        case defaultSellingFeePercentage = "default_selling_fee_percentage"
        case createdAt = "created_at"
    }

    var appUser: AppUser {
        AppUser(
            id: id,
            name: name,
            email: email,
            subscriptionTier: SubscriptionTier(rawValue: subscriptionTier) ?? .free,
            freeScansRemaining: freeScansRemaining,
            preferredGradingCompany: preferredGradingCompany,
            defaultSellingFeePercentage: defaultSellingFeePercentage,
            createdAt: createdAt
        )
    }
}

/// Bridges the delegate-based Sign in with Apple flow into async/await.
@MainActor
private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    func requestAuthorization(hashedNonce: String) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation?.resume(returning: credential)
        } else {
            continuation?.resume(throwing: SupabaseServiceError.appleSignInFailed)
        }
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if canImport(UIKit)
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        return window ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
