import SwiftUI
import SwiftData

@main
struct CardIQApp: App {
    @State private var appState = AppState()
    private let services = ServiceContainer.shared

    init() {
        // Generous shared cache so card art (static pokemontcg.io images) loads once
        // and persists across launches — no re-downloads or flicker when scrolling
        // large card grids, now that every card carries a real image.
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,    // 50 MB in memory
            diskCapacity: 500 * 1024 * 1024      // 500 MB on disk
        )
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([CollectionItem.self, ScanRecord.self, WatchlistItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
