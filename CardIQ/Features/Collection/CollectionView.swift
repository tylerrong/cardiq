import SwiftUI
import SwiftData

struct CollectionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CollectionItem.dateAdded, order: .reverse) private var items: [CollectionItem]
    @State private var searchText = ""
    @State private var sortOption: CollectionSortOption = .recentlyAdded
    @State private var filterOption: CollectionFilterOption = .all
    @State private var showGrid = true
    @State private var selectedItem: CollectionItem?
    @State private var hasSeedLoaded = false
    @State private var showAddCard = false
    @State private var itemToDelete: CollectionItem?

    private var filteredItems: [CollectionItem] {
        var result = items

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.cardIdentity?.name.lowercased().contains(q) == true ||
                $0.cardIdentity?.setName.lowercased().contains(q) == true
            }
        }

        switch filterOption {
        case .all: break
        case .raw: result = result.filter { $0.officialGrade == nil }
        case .graded: result = result.filter { $0.officialGrade != nil }
        case .pokemon: break
        case .gainers: result = result.filter { $0.gainLoss > 0 }
        case .losers: result = result.filter { $0.gainLoss < 0 }
        }

        switch sortOption {
        case .highestValue: result.sort { $0.currentValue > $1.currentValue }
        case .lowestValue: result.sort { $0.currentValue < $1.currentValue }
        case .biggestGain: result.sort { $0.gainLoss > $1.gainLoss }
        case .biggestLoss: result.sort { $0.gainLoss < $1.gainLoss }
        case .recentlyAdded: result.sort { $0.dateAdded > $1.dateAdded }
        case .alphabetical: result.sort { ($0.cardIdentity?.name ?? "") < ($1.cardIdentity?.name ?? "") }
        }

        return result
    }

    private var totalValue: Double {
        items.reduce(0) { $0 + $1.currentValue }
    }

    private var totalInvested: Double {
        items.reduce(0) { $0 + ($1.purchasePrice ?? 0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CIQSpacing.lg) {
                    portfolioSummary
                    filterBar
                    if filteredItems.isEmpty {
                        CIQEmptyState(
                            icon: "square.stack.3d.up",
                            title: "No Cards Yet",
                            message: "Scan a card or add one manually to start building your collection.",
                            actionTitle: "Scan a Card"
                        ) {
                            appState.showScanner = true
                        }
                    } else if showGrid {
                        gridView
                    } else {
                        listView
                    }
                }
                .padding(CIQSpacing.md)
            }
            .background(CIQColors.Fallback.backgroundPrimary)
            .navigationTitle("Collection")
            .ciqNavigationBarStyle()
            .searchable(text: $searchText, prompt: "Search collection...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: CIQSpacing.sm) {
                        Button {
                            showGrid.toggle()
                        } label: {
                            Image(systemName: showGrid ? "list.bullet" : "square.grid.2x2")
                                .foregroundStyle(CIQColors.Fallback.textSecondary)
                        }
                        Button {
                            showAddCard = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(CIQColors.Fallback.accentPrimary)
                        }
                    }
                }
            }
            .sheet(item: $selectedItem) { item in
                NavigationStack {
                    CollectionItemDetailView(item: item)
                }
            }
            .sheet(isPresented: $showAddCard) {
                NavigationStack {
                    AddCardView()
                }
            }
            .alert("Delete Card", isPresented: .init(
                get: { itemToDelete != nil },
                set: { if !$0 { itemToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let item = itemToDelete {
                        modelContext.delete(item)
                        try? modelContext.save()
                        itemToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { itemToDelete = nil }
            } message: {
                Text("Remove this card from your collection? This cannot be undone.")
            }
            .task {
                if !hasSeedLoaded && items.isEmpty {
                    seedCollection()
                    hasSeedLoaded = true
                }
                CIQImageCache.shared.prefetchThumbnails(for: items.compactMap(\.cardIdentity))
            }
        }
    }

    private var portfolioSummary: some View {
        CIQCard {
            HStack {
                VStack(alignment: .leading, spacing: CIQSpacing.xxs) {
                    Text("Portfolio")
                        .font(CIQFont.footnote)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                    Text(totalValue.currencyFormatted)
                        .font(CIQFont.displayLarge)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: CIQSpacing.xxs) {
                    Text("P&L")
                        .font(CIQFont.footnote)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                    let pl = totalValue - totalInvested
                    Text(pl.signedCurrencyFormatted)
                        .font(CIQFont.bodyBold)
                        .foregroundStyle(pl >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative)
                }
            }
        }
    }

    private var filterBar: some View {
        VStack(spacing: CIQSpacing.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CIQSpacing.xs) {
                    ForEach(CollectionFilterOption.allCases, id: \.self) { filter in
                        Button {
                            filterOption = filter
                        } label: {
                            Text(filter.displayName)
                                .font(CIQFont.captionBold)
                                .foregroundStyle(filterOption == filter ? .black : CIQColors.Fallback.textSecondary)
                                .padding(.horizontal, CIQSpacing.sm)
                                .padding(.vertical, CIQSpacing.xs)
                                .background(filterOption == filter ? CIQColors.Fallback.accentPrimary : CIQColors.Fallback.backgroundCard)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            HStack {
                Text("\(filteredItems.count) cards")
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
                Spacer()
                Menu {
                    ForEach(CollectionSortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                        } label: {
                            if sortOption == option {
                                Label(option.displayName, systemImage: "checkmark")
                            } else {
                                Text(option.displayName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: CIQSpacing.xxs) {
                        Text(sortOption.displayName)
                            .font(CIQFont.caption)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                }
            }
        }
    }

    private var gridView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CIQSpacing.sm) {
            ForEach(filteredItems, id: \.itemId) { item in
                Button { selectedItem = item } label: {
                    CollectionGridCell(item: item)
                }
                .contextMenu {
                    Button("Delete", role: .destructive) { itemToDelete = item }
                }
            }
        }
    }

    private var listView: some View {
        VStack(spacing: CIQSpacing.xs) {
            ForEach(filteredItems, id: \.itemId) { item in
                Button { selectedItem = item } label: {
                    CollectionListRow(item: item)
                }
                .contextMenu {
                    Button("Delete", role: .destructive) { itemToDelete = item }
                }
            }
        }
    }

    private func seedCollection() {
        for sample in MockSeedData.sampleCollectionItems {
            let item = CollectionItem(
                cardIdentity: sample.card,
                purchasePrice: sample.purchase,
                purchaseDate: Date().addingTimeInterval(-Double.random(in: 86400...2592000))
            )
            let market = MockSeedData.marketSnapshot(for: sample.card.id)
            item.marketSnapshot = market
            if let grade = sample.grade {
                item.officialGrade = grade
                item.officialGradingCompany = sample.gradeCompany
            }
            item.gradingReport = MockSeedData.gradingReport(for: sample.card.id)
            modelContext.insert(item)
        }
        try? modelContext.save()
    }
}

struct CollectionGridCell: View {
    let item: CollectionItem

    private var gradeBadgeText: String? {
        if let grade = item.officialGrade, let company = item.officialGradingCompany {
            return "\(company) \(Int(grade))"
        }
        if let grade = item.gradingReport?.estimatedGrade {
            return String(format: "%.1f", grade)
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.xs) {
            CardArtworkView(
                card: item.cardIdentity,
                gradeBadge: gradeBadgeText,
                size: .hero
            )

            Text(item.cardIdentity?.name ?? "Unknown")
                .font(CIQFont.footnoteBold)
                .foregroundStyle(CIQColors.Fallback.textPrimary)
                .lineLimit(1)

            HStack {
                Text(item.currentValue.currencyFormatted)
                    .font(CIQFont.captionBold)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                Spacer()
                if item.purchasePrice != nil {
                    PriceChangeLabel(percentageChange: item.gainLossPercentage)
                }
            }
        }
    }
}

struct CollectionListRow: View {
    let item: CollectionItem

    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            CardArtworkView(card: item.cardIdentity, size: .small)

            VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                Text(item.cardIdentity?.name ?? "Unknown")
                    .font(CIQFont.bodyBold)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                HStack(spacing: CIQSpacing.xs) {
                    Text(item.cardIdentity?.setName ?? "")
                        .font(CIQFont.caption)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                    if let grade = item.officialGrade, let co = item.officialGradingCompany {
                        GradeBadge(grade: "\(co) \(Int(grade))")
                    } else {
                        Text("Raw")
                            .font(CIQFont.captionBold)
                            .foregroundStyle(CIQColors.Fallback.textTertiary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: CIQSpacing.xxxs) {
                Text(item.currentValue.currencyFormatted)
                    .font(CIQFont.bodyBold)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                if item.purchasePrice != nil {
                    Text(item.gainLoss.signedCurrencyFormatted)
                        .font(CIQFont.captionBold)
                        .foregroundStyle(item.gainLoss >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative)
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

struct CollectionItemDetailView: View {
    let item: CollectionItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showOfficialGrade = false
    @State private var showEdit = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CIQSpacing.lg) {
                cardHeader
                if item.purchasePrice != nil { purchaseSection }
                if let report = item.gradingReport { gradingSummary(report) }
                if let market = item.marketSnapshot { marketSummary(market) }
                if item.officialGrade != nil { officialGradeSection }
                actionsSection
            }
            .padding(CIQSpacing.md)
        }
        .background(CIQColors.Fallback.backgroundPrimary)
        .navigationTitle(item.cardIdentity?.name ?? "Card Detail")
        .ciqInlineTitle()
        .ciqNavigationBarStyle()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(CIQColors.Fallback.accentPrimary)
            }
        }
        .sheet(isPresented: $showOfficialGrade) {
            OfficialGradeEntryView(item: item)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showEdit) {
            EditCollectionItemView(item: item)
                .presentationDetents([.medium])
        }
        .alert("Remove Card", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(item)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove this card from your collection? This cannot be undone.")
        }
    }

    private var cardHeader: some View {
        CIQCard {
            VStack(spacing: CIQSpacing.md) {
                CardArtworkView(
                    card: item.cardIdentity,
                    gradeBadge: item.officialGrade.map { "\(item.officialGradingCompany ?? "PSA") \(Int($0))" },
                    size: .hero
                )
                .frame(maxWidth: 200)
                .frame(maxWidth: .infinity)

                if let card = item.cardIdentity {
                    VStack(spacing: CIQSpacing.xs) {
                        Text(card.name)
                            .font(CIQFont.title)
                            .foregroundStyle(CIQColors.Fallback.textPrimary)

                        HStack(spacing: CIQSpacing.sm) {
                            CIQBadge(text: card.rarity.displayName, color: CIQColors.Fallback.accentPrimary)
                            if let grade = item.officialGrade, let company = item.officialGradingCompany {
                                CIQBadge(text: "\(company) \(Int(grade))", color: CIQColors.Fallback.positive)
                            }
                        }

                        CIQMetricRow("Set", value: card.setName)
                        CIQMetricRow("Number", value: card.displayNumber)
                        CIQMetricRow("Year", value: "\(card.year)")
                    }
                }
            }
        }
    }

    private var purchaseSection: some View {
        CIQCard {
            VStack(spacing: CIQSpacing.sm) {
                Text("Purchase Info")
                    .font(CIQFont.headline)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let price = item.purchasePrice {
                    CIQMetricRow("Purchase Price", value: price.currencyFormatted)
                }
                CIQMetricRow("Current Value", value: item.currentValue.currencyFormatted)
                CIQMetricRow(
                    "Unrealized P&L",
                    value: item.gainLoss.signedCurrencyFormatted,
                    valueColor: item.gainLoss >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative
                )
                CIQMetricRow(
                    "Return",
                    value: item.gainLossPercentage.percentFormatted,
                    valueColor: item.gainLossPercentage >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative
                )
            }
        }
    }

    private func gradingSummary(_ report: GradingReport) -> some View {
        CIQCard {
            VStack(spacing: CIQSpacing.sm) {
                HStack {
                    Text("AI Grade Estimate")
                        .font(CIQFont.headline)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                    Spacer()
                    CIQGradeCircle(grade: report.estimatedGrade, size: 50)
                }
                CIQMetricRow("Centering", value: String(format: "%.1f", max(5, 10 - (abs(report.frontCenteringHorizontal - 0.5) + abs(report.frontCenteringVertical - 0.5)) * 20)))
                CIQMetricRow("Corners", value: String(format: "%.1f", report.cornerScore))
                CIQMetricRow("Edges", value: String(format: "%.1f", report.edgeScore))
                CIQMetricRow("Surface", value: String(format: "%.1f", report.surfaceScore))
                CIQDisclaimerView()
            }
        }
    }

    private func marketSummary(_ market: MarketSnapshot) -> some View {
        CIQCard {
            VStack(spacing: CIQSpacing.sm) {
                Text("Market Data")
                    .font(CIQFont.headline)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                CIQMetricRow("Raw", value: market.rawEstimatedValue.currencyFormatted)
                CIQMetricRow("PSA 9", value: market.psa9EstimatedValue.currencyFormatted)
                CIQMetricRow("PSA 10", value: market.psa10EstimatedValue.currencyFormatted, valueColor: CIQColors.Fallback.accentPrimary)
                CIQMetricRow("30D Change", value: market.thirtyDayChangePercentage.percentFormatted, valueColor: market.thirtyDayChangePercentage >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative)
            }
        }
    }

    private var officialGradeSection: some View {
        CIQCard {
            VStack(spacing: CIQSpacing.sm) {
                Text("Official Grade")
                    .font(CIQFont.headline)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let grade = item.officialGrade, let company = item.officialGradingCompany {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Official")
                                .font(CIQFont.caption)
                                .foregroundStyle(CIQColors.Fallback.textSecondary)
                            Text("\(company) \(Int(grade))")
                                .font(CIQFont.displayMedium)
                                .foregroundStyle(CIQColors.Fallback.accentPrimary)
                        }
                        Spacer()
                        if let estimated = item.gradingReport?.estimatedGrade {
                            VStack(alignment: .trailing) {
                                Text("Predicted")
                                    .font(CIQFont.caption)
                                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                                Text(String(format: "%.1f", estimated))
                                    .font(CIQFont.displayMedium)
                                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: CIQSpacing.sm) {
            CIQSecondaryButton("Edit Card Details", icon: "pencil") {
                showEdit = true
            }
            if item.officialGrade == nil {
                CIQSecondaryButton("Add Official Grade", icon: "seal") {
                    showOfficialGrade = true
                }
            }
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: CIQSpacing.xs) {
                    Image(systemName: "trash")
                    Text("Remove from Collection")
                }
                .font(CIQFont.subheadline)
                .foregroundStyle(CIQColors.Fallback.negative)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CIQSpacing.sm)
            }
        }
    }
}

struct OfficialGradeEntryView: View {
    let item: CollectionItem
    @Environment(\.dismiss) private var dismiss
    @State private var gradingCompany = "PSA"
    @State private var grade: Double = 9
    @State private var certNumber = ""
    @State private var dateReceived = Date()
    @State private var allowAnonymizedData = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Grading Details") {
                    Picker("Company", selection: $gradingCompany) {
                        Text("PSA").tag("PSA")
                        Text("CGC").tag("CGC")
                        Text("BGS").tag("BGS")
                    }
                    Picker("Grade", selection: $grade) {
                        ForEach([10.0, 9.5, 9.0, 8.5, 8.0, 7.5, 7.0, 6.5, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0], id: \.self) { g in
                            Text(String(format: g.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", g)).tag(g)
                        }
                    }
                    TextField("Certification Number", text: $certNumber)
                    DatePicker("Date Received", selection: $dateReceived, displayedComponents: .date)
                }

                if let estimated = item.gradingReport?.estimatedGrade {
                    Section("Comparison") {
                        HStack {
                            Text("CardIQ Predicted")
                            Spacer()
                            Text(String(format: "%.1f", estimated))
                                .foregroundStyle(CIQColors.Fallback.textSecondary)
                        }
                        HStack {
                            Text("Official Grade")
                            Spacer()
                            Text(String(format: grade.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", grade))
                                .foregroundStyle(CIQColors.Fallback.accentPrimary)
                        }
                        HStack {
                            Text("Difference")
                            Spacer()
                            let diff = grade - estimated
                            Text(String(format: "%+.1f", diff))
                                .foregroundStyle(abs(diff) <= 0.5 ? CIQColors.Fallback.positive : CIQColors.Fallback.warning)
                        }
                    }
                }

                Section {
                    Toggle(isOn: $allowAnonymizedData) {
                        VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                            Text("Improve CardIQ")
                                .font(CIQFont.body)
                            Text("Allow anonymized scan data and official results to help improve CardIQ.")
                                .font(CIQFont.caption)
                                .foregroundStyle(CIQColors.Fallback.textSecondary)
                        }
                    }
                    .tint(CIQColors.Fallback.accentPrimary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CIQColors.Fallback.backgroundPrimary)
            .navigationTitle("Official Grade")
            .ciqInlineTitle()
            .ciqNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        item.officialGrade = grade
                        item.officialGradingCompany = gradingCompany
                        item.officialCertNumber = certNumber
                        item.officialGradeDate = dateReceived
                        item.allowAnonymizedData = allowAnonymizedData
                        dismiss()
                    }
                    .foregroundStyle(CIQColors.Fallback.accentPrimary)
                }
            }
        }
    }
}

#Preview {
    CollectionView()
        .environment(AppState())
        .modelContainer(for: CollectionItem.self, inMemory: true)
}
