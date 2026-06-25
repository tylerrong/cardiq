import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CIQSpacing.xl) {
                    greetingSection
                    portfolioSummary
                    scanButton
                    scansRemainingBanner
                    if !viewModel.recommendedForGrading.isEmpty {
                        recommendedSection
                    }
                    if !viewModel.recentScans.isEmpty {
                        recentScansSection
                    }
                    if !viewModel.biggestMovers.isEmpty {
                        moversSection
                    }
                }
                .padding(CIQSpacing.md)
            }
            .background(CIQColors.Fallback.backgroundPrimary)
            .navigationTitle("CardIQ")
            .ciqNavigationBarStyle()
            .navigationDestination(for: CardIdentity.self) { card in
                MarketDetailView(card: card)
            }
        }
        .task {
            viewModel.collectorType = appState.collectorType
            await viewModel.load(modelContext: modelContext)
        }
    }

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.xxs) {
            Text(viewModel.greeting)
                .font(CIQFont.displayMedium)
                .foregroundStyle(CIQColors.Fallback.textPrimary)
            Text(viewModel.dashboardSubtitle)
                .font(CIQFont.subheadline)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
        }
    }

    private var portfolioSummary: some View {
        CIQCard {
            VStack(spacing: CIQSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: CIQSpacing.xxs) {
                        Text("Collection Value")
                            .font(CIQFont.footnote)
                            .foregroundStyle(CIQColors.Fallback.textSecondary)
                        Text(viewModel.totalValue.currencyFormatted)
                            .font(CIQFont.heroValue)
                            .foregroundStyle(CIQColors.Fallback.textPrimary)
                    }
                    Spacer()
                }

                HStack(spacing: CIQSpacing.xl) {
                    PortfolioMetric(label: "Invested", value: viewModel.totalInvested.currencyFormatted)
                    PortfolioMetric(
                        label: "Unrealized P&L",
                        value: viewModel.unrealizedGainLoss.signedCurrencyFormatted,
                        valueColor: viewModel.unrealizedGainLoss >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative
                    )
                }
            }
        }
    }

    private var scanButton: some View {
        CIQPrimaryButton("Scan a Card", icon: "viewfinder") {
            appState.showScanner = true
        }
    }

    private var scansRemainingBanner: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(CIQColors.Fallback.accentPrimary)
            Text("\(viewModel.freeScansRemaining) free scans remaining this month")
                .font(CIQFont.footnote)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
            Spacer()
            if viewModel.freeScansRemaining <= 1 {
                Text("Upgrade")
                    .font(CIQFont.footnoteBold)
                    .foregroundStyle(CIQColors.Fallback.accentPrimary)
            }
        }
        .padding(CIQSpacing.sm)
        .background(CIQColors.Fallback.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            CIQSectionHeader("Recommended for Grading")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CIQSpacing.sm) {
                    ForEach(viewModel.recommendedForGrading) { card in
                        NavigationLink(value: card) {
                            RecommendedCardCell(card: card)
                        }
                    }
                }
            }
        }
    }

    private var recentScansSection: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            CIQSectionHeader("Recent Scans") {
                appState.selectedTab = .scan
            }
            ForEach(viewModel.recentScans) { scan in
                NavigationLink(value: scan) {
                    RecentScanRow(card: scan)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var moversSection: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            CIQSectionHeader("Biggest Movers")
            ForEach(viewModel.biggestMovers) { mover in
                NavigationLink(value: mover.card) {
                    MoverRow(mover: mover)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PortfolioMetric: View {
    let label: String
    let value: String
    var valueColor: Color = CIQColors.Fallback.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
            Text(label)
                .font(CIQFont.caption)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
            Text(value)
                .font(CIQFont.bodyBold)
                .foregroundStyle(valueColor)
        }
    }
}

struct RecommendedCardCell: View {
    let card: CardIdentity

    var body: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.xs) {
            RoundedRectangle(cornerRadius: CIQRadius.sm)
                .fill(CIQColors.Fallback.backgroundTertiary)
                .frame(width: 120, height: 168)
                .overlay {
                    VStack(spacing: CIQSpacing.xxs) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 28))
                            .foregroundStyle(CIQColors.Fallback.accentPrimary)
                        Text(card.name)
                            .font(CIQFont.caption)
                            .foregroundStyle(CIQColors.Fallback.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(CIQSpacing.xs)
                }

            Text(card.name)
                .font(CIQFont.footnoteBold)
                .foregroundStyle(CIQColors.Fallback.textPrimary)
                .lineLimit(1)

            Text(card.setName)
                .font(CIQFont.caption)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 120)
    }
}

struct RecentScanRow: View {
    let card: CardIdentity

    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            RoundedRectangle(cornerRadius: CIQRadius.sm)
                .fill(CIQColors.Fallback.backgroundTertiary)
                .frame(width: 48, height: 66)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                }

            VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                Text(card.name)
                    .font(CIQFont.bodyBold)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                Text("\(card.setName) · \(card.displayNumber)")
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(CIQFont.caption)
                .foregroundStyle(CIQColors.Fallback.textTertiary)
        }
        .padding(CIQSpacing.sm)
        .background(CIQColors.Fallback.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))
    }
}

struct MoverRow: View {
    let mover: HomeMover

    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                Text(mover.card.name)
                    .font(CIQFont.bodyBold)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                Text(mover.card.setName)
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: CIQSpacing.xxxs) {
                Text(mover.currentValue.currencyFormatted)
                    .font(CIQFont.bodyBold)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                Text(mover.changeFormatted)
                    .font(CIQFont.captionBold)
                    .foregroundStyle(mover.change >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative)
            }
        }
        .padding(CIQSpacing.sm)
        .background(CIQColors.Fallback.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))
    }
}

extension Double {
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }

    var signedCurrencyFormatted: String {
        let formatted = abs(self).currencyFormatted
        if self >= 0 { return "+\(formatted)" }
        return "-\(formatted)"
    }

    var percentFormatted: String {
        String(format: "%.1f%%", self)
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
