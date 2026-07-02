import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HomeViewModel()

    // Universal card search — the market front door. Searches the full local
    // catalog (EN + JP) as you type; results open the card's market page.
    @State private var searchText = ""
    @State private var searchResults: [CardIdentity] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    private var searchActive: Bool { searchFocused || !searchText.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CIQSpacing.xl) {
                    if !searchActive {
                        headerSection
                    }
                    searchBar
                    if searchActive {
                        searchResultsSection
                    } else {
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
                    }
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, CIQSpacing.md)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(CIQColors.Fallback.backgroundPrimary)
            .navigationTitle("CardIQ")
            .ciqNavigationBarStyle()
            .navigationDestination(for: CardIdentity.self) { card in
                MarketDetailView(card: card)
            }
            .animation(.easeInOut(duration: 0.2), value: searchActive)
        }
        .task {
            viewModel.collectorType = appState.collectorType
            await viewModel.load(modelContext: modelContext)
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: CIQSpacing.sm) {
            HStack(spacing: CIQSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
                TextField("Search any card — name, set, or number", text: $searchText)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(CIQColors.Fallback.textTertiary)
                    }
                }
            }
            .padding(.horizontal, CIQSpacing.sm)
            .padding(.vertical, CIQSpacing.xs + 2)
            .background(CIQColors.Fallback.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: CIQRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CIQRadius.md)
                    .strokeBorder(
                        searchFocused ? CIQColors.Fallback.accentPrimary.opacity(0.4) : CIQColors.Fallback.borderSubtle,
                        lineWidth: 1
                    )
            )

            if searchActive {
                Button("Cancel") {
                    searchText = ""
                    searchResults = []
                    searchFocused = false
                }
                .font(CIQFont.subheadline)
                .foregroundStyle(CIQColors.Fallback.accentPrimary)
            }
        }
        .onChange(of: searchText) { _, query in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(200))
                if Task.isCancelled { return }
                guard query.count >= 2 else {
                    searchResults = []
                    return
                }
                isSearching = true
                searchResults = (try? await ServiceContainer.shared.cardIdentification.search(query: query)) ?? []
                isSearching = false
                CIQImageCache.shared.prefetchThumbnails(for: searchResults)
            }
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            if searchText.count < 2 {
                searchHint(icon: "sparkle.magnifyingglass",
                           title: "Search the whole market",
                           subtitle: "Every English and Japanese card — try a name, set, or collector number like 4/102.")
            } else if isSearching && searchResults.isEmpty {
                HStack(spacing: CIQSpacing.sm) {
                    ProgressView().controlSize(.small)
                    Text("Searching...")
                        .font(CIQFont.footnote)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, CIQSpacing.xl)
            } else if searchResults.isEmpty {
                searchHint(icon: "magnifyingglass",
                           title: "No cards found",
                           subtitle: "Nothing matches \"\(searchText)\". Check the spelling or try the set name.")
            } else {
                ForEach(searchResults) { card in
                    NavigationLink(value: card) {
                        MarketCardRow(card: card)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func searchHint(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: CIQSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(CIQColors.Fallback.textTertiary)
            Text(title)
                .font(CIQFont.headline)
                .foregroundStyle(CIQColors.Fallback.textPrimary)
            Text(subtitle)
                .font(CIQFont.footnote)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, CIQSpacing.xxl)
        .padding(.horizontal, CIQSpacing.xl)
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

    /// Compact scan banner — the tab bar's center button is the primary scan
    /// CTA now, so this is a slim secondary entry point with the explainer.
    private var scanHero: some View {
        Button {
            CIQHaptics.tap()
            appState.showScanner = true
        } label: {
            HStack(spacing: CIQSpacing.md) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .background(CIQColors.Fallback.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan & Grade")
                        .font(CIQFont.headline)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                    Text("Identify condition, value, and grading upside.")
                        .font(CIQFont.footnote)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
            }
            .padding(CIQSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: CIQRadius.lg)
                    .fill(CIQColors.Fallback.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: CIQRadius.lg)
                            .strokeBorder(CIQColors.Fallback.accentPrimary.opacity(0.25), lineWidth: 1)
                    )
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
                    ForEach(viewModel.recommendedForGrading) { candidate in
                        NavigationLink(value: candidate.card) {
                            GradingOpportunityCard(card: candidate.card, report: candidate.report)
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
                NavigationLink {
                    ScanHistoryView()
                } label: {
                    Text("See All")
                        .font(CIQFont.subheadline)
                        .foregroundStyle(CIQColors.Fallback.accentPrimary)
                }
            }
            ForEach(viewModel.recentScans.prefix(3)) { recent in
                NavigationLink(value: recent.card) {
                    RecentScanRow(card: recent.card, report: recent.report)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Grading Opportunity Card

struct GradingOpportunityCard: View {
    let card: CardIdentity
    let report: GradingReport
    @State private var market: MarketSnapshot?

    private var upside: Double {
        guard let m = market else { return 0 }
        return (report.psa10Probability * m.psa10EstimatedValue + report.psa9Probability * m.psa9EstimatedValue) - m.rawEstimatedValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.xs) {
            CardArtworkView(card: card, gradeBadge: gradeText, recommendationBadge: .grade, size: .large)

            Text(card.name)
                .font(CIQFont.footnoteBold)
                .foregroundStyle(CIQColors.Fallback.textPrimary)
                .lineLimit(1)

            Text("Likely \(report.gradeDescriptor)")
                .font(CIQFont.caption)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
            Text("\(Int(report.psa10Probability * 100))% PSA 10")
                .font(CIQFont.captionBold)
                .foregroundStyle(CIQColors.Fallback.accentPrimary)

            if upside > 0 {
                Text("+\(upside.currencyFormatted) upside")
                    .font(CIQFont.captionBold)
                    .foregroundStyle(CIQColors.Fallback.positive)
            }
        }
        .frame(width: 150)
        .task {
            market = await MarketSnapshotCache.shared.snapshot(for: card.id)
        }
    }

    private var gradeText: String? {
        String(format: "%.1f", report.estimatedGrade)
    }
}

// MARK: - Recent Scan Row

struct RecentScanRow: View {
    let card: CardIdentity
    var report: GradingReport?

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
