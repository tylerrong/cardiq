import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CIQSpacing.xl) {
                    headerSection
                    scanHero
                    portfolioStrip
                    if !viewModel.recommendedForGrading.isEmpty {
                        gradingOpportunities
                    }
                    if !viewModel.biggestMovers.isEmpty {
                        moversSection
                    }
                    if !viewModel.recentScans.isEmpty {
                        recentScansSection
                    }
                    Color.clear.frame(height: CIQSpacing.xxl)
                }
                .padding(.horizontal, CIQSpacing.md)
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

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                Text(viewModel.greeting)
                    .font(CIQFont.title)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                if viewModel.unrealizedGainLoss != 0 {
                    Text("Your collection is \(viewModel.unrealizedGainLoss >= 0 ? "up" : "down") \(abs(viewModel.unrealizedGainLoss).currencyFormatted).")
                        .font(CIQFont.subheadline)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                }
            }
            Spacer()
            HStack(spacing: CIQSpacing.xxxs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                Text("\(viewModel.freeScansRemaining) scans")
                    .font(CIQFont.captionBold)
            }
            .foregroundStyle(CIQColors.Fallback.accentPrimary)
            .padding(.horizontal, CIQSpacing.sm)
            .padding(.vertical, CIQSpacing.xxs)
            .background(CIQColors.Fallback.accentPrimary.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    private var scanHero: some View {
        Button {
            CIQHaptics.tap()
            appState.showScanner = true
        } label: {
            HStack(spacing: CIQSpacing.md) {
                VStack(alignment: .leading, spacing: CIQSpacing.xs) {
                    Text("Scan & Grade")
                        .font(CIQFont.title)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                    Text("Identify condition, value, and grading upside.")
                        .font(CIQFont.footnote)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                        .lineLimit(2)

                    HStack(spacing: CIQSpacing.xs) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Start Scan")
                            .font(CIQFont.footnoteBold)
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, CIQSpacing.md)
                    .padding(.vertical, CIQSpacing.xs)
                    .background(CIQColors.Fallback.accentPrimary)
                    .clipShape(Capsule())
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: CIQRadius.sm)
                        .strokeBorder(CIQColors.Fallback.accentPrimary.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(width: 56, height: 78)

                    Image(systemName: "viewfinder")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(CIQColors.Fallback.accentPrimary.opacity(0.5))
                }
            }
            .padding(CIQSpacing.lg)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: CIQRadius.xl)
                        .fill(CIQColors.Fallback.backgroundCard)
                    RoundedRectangle(cornerRadius: CIQRadius.xl)
                        .fill(
                            LinearGradient(
                                colors: [CIQColors.Fallback.accentPrimary.opacity(0.08), .clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: CIQRadius.xl)
                        .strokeBorder(
                            LinearGradient(
                                colors: [CIQColors.Fallback.accentPrimary.opacity(0.3), CIQColors.Fallback.borderSubtle],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ), lineWidth: 1
                        )
                }
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var portfolioStrip: some View {
        HStack(spacing: CIQSpacing.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Collection")
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
                AnimatedCounterText(value: viewModel.totalValue, format: .currency)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Invested")
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
                Text(viewModel.totalInvested.currencyFormatted)
                    .font(CIQFont.bodyBold)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text("Return")
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
                HStack(spacing: CIQSpacing.xxxs) {
                    let pct = viewModel.totalInvested > 0 ? ((viewModel.unrealizedGainLoss / viewModel.totalInvested) * 100) : 0
                    Image(systemName: viewModel.unrealizedGainLoss >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(pct.percentFormatted)
                        .font(CIQFont.bodyBold)
                }
                .foregroundStyle(viewModel.unrealizedGainLoss >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative)
            }
        }
        .padding(.vertical, CIQSpacing.sm)
        .padding(.horizontal, CIQSpacing.md)
        .background(CIQColors.Fallback.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CIQRadius.md)
                .strokeBorder(CIQColors.Fallback.borderSubtle, lineWidth: 0.5)
        )
    }

    private var gradingOpportunities: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Grading Opportunities")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                    Text("\(viewModel.recommendedForGrading.count) cards with upside")
                        .font(CIQFont.caption)
                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                }
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CIQSpacing.sm) {
                    ForEach(viewModel.recommendedForGrading) { card in
                        NavigationLink(value: card) {
                            GradingOpportunityCard(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var moversSection: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            Text("Biggest Movers")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(CIQColors.Fallback.textPrimary)
            ForEach(viewModel.biggestMovers) { mover in
                NavigationLink(value: mover.card) {
                    MoverRow(mover: mover)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recentScansSection: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            HStack {
                Text("Recent Scans")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                Spacer()
                Button("See All") { appState.selectedTab = .scan }
                    .font(CIQFont.subheadline)
                    .foregroundStyle(CIQColors.Fallback.accentPrimary)
            }
            ForEach(viewModel.recentScans.prefix(3)) { scan in
                NavigationLink(value: scan) {
                    RecentScanRow(card: scan)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Grading Opportunity Card

struct GradingOpportunityCard: View {
    let card: CardIdentity
    @State private var report: GradingReport?
    @State private var market: MarketSnapshot?

    private var upside: Double {
        guard let r = report, let m = market else { return 0 }
        return (r.psa10Probability * m.psa10EstimatedValue + r.psa9Probability * m.psa9EstimatedValue) - m.rawEstimatedValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.xs) {
            CardArtworkView(card: card, gradeBadge: gradeText, recommendationBadge: .grade, size: .large)

            Text(card.name)
                .font(CIQFont.footnoteBold)
                .foregroundStyle(CIQColors.Fallback.textPrimary)
                .lineLimit(1)

            if let report {
                Text("Likely \(report.gradeDescriptor)")
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                Text("\(Int(report.psa10Probability * 100))% PSA 10")
                    .font(CIQFont.captionBold)
                    .foregroundStyle(CIQColors.Fallback.accentPrimary)
            }

            if upside > 0 {
                Text("+\(upside.currencyFormatted) upside")
                    .font(CIQFont.captionBold)
                    .foregroundStyle(CIQColors.Fallback.positive)
            }
        }
        .frame(width: 150)
        .task {
            report = MockSeedData.gradingReport(for: card.id)
            market = MockSeedData.marketSnapshot(for: card.id)
        }
    }

    private var gradeText: String? {
        guard let r = report else { return nil }
        return String(format: "%.1f", r.estimatedGrade)
    }
}

// MARK: - Recent Scan Row

struct RecentScanRow: View {
    let card: CardIdentity
    @State private var report: GradingReport?

    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            CardArtworkView(card: card, size: .small)

            VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                Text(card.name)
                    .font(CIQFont.bodyBold)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                Text("\(card.setName) · \(card.displayNumber)")
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
            }

            Spacer()

            if let report {
                GradeBadge(grade: String(format: "%.1f", report.estimatedGrade))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(CIQColors.Fallback.textTertiary)
        }
        .padding(CIQSpacing.sm)
        .task { report = MockSeedData.gradingReport(for: card.id) }
    }
}

// MARK: - Mover Row

struct MoverRow: View {
    let mover: HomeMover

    private var changeColor: Color {
        mover.change >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative
    }

    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(changeColor)
                .frame(width: 3, height: 36)

            CardArtworkView(card: mover.card, size: .small)

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
                PriceChangeLabel(percentageChange: mover.change)
            }
        }
        .padding(.vertical, CIQSpacing.xs)
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
        .modelContainer(for: CollectionItem.self, inMemory: true)
}
