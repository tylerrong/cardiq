import SwiftUI
import SwiftData

/// The Opportunities tab — what to do with raw cards, and which raw cards are
/// moving. Replaces the generic Market tab: browsing/search lives on Home now,
/// so this screen is entirely action-oriented and rooted in raw cards and
/// their condition.
struct OpportunitiesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CollectionItem.dateAdded, order: .reverse) private var collectionItems: [CollectionItem]
    @Query(sort: \WatchlistItem.dateAdded, order: .reverse) private var watchlistItems: [WatchlistItem]

    @State private var movers: [RawMover] = []
    @State private var moversLoading = true
    @State private var moversFailed = false

    /// Raw (ungraded) cards from the vault with a condition read, ranked by
    /// expected grading profit. The same calculator that powers the ROI screen.
    private var gradingCandidates: [RawGradingCandidate] {
        let calculator = DefaultGradeROICalculator()
        return collectionItems.compactMap { item -> RawGradingCandidate? in
            guard item.officialGrade == nil,
                  let card = item.cardIdentity,
                  let report = item.gradingReport
            else { return nil }
            guard let market = item.marketSnapshot, market.rawEstimatedValue > 0 else {
                // No pricing yet — still a raw card worth showing, without economics.
                return RawGradingCandidate(card: card, report: report, market: nil, roi: nil)
            }
            var input = ROIInput.default
            input.purchasePrice = item.purchasePrice ?? 0
            let roi = calculator.calculate(gradingReport: report, marketSnapshot: market, input: input)
            return RawGradingCandidate(card: card, report: report, market: market, roi: roi)
        }
        .sorted { ($0.roi?.expectedProfit ?? -.infinity) > ($1.roi?.expectedProfit ?? -.infinity) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CIQSpacing.xl) {
                    vaultSection
                    moversSection
                    if !watchlistItems.isEmpty {
                        watchlistSection
                    }
                    Color.clear.frame(height: 80)
                }
                .padding(CIQSpacing.md)
            }
            .background(CIQColors.Fallback.backgroundPrimary)
            .navigationTitle("Opportunities")
            .ciqNavigationBarStyle()
            .navigationDestination(for: CardIdentity.self) { card in
                MarketDetailView(card: card)
            }
            .refreshable {
                await loadMovers()
                await refreshMissingSnapshots()
            }
            .task {
                await loadMovers()
                await refreshMissingSnapshots()
            }
        }
    }

    // MARK: - Your raw cards

    private var vaultSection: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            sectionHeader(
                "Grade From Your Vault",
                subtitle: gradingCandidates.isEmpty
                    ? nil
                    : "Raw cards ranked by expected grading profit"
            )

            if gradingCandidates.isEmpty {
                vaultEmptyState
            } else {
                ForEach(gradingCandidates.prefix(5)) { candidate in
                    if let market = candidate.market, let roi = candidate.roi {
                        NavigationLink {
                            GradeROIView(card: candidate.card, report: candidate.report, market: market)
                        } label: {
                            RawGradingRow(candidate: candidate, roi: roi)
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(value: candidate.card) {
                            RawGradingRow(candidate: candidate, roi: nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var vaultEmptyState: some View {
        VStack(spacing: CIQSpacing.sm) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(CIQColors.Fallback.textTertiary)
            Text("No raw cards analyzed yet")
                .font(CIQFont.headline)
                .foregroundStyle(CIQColors.Fallback.textPrimary)
            Text("Scan a raw card and CardIQ reads its condition, predicts the grade, and shows whether grading pays.")
                .font(CIQFont.footnote)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
                .multilineTextAlignment(.center)
            CIQSecondaryButton("Scan a Card", icon: "viewfinder") {
                appState.showScanner = true
            }
            .fixedSize()
            .padding(.top, CIQSpacing.xxs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CIQSpacing.lg)
        .padding(.horizontal, CIQSpacing.md)
        .background(CIQColors.Fallback.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.md))
    }

    // MARK: - Raw movers

    private var moversSection: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            sectionHeader("Raw Movers", subtitle: "Biggest raw-price swings, 30 days")

            if moversLoading && movers.isEmpty {
                HStack(spacing: CIQSpacing.sm) {
                    ProgressView().controlSize(.small)
                    Text("Checking raw prices...")
                        .font(CIQFont.footnote)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, CIQSpacing.lg)
            } else if movers.isEmpty {
                VStack(spacing: CIQSpacing.xs) {
                    Text("Price data unavailable")
                        .font(CIQFont.footnoteBold)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                    Text("Couldn't reach pricing right now. Pull down to retry.")
                        .font(CIQFont.caption)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CIQSpacing.lg)
                .background(CIQColors.Fallback.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: CIQRadius.md))
            } else {
                ForEach(movers) { mover in
                    NavigationLink(value: mover.card) {
                        RawMoverRow(mover: mover)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Rank recent catalog cards by 30-day raw price movement. Candidates are
    /// the newest sets plus trending — the slice of the market where raw
    /// prices actually move week to week.
    private func loadMovers() async {
        moversLoading = true
        defer { moversLoading = false }

        var candidates = await ServiceContainer.shared.cardIdentification.allCards()
        let trending = (try? await ServiceContainer.shared.marketData.trendingCards()) ?? []
        candidates = Array((trending + candidates).uniqued(by: \.id).prefix(24))
        CIQImageCache.shared.prefetchThumbnails(for: candidates)

        var ranked: [RawMover] = []
        await withTaskGroup(of: RawMover?.self) { group in
            for card in candidates {
                group.addTask { @MainActor in
                    guard let snapshot = await MarketSnapshotCache.shared.snapshot(for: card.id),
                          snapshot.rawEstimatedValue > 0,
                          snapshot.thirtyDayChangePercentage != 0
                    else { return nil }
                    return RawMover(card: card, raw: snapshot.rawEstimatedValue, change: snapshot.thirtyDayChangePercentage)
                }
            }
            for await mover in group {
                if let mover { ranked.append(mover) }
            }
        }
        movers = Array(ranked.sorted { abs($0.change) > abs($1.change) }.prefix(6))
    }

    /// Items saved while pricing was unreachable have no snapshot ("Price
    /// pending") — backfill them whenever this tab loads, and sync the fix.
    private func refreshMissingSnapshots() async {
        var healed = false
        for item in collectionItems where item.marketSnapshot == nil {
            guard let card = item.cardIdentity else { continue }
            if let snapshot = await MarketSnapshotCache.shared.snapshot(for: card.id) {
                item.marketSnapshot = snapshot
                healed = true
            }
        }
        if healed {
            try? modelContext.save()
        }
    }

    // MARK: - Watchlist

    private var watchlistSection: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            sectionHeader("Watchlist", subtitle: nil)
            ForEach(watchlistItems, id: \.cardId) { item in
                if let card = item.cardIdentity {
                    NavigationLink(value: card) {
                        MarketCardRow(card: card)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(CIQColors.Fallback.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
            }
        }
    }
}

// MARK: - Models

struct RawGradingCandidate: Identifiable {
    var id: String { card.id }
    let card: CardIdentity
    let report: GradingReport
    let market: MarketSnapshot?
    let roi: GradeROIResult?
}

struct RawMover: Identifiable {
    var id: String { card.id }
    let card: CardIdentity
    let raw: Double
    let change: Double
}

// MARK: - Rows

/// A raw card from the vault: condition read on the left, grading economics
/// on the right.
struct RawGradingRow: View {
    let candidate: RawGradingCandidate
    let roi: GradeROIResult?

    /// The condition area most likely to cap the grade — the thing to look at
    /// before paying a grading fee.
    private var weakestArea: String? {
        let areas: [(String, Double)] = [
            ("corners", candidate.report.cornerScore),
            ("edges", candidate.report.edgeScore),
            ("surface", candidate.report.surfaceScore),
            ("print", candidate.report.printQualityScore),
        ]
        guard let weakest = areas.min(by: { $0.1 < $1.1 }), weakest.1 < 0.9 else { return nil }
        return "Watch the \(weakest.0)"
    }

    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            CardArtworkView(card: candidate.card, gradeBadge: String(format: "%.1f", candidate.report.estimatedGrade), size: .small)

            VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                Text(candidate.card.name)
                    .font(CIQFont.bodyBold)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                    .lineLimit(1)
                Text("Likely \(candidate.report.gradeDescriptor) · \(Int(candidate.report.psa10Probability * 100))% PSA 10")
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                if let weakestArea {
                    Text(weakestArea)
                        .font(CIQFont.caption)
                        .foregroundStyle(CIQColors.Fallback.warning)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: CIQSpacing.xxxs) {
                if let roi {
                    Text(roi.expectedProfit.signedCurrencyFormatted)
                        .font(CIQFont.bodyBold)
                        .foregroundStyle(roi.expectedProfit >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative)
                    Text(roi.recommendation.displayName)
                        .font(CIQFont.caption)
                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                } else {
                    Text("Price pending")
                        .font(CIQFont.caption)
                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                }
            }

            Image(systemName: "chevron.right")
                .font(CIQFont.caption)
                .foregroundStyle(CIQColors.Fallback.textTertiary)
        }
        .padding(CIQSpacing.sm)
        .background(CIQColors.Fallback.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))
    }
}

struct RawMoverRow: View {
    let mover: RawMover

    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(mover.change >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative)
                .frame(width: 3, height: 36)

            CardArtworkView(card: mover.card, size: .small)

            VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                Text(mover.card.name)
                    .font(CIQFont.bodyBold)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                    .lineLimit(1)
                Text(mover.card.setName)
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: CIQSpacing.xxxs) {
                Text(mover.raw.currencyFormatted)
                    .font(CIQFont.bodyBold)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                PriceChangeLabel(percentageChange: mover.change)
            }
        }
        .padding(CIQSpacing.sm)
        .background(CIQColors.Fallback.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))
    }
}

private extension Array {
    /// Order-preserving de-duplication by key.
    func uniqued<Key: Hashable>(by key: (Element) -> Key) -> [Element] {
        var seen = Set<Key>()
        return filter { seen.insert(key($0)).inserted }
    }
}

#Preview {
    OpportunitiesView()
        .environment(AppState())
        .modelContainer(for: CollectionItem.self, inMemory: true)
}
