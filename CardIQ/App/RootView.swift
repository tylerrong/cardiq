import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if appState.requiresAuthentication && !appState.authResolved {
                AuthLoadingView()
            } else if appState.requiresAuthentication && !appState.isAuthenticated {
                LoginView()
            } else if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .task { await appState.bootstrapAuth() }
        .task(id: appState.isAuthenticated) {
            // Pull the cloud collection once a session is active (launch restore
            // or fresh sign-in). No-ops when Supabase isn't configured.
            if appState.isAuthenticated {
                await CollectionSync.pull(into: modelContext)
            }
        }
    }
}

/// Brief splash shown while the launch-time Supabase session lookup runs.
struct AuthLoadingView: View {
    var body: some View {
        ZStack {
            CIQColors.Fallback.backgroundPrimary.ignoresSafeArea()
            ProgressView()
                .controlSize(.large)
                .tint(CIQColors.Fallback.accentPrimary)
        }
    }
}

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var showChat = false

    var body: some View {
        @Bindable var state = appState
        ZStack(alignment: .bottom) {
            Group {
                switch appState.selectedTab {
                case .home: HomeView()
                case .scan: ScanLaunchView()
                case .collection: CollectionView()
                case .market: MarketView()
                case .profile: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CIQTabBar(selectedTab: $state.selectedTab, onAskCardIQ: { showChat = true })
        }
        .ignoresSafeArea(.keyboard)
        #if os(iOS)
        .fullScreenCover(isPresented: $state.showScanner) {
            ScannerFlowView()
        }
        #else
        .sheet(isPresented: $state.showScanner) {
            ScannerFlowView()
        }
        #endif
        .sheet(isPresented: $showChat) {
            MarketChatView()
        }
    }
}

struct CIQTabBar: View {
    @Binding var selectedTab: AppTab
    let onAskCardIQ: () -> Void

    private let navTabs: [AppTab] = [.home, .scan, .collection, .market, .profile]

    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            HStack(spacing: 0) {
                ForEach(navTabs, id: \.self) { tab in
                    Button {
                        CIQHaptics.select()
                        selectedTab = tab
                    } label: {
                        Image(systemName: tabIcon(tab))
                            .font(.system(size: 18, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? CIQColors.Fallback.textPrimary : CIQColors.Fallback.textTertiary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(tab.title)
                }
            }
            .padding(.horizontal, CIQSpacing.xs)
            .padding(.vertical, CIQSpacing.xxs)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(CIQColors.Fallback.borderSubtle.opacity(0.5), lineWidth: 0.5)
            )

            Button {
                CIQHaptics.tap()
                onAskCardIQ()
            } label: {
                HStack(spacing: CIQSpacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Ask CardIQ")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, CIQSpacing.lg)
                .frame(minHeight: 48)
                .background(CIQColors.Fallback.accentPrimary)
                .clipShape(Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Ask CardIQ")
        }
        .padding(.horizontal, CIQSpacing.md)
        .padding(.bottom, CIQSpacing.xs)
    }

    private func tabIcon(_ tab: AppTab) -> String {
        switch tab {
        case .home: "chart.line.uptrend.xyaxis"
        case .scan: "viewfinder"
        case .collection: "square.stack.3d.up.fill"
        case .market: "tag"
        case .profile: "person"
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
