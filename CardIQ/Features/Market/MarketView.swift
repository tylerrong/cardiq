import SwiftUI
import SwiftData
import Charts

struct MarketView: View {
    @State private var searchText = ""
    @State private var selectedTimeRange: TimeRange = .thirtyDays
    @State private var trendingCards: [CardIdentity] = []
    @State private var allCards: [CardIdentity] = []
    @State private var showChat = false
    @Query(sort: \WatchlistItem.dateAdded, order: .reverse) private var watchlistItems: [WatchlistItem]

    private var filteredCards: [CardIdentity] {
        if searchText.isEmpty { return allCards }
        let q = searchText.lowercased()
        return allCards.filter { $0.name.lowercased().contains(q) || $0.setName.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CIQSpacing.lg) {
                    if searchText.isEmpty {
                        if !watchlistItems.isEmpty {
                            watchlistSection
                        }
                        trendingSection
                    }

                    allCardsSection
                    Color.clear.frame(height: 80)
                }
                .padding(CIQSpacing.md)
            }
            .background(CIQColors.Fallback.backgroundPrimary)
            .navigationTitle("Market")
            .ciqNavigationBarStyle()
            .searchable(text: $searchText, prompt: "Search cards...")
            .task {
                allCards = await ServiceContainer.shared.cardIdentification.allCards()
                trendingCards = (try? await ServiceContainer.shared.marketData.trendingCards()) ?? []
                CIQImageCache.shared.prefetchThumbnails(for: allCards + trendingCards)
            }
        }
    }

    private var watchlistSection: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            CIQSectionHeader("Watchlist")
            ForEach(watchlistItems, id: \.cardId) { item in
                if let card = item.cardIdentity {
                    NavigationLink(value: card) {
                        MarketCardRow(card: card)
                    }
                }
            }
        }
    }

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            CIQSectionHeader("Trending")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CIQSpacing.sm) {
                    ForEach(trendingCards) { card in
                        NavigationLink(value: card) {
                            TrendingCardCell(card: card)
                        }
                    }
                }
            }
        }
        .navigationDestination(for: CardIdentity.self) { card in
            MarketDetailView(card: card)
        }
    }

    private var allCardsSection: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            CIQSectionHeader("Browse Cards")
            ForEach(filteredCards) { card in
                NavigationLink(value: card) {
                    MarketCardRow(card: card)
                }
            }
        }
    }
}

struct TrendingCardCell: View {
    let card: CardIdentity
    @State private var market: MarketSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.xs) {
            CardArtworkView(card: card, size: .large)

            Text(card.name)
                .font(CIQFont.footnoteBold)
                .foregroundStyle(CIQColors.Fallback.textPrimary)
                .lineLimit(1)

            if let market {
                if market.rawEstimatedValue > 0 {
                    HStack(spacing: CIQSpacing.xs) {
                        Text(market.rawEstimatedValue.currencyFormatted)
                            .font(CIQFont.bodyBold)
                            .foregroundStyle(CIQColors.Fallback.textPrimary)
                        PriceChangeLabel(percentageChange: market.thirtyDayChangePercentage)
                    }
                } else {
                    Text("Price unavailable")
                        .font(CIQFont.caption)
                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                }
                if market.salesVolume30Days > 0 {
                    Text("\(market.salesVolume30Days) sales")
                        .font(CIQFont.caption)
                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                }
            }
        }
        .frame(width: 150)
        .task { market = await MarketSnapshotCache.shared.snapshot(for: card.id) }
    }
}

struct MarketCardRow: View {
    let card: CardIdentity
    @State private var market: MarketSnapshot?

    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            CardArtworkView(card: card, size: .small)

            VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                Text(card.name)
                    .font(CIQFont.bodyBold)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                HStack(spacing: CIQSpacing.xxs) {
                    Text("\(card.setName) · \(card.displayNumber)")
                        .font(CIQFont.caption)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                }
                if let market, let variant = card.variant {
                    Text(variant)
                        .font(CIQFont.caption)
                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                    if market.salesVolume30Days > 100 {
                        DataFreshnessLabel(text: "High confidence", icon: "checkmark.seal")
                    }
                }
            }

            Spacer()

            if let market {
                VStack(alignment: .trailing, spacing: CIQSpacing.xxxs) {
                    if market.rawEstimatedValue > 0 {
                        let lo = market.rawEstimatedValue * 0.95
                        let hi = market.rawEstimatedValue * 1.05
                        Text("\(lo.currencyFormatted)–\(hi.currencyFormatted)")
                            .font(CIQFont.footnoteBold)
                            .foregroundStyle(CIQColors.Fallback.textPrimary)
                        PriceChangeLabel(percentageChange: market.thirtyDayChangePercentage)
                    } else {
                        Text("Price unavailable")
                            .font(CIQFont.caption)
                            .foregroundStyle(CIQColors.Fallback.textTertiary)
                    }
                    if market.salesVolume30Days > 0 {
                        Text("\(market.salesVolume30Days) sales")
                            .font(CIQFont.caption)
                            .foregroundStyle(CIQColors.Fallback.textTertiary)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(CIQFont.caption)
                .foregroundStyle(CIQColors.Fallback.textTertiary)
        }
        .padding(CIQSpacing.sm)
        .background(CIQColors.Fallback.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))
        .task { market = await MarketSnapshotCache.shared.snapshot(for: card.id) }
    }
}

struct MarketDetailView: View {
    let card: CardIdentity
    @Environment(\.modelContext) private var modelContext
    @State private var market: MarketSnapshot?
    @State private var priceHistory: [PriceHistoryPoint] = []
    @State private var selectedTimeRange: TimeRange = .thirtyDays
    @State private var hideWeakComps = false
    @State private var showAddToCollection = false
    @State private var addedToCollection = false
    @State private var isWatchlisted = false

    private var filteredSales: [ComparableSale] {
        guard let market else { return [] }
        if hideWeakComps { return market.recentSales.filter { $0.matchQuality != .weak } }
        return market.recentSales
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CIQSpacing.lg) {
                if let market {
                    valuesSection(market)
                    chartSection
                    volumeSection(market)
                    actionsSection
                    salesSection
                } else {
                    CIQLoadingView(message: "Loading market data...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, CIQSpacing.xxxxl)
                }
            }
            .padding(CIQSpacing.md)
        }
        .background(CIQColors.Fallback.backgroundPrimary)
        .navigationTitle(card.name)
        .ciqNavigationBarStyle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    toggleWatchlist()
                } label: {
                    Image(systemName: isWatchlisted ? "eye.fill" : "eye")
                        .foregroundStyle(isWatchlisted ? CIQColors.Fallback.accentPrimary : CIQColors.Fallback.textSecondary)
                }
                .accessibilityLabel(isWatchlisted ? "Remove from watchlist" : "Add to watchlist")
            }
        }
        .task {
            let service = ServiceContainer.shared.marketData
            market = await MarketSnapshotCache.shared.snapshot(for: card.id)
            priceHistory = (try? await service.priceHistory(for: card.id, range: selectedTimeRange)) ?? []
            checkWatchlist()
        }
        .onChange(of: selectedTimeRange) { _, newRange in
            Task {
                priceHistory = (try? await ServiceContainer.shared.marketData.priceHistory(for: card.id, range: newRange)) ?? []
            }
        }
        .sheet(isPresented: $showAddToCollection) {
            NavigationStack {
                MarketAddToCollectionView(card: card, market: market) {
                    addedToCollection = true
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var actionsSection: some View {
        HStack(spacing: CIQSpacing.sm) {
            if addedToCollection {
                HStack(spacing: CIQSpacing.xxs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(CIQColors.Fallback.positive)
                    Text("In Collection")
                        .font(CIQFont.footnoteBold)
                        .foregroundStyle(CIQColors.Fallback.positive)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CIQSpacing.sm)
                .background(CIQColors.Fallback.positive.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CIQRadius.button))
            } else {
                CIQSecondaryButton("Add to Collection", icon: "plus.circle") {
                    showAddToCollection = true
                }
            }
        }
    }

    private func checkWatchlist() {
        let cardId = card.id
        let descriptor = FetchDescriptor<WatchlistItem>(predicate: #Predicate { $0.cardId == cardId })
        isWatchlisted = ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
    }

    private func toggleWatchlist() {
        let cardId = card.id
        if isWatchlisted {
            let descriptor = FetchDescriptor<WatchlistItem>(predicate: #Predicate { $0.cardId == cardId })
            if let existing = try? modelContext.fetch(descriptor).first {
                modelContext.delete(existing)
                try? modelContext.save()
            }
            isWatchlisted = false
        } else {
            let item = WatchlistItem(cardIdentity: card)
            modelContext.insert(item)
            try? modelContext.save()
            isWatchlisted = true
        }
    }

    private func valuesSection(_ market: MarketSnapshot) -> some View {
        CIQCard {
            VStack(spacing: CIQSpacing.sm) {
                CIQMetricRow("Raw", value: market.rawEstimatedValue.currencyFormatted)
                CIQMetricRow("PSA 8", value: market.psa8EstimatedValue.currencyFormatted)
                CIQMetricRow("PSA 9", value: market.psa9EstimatedValue.currencyFormatted)
                CIQMetricRow("PSA 10", value: market.psa10EstimatedValue.currencyFormatted, valueColor: CIQColors.Fallback.accentPrimary)
                CIQDisclaimerView("Estimated values based on recent sales.")
            }
        }
    }

    private var chartSection: some View {
        CIQCard {
            VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                HStack {
                    Text("Price History")
                        .font(CIQFont.headline)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                    Spacer()
                    Picker("Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                if !priceHistory.isEmpty {
                    Chart(priceHistory) {
                        LineMark(x: .value("Date", $0.date), y: .value("Price", $0.price))
                            .foregroundStyle(CIQColors.Fallback.accentPrimary)
                        AreaMark(x: .value("Date", $0.date), y: .value("Price", $0.price))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [CIQColors.Fallback.accentPrimary.opacity(0.3), .clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let price = value.as(Double.self) {
                                    Text(price.currencyFormatted)
                                        .font(CIQFont.caption)
                                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date, format: .dateTime.month(.abbreviated).day())
                                        .font(CIQFont.caption)
                                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                } else {
                    Text("No price history available")
                        .font(CIQFont.footnote)
                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                }
            }
        }
    }

    private func volumeSection(_ market: MarketSnapshot) -> some View {
        CIQCard {
            VStack(spacing: CIQSpacing.sm) {
                if market.salesVolume30Days > 0 {
                    CIQMetricRow("30-Day Volume", value: "\(market.salesVolume30Days) sales")
                }
                CIQMetricRow("Liquidity", value: String(format: "%.0f%%", market.liquidityScore * 100))
                CIQMetricRow("30D Change", value: market.thirtyDayChangePercentage.percentFormatted, valueColor: market.thirtyDayChangePercentage >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative)
                if market.ninetyDayChangePercentage != 0 {
                    CIQMetricRow("90D Change", value: market.ninetyDayChangePercentage.percentFormatted, valueColor: market.ninetyDayChangePercentage >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative)
                }
                if market.oneYearChangePercentage != 0 {
                    CIQMetricRow("1Y Change", value: market.oneYearChangePercentage.percentFormatted, valueColor: market.oneYearChangePercentage >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative)
                }
            }
        }
    }

    private var salesSection: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            HStack {
                CIQSectionHeader("Recent Sales")
                Spacer()
                Toggle("Hide weak", isOn: $hideWeakComps)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(CIQColors.Fallback.accentPrimary)
                Text("Hide weak")
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
            }

            ForEach(filteredSales) { sale in
                ComparableSaleRow(sale: sale)
            }
        }
    }
}

struct ComparableSaleRow: View {
    let sale: ComparableSale

    private var matchColor: Color {
        switch sale.matchQuality {
        case .exact: CIQColors.Fallback.positive
        case .strong: CIQColors.Fallback.accentPrimary
        case .partial: CIQColors.Fallback.warning
        case .weak: CIQColors.Fallback.textTertiary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.xs) {
            HStack {
                Text(sale.title)
                    .font(CIQFont.subheadline)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(sale.salePrice.currencyFormatted)
                    .font(CIQFont.bodyBold)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
            }
            HStack {
                CIQBadge(text: sale.matchQuality.displayName, color: matchColor)
                Text(sale.marketplace)
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
                if let grade = sale.grade, let company = sale.gradingCompany {
                    Text("\(company) \(String(format: "%.0f", grade))")
                        .font(CIQFont.captionBold)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                }
                Spacer()
                Text(sale.saleDate, format: .dateTime.month(.abbreviated).day())
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
            }
        }
        .padding(CIQSpacing.sm)
        .background(CIQColors.Fallback.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))
    }
}

#Preview("Market") {
    MarketView()
}

#Preview("Market Detail") {
    NavigationStack {
        MarketDetailView(card: MockSeedData.cards[0])
    }
}
