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
                    heroSection
                    scanButton
                    if !viewModel.recommendedForGrading.isEmpty {
                        recommendedSection
                    }
                    if !viewModel.biggestMovers.isEmpty {
                        moversSection
                    }
                    if !viewModel.recentScans.isEmpty {
                        recentScansSection
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

    // MARK: - Hero portfolio card with gradient accent

    private var heroSection: some View {
        VStack(spacing: 0) {
            VStack(spacing: CIQSpacing.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: CIQSpacing.xxs) {
                        Text(viewModel.greeting)
                            .font(CIQFont.title)
                            .foregroundStyle(CIQColors.Fallback.textSecondary)
                        Text("Collection Value")
                            .font(CIQFont.footnote)
                            .foregroundStyle(CIQColors.Fallback.textTertiary)
                    }
                    Spacer()
                    scansChip
                }

                AnimatedCounterText(value: viewModel.totalValue, format: .currency)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: CIQSpacing.xxl) {
                    metricPill(
                        label: "Invested",
                        value: viewModel.totalInvested.currencyFormatted,
                        icon: "arrow.down.circle.fill",
                        color: CIQColors.Fallback.textSecondary
                    )
                    metricPill(
                        label: "P&L",
                        value: viewModel.unrealizedGainLoss.signedCurrencyFormatted,
                        icon: viewModel.unrealizedGainLoss >= 0 ? "arrow.up.right" : "arrow.down.right",
                        color: viewModel.unrealizedGainLoss >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative
                    )
                    if viewModel.unrealizedGainLoss != 0 && viewModel.totalInvested > 0 {
                        metricPill(
                            label: "Return",
                            value: ((viewModel.unrealizedGainLoss / viewModel.totalInvested) * 100).percentFormatted,
                            icon: "percent",
                            color: viewModel.unrealizedGainLoss >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative
                        )
                    }
                }
            }
            .padding(CIQSpacing.lg)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: CIQRadius.xxl)
                        .fill(CIQColors.Fallback.backgroundCard)
                    RoundedRectangle(cornerRadius: CIQRadius.xxl)
                        .fill(
                            LinearGradient(
                                colors: [
                                    CIQColors.Fallback.accentPrimary.opacity(0.12),
                                    CIQColors.Fallback.accentPrimary.opacity(0.03),
                                    .clear,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: CIQRadius.xxl)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    CIQColors.Fallback.accentPrimary.opacity(0.4),
                                    CIQColors.Fallback.accentPrimary.opacity(0.1),
                                    CIQColors.Fallback.borderSubtle,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
        }
    }

    private var scansChip: some View {
        HStack(spacing: CIQSpacing.xxs) {
            Image(systemName: "sparkles")
                .font(.system(size: 11))
            Text("\(viewModel.freeScansRemaining) scans")
                .font(CIQFont.captionBold)
        }
        .foregroundStyle(CIQColors.Fallback.accentPrimary)
        .padding(.horizontal, CIQSpacing.sm)
        .padding(.vertical, CIQSpacing.xxs)
        .background(CIQColors.Fallback.accentPrimary.opacity(0.12))
        .clipShape(Capsule())
    }

    private func metricPill(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
            Text(label)
                .font(CIQFont.caption)
                .foregroundStyle(CIQColors.Fallback.textTertiary)
            HStack(spacing: CIQSpacing.xxxs) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                Text(value)
                    .font(CIQFont.footnoteBold)
                    .foregroundStyle(color)
            }
        }
    }

    // MARK: - Scan button with glow

    private var scanButton: some View {
        Button {
            CIQHaptics.tap()
            appState.showScanner = true
        } label: {
            HStack(spacing: CIQSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(CIQColors.Fallback.accentPrimary.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "viewfinder")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)
                }
                VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                    Text("Scan a Card")
                        .font(CIQFont.headline)
                        .foregroundStyle(.black)
                    Text("Get instant grading & ROI analysis")
                        .font(CIQFont.caption)
                        .foregroundStyle(.black.opacity(0.6))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.5))
            }
            .padding(CIQSpacing.md)
            .background(CIQColors.Fallback.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: CIQRadius.lg))
            .shadow(color: CIQColors.Fallback.accentPrimary.opacity(0.35), radius: 16, x: 0, y: 6)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Recommended for grading — richer cards

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

    // MARK: - Movers with inline change indicators

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

    // MARK: - Recent scans

    private var recentScansSection: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            CIQSectionHeader("Recent Scans") {
                appState.selectedTab = .scan
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

// MARK: - Recommended Card Cell

struct RecommendedCardCell: View {
    let card: CardIdentity
    @State private var market: MarketSnapshot?

    private var rarityGradient: LinearGradient {
        switch card.rarity {
        case .specialArt, .specialIllustrationRare, .hyperRare:
            LinearGradient(colors: [
                CIQColors.Fallback.accentPrimary.opacity(0.25),
                CIQColors.Fallback.accentPrimary.opacity(0.05),
            ], startPoint: .top, endPoint: .bottom)
        case .fullArt, .altArt, .illustrationRare:
            LinearGradient(colors: [
                Color.purple.opacity(0.2),
                Color.purple.opacity(0.05),
            ], startPoint: .top, endPoint: .bottom)
        case .ultraRare, .secretRare:
            LinearGradient(colors: [
                CIQColors.Fallback.warning.opacity(0.2),
                CIQColors.Fallback.warning.opacity(0.05),
            ], startPoint: .top, endPoint: .bottom)
        default:
            LinearGradient(colors: [
                CIQColors.Fallback.backgroundTertiary,
                CIQColors.Fallback.backgroundTertiary,
            ], startPoint: .top, endPoint: .bottom)
        }
    }

    private var rarityAccent: Color {
        switch card.rarity {
        case .specialArt, .specialIllustrationRare, .hyperRare: CIQColors.Fallback.accentPrimary
        case .fullArt, .altArt, .illustrationRare: .purple
        case .ultraRare, .secretRare: CIQColors.Fallback.warning
        default: CIQColors.Fallback.textTertiary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.xs) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: CIQRadius.card)
                    .fill(rarityGradient)
                    .frame(width: 150, height: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: CIQRadius.card)
                            .strokeBorder(rarityAccent.opacity(0.3), lineWidth: 1)
                    )
                    .overlay {
                        VStack(spacing: CIQSpacing.sm) {
                            Image(systemName: card.isHolo ? "sparkles" : "star.fill")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(rarityAccent)

                            Text(card.name)
                                .font(CIQFont.footnoteBold)
                                .foregroundStyle(CIQColors.Fallback.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)

                            if let market {
                                Text(market.rawEstimatedValue.currencyFormatted)
                                    .font(CIQFont.bodyBold)
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(CIQSpacing.sm)
                    }

                CIQBadge(text: "GRADE", color: CIQColors.Fallback.accentPrimary)
                    .padding(CIQSpacing.xs)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(card.rarity.displayName)
                    .font(CIQFont.caption)
                    .foregroundStyle(rarityAccent)
                Text(card.setName)
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(width: 150)
        .task {
            market = MockSeedData.marketSnapshot(for: card.id)
        }
    }
}

// MARK: - Recent Scan Row

struct RecentScanRow: View {
    let card: CardIdentity
    @State private var report: GradingReport?

    private var gradeColor: Color {
        guard let g = report?.estimatedGrade else { return CIQColors.Fallback.textTertiary }
        switch g {
        case 9.5...10: return CIQColors.Fallback.accentPrimary
        case 8.5..<9.5: return CIQColors.Fallback.positive
        case 7..<8.5: return CIQColors.Fallback.warning
        default: return CIQColors.Fallback.negative
        }
    }

    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: CIQRadius.sm)
                    .fill(gradeColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                if let grade = report?.estimatedGrade {
                    Text(String(format: "%.1f", grade))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(gradeColor)
                } else {
                    Image(systemName: "viewfinder")
                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                }
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

            if let report {
                CIQBadge(
                    text: report.gradeDescriptor,
                    color: gradeColor
                )
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(CIQColors.Fallback.textTertiary)
        }
        .padding(CIQSpacing.sm)
        .background(CIQColors.Fallback.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: CIQRadius.card)
                .strokeBorder(CIQColors.Fallback.borderSubtle, lineWidth: 0.5)
        )
        .task {
            report = MockSeedData.gradingReport(for: card.id)
        }
    }
}

// MARK: - Mover Row with change bar

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
                HStack(spacing: CIQSpacing.xxxs) {
                    Image(systemName: mover.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(mover.changeFormatted)
                        .font(CIQFont.captionBold)
                }
                .foregroundStyle(changeColor)
            }
        }
        .padding(.vertical, CIQSpacing.sm)
        .padding(.horizontal, CIQSpacing.md)
        .background(CIQColors.Fallback.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: CIQRadius.card)
                .strokeBorder(CIQColors.Fallback.borderSubtle, lineWidth: 0.5)
        )
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
