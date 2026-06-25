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

    var isAuthenticated: Bool = true
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
}

enum AppTab: Int, CaseIterable, Sendable {
    case home
    case scan
    case collection
    case market
    case profile

    var title: String {
        switch self {
        case .home: "Home"
        case .scan: "Scan"
        case .collection: "Collection"
        case .market: "Market"
        case .profile: "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .scan: "viewfinder"
        case .collection: "square.stack.3d.up.fill"
        case .market: "chart.line.uptrend.xyaxis"
        case .profile: "person.fill"
        }
    }
}
