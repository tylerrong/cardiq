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
                case .collection: CollectionView()
                case .opportunities: OpportunitiesView()
                case .profile: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CIQTabBar(selectedTab: $state.selectedTab, onScan: { state.showScanner = true })
        }
        .overlay(alignment: .bottomTrailing) {
            AskCardIQButton { showChat = true }
                .padding(.trailing, CIQSpacing.lg)
                .padding(.bottom, 104)
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
    let onScan: () -> Void

    private let leftTabs: [AppTab] = [.home, .collection]
    private let rightTabs: [AppTab] = [.opportunities, .profile]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(leftTabs, id: \.self) { tabButton($0) }
            scanButton
            ForEach(rightTabs, id: \.self) { tabButton($0) }
        }
        .padding(.horizontal, CIQSpacing.sm)
        .padding(.top, CIQSpacing.xs)
        .padding(.bottom, CIQSpacing.xxs)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CIQRadius.xl, style: .continuous)
                .strokeBorder(CIQColors.Fallback.borderSubtle.opacity(0.5), lineWidth: 0.5)
        )
        .padding(.horizontal, CIQSpacing.md)
        .padding(.bottom, CIQSpacing.xs)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            CIQHaptics.select()
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? CIQColors.Fallback.accentPrimary : CIQColors.Fallback.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(tab.title)
    }

    private var scanButton: some View {
        Button {
            CIQHaptics.tap()
            onScan()
        } label: {
            ZStack {
                Circle()
                    .fill(CIQColors.Fallback.accentPrimary)
                    .frame(width: 52, height: 52)
                    .shadow(color: CIQColors.Fallback.accentPrimary.opacity(0.4), radius: 8, y: 2)
                Image(systemName: "viewfinder")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.black)
            }
        }
        .frame(width: 72)
        .accessibilityLabel("Scan a card")
    }
}

/// Compact floating action button for the market chat assistant.
struct AskCardIQButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            CIQHaptics.tap()
            action()
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(CIQColors.Fallback.accentPrimary)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Ask CardIQ")
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
