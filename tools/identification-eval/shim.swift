import Foundation

// Minimal protocol shim so the real service file compiles standalone.
protocol CardIdentificationService {
    func identify(frontImage: Data, backImage: Data?) async throws -> [CardIdentity]
    func search(query: String) async throws -> [CardIdentity]
    func allCards() async -> [CardIdentity]
}
