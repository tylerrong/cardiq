import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var collectorType: CollectorType? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "collectorType") else { return nil }
            return CollectorType(rawValue: raw)
        }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: "collectorType") }
    }

    /// Whether the app requires a real sign-in. Only true once Supabase is
    /// configured; without credentials the app runs on mocks as before.
    var requiresAuthentication: Bool { SupabaseManager.isConfigured }

    /// In mock mode we're "authenticated" immediately; with Supabase we wait for
    /// the session check before deciding.
    var isAuthenticated: Bool = !SupabaseManager.isConfigured
    /// Set once the launch-time session lookup has finished (avoids flashing the
    /// sign-in screen before we know whether a session exists).
    var authResolved: Bool = false
    var currentUser: AppUser = .free
    var selectedTab: AppTab = .home
    var showScanner: Bool = false

    var preferredGradingCompany: String = UserDefaults.standard.string(forKey: "preferredGradingCompany") ?? "PSA" {
        didSet { UserDefaults.standard.set(preferredGradingCompany, forKey: "preferredGradingCompany") }
    }
    var defaultGradingFee: Double = UserDefaults.standard.object(forKey: "defaultGradingFee") as? Double ?? 25.0 {
        didSet { UserDefaults.standard.set(defaultGradingFee, forKey: "defaultGradingFee") }
    }
    var defaultShippingCost: Double = UserDefaults.standard.object(forKey: "defaultShippingCost") as? Double ?? 15.0 {
        didSet { UserDefaults.standard.set(defaultShippingCost, forKey: "defaultShippingCost") }
    }
    var defaultSellingFee: Double = UserDefaults.standard.object(forKey: "defaultSellingFee") as? Double ?? 13.0 {
        didSet { UserDefaults.standard.set(defaultSellingFee, forKey: "defaultSellingFee") }
    }

    func completeOnboarding(type: CollectorType) {
        collectorType = type
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        hasCompletedOnboarding = true
        CIQHaptics.success()
    }

    func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "collectorType")
        hasCompletedOnboarding = false
    }

    // MARK: - Authentication

    /// Resolves the current session at launch. In mock mode this is a no-op that
    /// marks the user authenticated; with Supabase it restores an existing session.
    func bootstrapAuth() async {
        guard requiresAuthentication else {
            isAuthenticated = true
            authResolved = true
            return
        }
        if let user = await ServiceContainer.shared.auth.currentUser() {
            currentUser = user
            isAuthenticated = true
        }
        authResolved = true
    }

    func didSignIn(_ user: AppUser) {
        currentUser = user
        isAuthenticated = true
    }

    func signOut() async {
        try? await ServiceContainer.shared.auth.signOut()
        currentUser = .free
        isAuthenticated = false
    }

    func deleteAccount() async {
        try? await ServiceContainer.shared.auth.deleteAccount()
        currentUser = .free
        isAuthenticated = false
    }
}

enum AppTab: Int, CaseIterable, Sendable {
    case home
    case collection
    case opportunities
    case profile

    var title: String {
        switch self {
        case .home: "Home"
        case .collection: "Collection"
        case .opportunities: "Opportunities"
        case .profile: "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .collection: "square.stack.3d.up.fill"
        case .opportunities: "scope"
        case .profile: "person.fill"
        }
    }
}
