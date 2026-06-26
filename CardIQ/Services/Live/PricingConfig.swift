import Foundation

/// Configuration for live pricing providers.
///
/// JustTCG (https://justtcg.com) relays TCGplayer prices. Get a free key (format
/// `tcg_...`) at https://justtcg.com → Sign Up → API key, then either:
///   - paste it into `justTCGAPIKey` below (quick, but don't commit a real key), or
///   - set the `JUSTTCG_API_KEY` env var on the Run scheme, or
///   - add a `JustTCGAPIKey` entry to Info.plist (recommended for real builds).
///
/// With no key, the app uses pokemontcg.io's embedded pricing (current behavior).
enum PricingConfig {
    static let justTCGAPIKey: String? = {
        if let env = ProcessInfo.processInfo.environment["JUSTTCG_API_KEY"], !env.isEmpty {
            return env
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "JustTCGAPIKey") as? String, !plist.isEmpty {
            return plist
        }
        // Or paste directly here for a quick local test (replace nil):
        return nil
    }()
}
