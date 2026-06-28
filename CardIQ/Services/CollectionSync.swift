import Foundation
import SwiftData

/// Bridges the local SwiftData collection store with the cloud
/// `CollectionRepository`. Local-first: writes hit SwiftData immediately and are
/// mirrored to Supabase in the background; on sign-in the cloud collection is
/// pulled down and merged. No-ops entirely when Supabase isn't configured, so
/// the app behaves exactly as before in mock mode.
@MainActor
enum CollectionSync {
    private static var repo: any CollectionRepository { ServiceContainer.shared.collectionRepository }
    private static var enabled: Bool { SupabaseManager.isConfigured }

    /// Insert locally and mirror to the cloud.
    static func add(_ item: CollectionItem, to context: ModelContext) {
        context.insert(item)
        try? context.save()
        push(item)
    }

    /// Delete locally and mirror the deletion to the cloud.
    static func remove(_ item: CollectionItem, from context: ModelContext) {
        let id = item.itemId
        context.delete(item)
        try? context.save()
        guard enabled else { return }
        Task {
            do { try await repo.delete(id) }
            catch { NSLog("CollectionSync delete failed: \(error)") }
        }
    }

    /// Mirror an item's current state to the cloud (no local insert).
    static func push(_ item: CollectionItem) {
        guard enabled else { return }
        let snapshot = item.detachedCopy()
        Task {
            do { try await repo.save(snapshot) }
            catch { NSLog("CollectionSync push failed: \(error)") }
        }
    }

    /// Pull the signed-in user's cloud collection into the local store,
    /// inserting any items not already present locally (matched by `itemId`).
    /// Runs after sign-in so a fresh device fills up with the existing vault.
    static func pull(into context: ModelContext) async {
        guard enabled else { return }
        guard let remote = try? await repo.fetchAll() else { return }
        let local = (try? context.fetch(FetchDescriptor<CollectionItem>())) ?? []
        let localIds = Set(local.map(\.itemId))
        var inserted = 0
        for item in remote where !localIds.contains(item.itemId) {
            context.insert(item.detachedCopy())
            inserted += 1
        }
        if inserted > 0 { try? context.save() }
    }
}

extension CollectionItem {
    /// A context-free copy, safe to hand to a background task — the live
    /// SwiftData model must not be read off the main actor.
    func detachedCopy() -> CollectionItem {
        let copy = CollectionItem(
            itemId: itemId,
            cardIdentity: cardIdentity,
            purchasePrice: purchasePrice,
            purchaseDate: purchaseDate,
            quantity: quantity,
            notes: notes,
            dateAdded: dateAdded
        )
        copy.gradingReport = gradingReport
        copy.marketSnapshot = marketSnapshot
        copy.frontImageLocalPath = frontImageLocalPath
        copy.backImageLocalPath = backImageLocalPath
        copy.surfaceImageLocalPath = surfaceImageLocalPath
        copy.officialGrade = officialGrade
        copy.officialGradingCompany = officialGradingCompany
        copy.officialCertNumber = officialCertNumber
        copy.officialGradeDate = officialGradeDate
        copy.allowAnonymizedData = allowAnonymizedData
        copy.scanId = scanId
        return copy
    }
}
