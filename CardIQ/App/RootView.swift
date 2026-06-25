import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        TabView(selection: $state.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView()
            }
            Tab("Scan", systemImage: "viewfinder", value: AppTab.scan) {
                ScanLaunchView()
            }
            Tab("Collection", systemImage: "square.stack.3d.up.fill", value: AppTab.collection) {
                CollectionView()
            }
            Tab("Market", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.market) {
                MarketView()
            }
            Tab("Profile", systemImage: "person.fill", value: AppTab.profile) {
                ProfileView()
            }
        }
        .tint(CIQColors.Fallback.accentPrimary)
        #if os(iOS)
        .fullScreenCover(isPresented: $state.showScanner) {
            ScannerFlowView()
        }
        #else
        .sheet(isPresented: $state.showScanner) {
            ScannerFlowView()
        }
        #endif
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
