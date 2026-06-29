import SwiftUI
import SwiftData

/// Front-only result: identifies the card and shows its raw market value, with an
/// upsell to capture the back for full AI grading. No grading report is produced.
struct RawValueResultView: View {
    let card: CardIdentity
    let market: MarketSnapshot
    var onScanBack: (() -> Void)?
    var onDismiss: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var savedToCollection = false
    @State private var showToast = false
    @State private var hasSavedScanRecord = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: CIQSpacing.lg) {
                    identifiedHeader
                    rawValueCard
                        .slideUp(delay: 0.2)
                    if !market.recentSales.isEmpty {
                        recentSalesCard
                            .slideUp(delay: 0.4)
                    }
                    gradingUpsell
                        .slideUp(delay: 0.6)
                    Color.clear.frame(height: 80)
                }
                .padding(CIQSpacing.md)
            }

            stickyBottomBar
        }
        .background(CIQColors.Fallback.backgroundPrimary)
        .navigationTitle(card.name)
        .ciqNavigationBarStyle()
        .toolbar {
            if let onDismiss {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                        .foregroundStyle(CIQColors.Fallback.accentPrimary)
                }
            }
        }
        .task {
            CIQHaptics.success()
            guard !hasSavedScanRecord else { return }
            let record = ScanRecord(cardIdentity: card, gradingReport: nil, marketSnapshot: market)
            modelContext.insert(record)
            try? modelContext.save()
            hasSavedScanRecord = true
        }
        .ciqToast(isPresented: $showToast, message: "Saved to collection")
    }

    private var identifiedHeader: some View {
        CIQCard {
            VStack(spacing: CIQSpacing.md) {
                HStack {
                    Text("Card Identified")
                        .font(CIQFont.headline)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                    Spacer()
                    CIQBadge(
                        text: "\(Int(card.identificationConfidence * 100))% match",
                        color: card.identificationConfidence >= 0.9 ? CIQColors.Fallback.positive : CIQColors.Fallback.warning
                    )
                }

                CardArtworkView(card: card, size: .large)
                    .frame(maxWidth: .infinity)

                VStack(spacing: CIQSpacing.xs) {
                    CIQMetricRow("Name", value: card.name)
                    CIQMetricRow("Set", value: card.setName)
                    CIQMetricRow("Year", value: "\(card.year)")
                    CIQMetricRow("Number", value: card.displayNumber)
                    CIQMetricRow("Rarity", value: card.rarity.displayName)
                }
            }
        }
    }

    private var rawValueCard: some View {
        CIQCard {
            VStack(spacing: CIQSpacing.sm) {
                Text("Estimated Raw Value")
                    .font(CIQFont.footnoteBold)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(market.rawEstimatedValue.currencyFormatted)
                    .font(CIQFont.displayLarge)
                    .foregroundStyle(CIQColors.Fallback.accentPrimary)

                HStack(spacing: CIQSpacing.lg) {
                    changeStat("30D", market.thirtyDayChangePercentage)
                    changeStat("90D", market.ninetyDayChangePercentage)
                    changeStat("1Y", market.oneYearChangePercentage)
                }

                CIQDisclaimerView("Ungraded estimate based on recent sales. Scan the back for grade-specific values.")
            }
        }
    }

    private func changeStat(_ label: String, _ percent: Double) -> some View {
        let positive = percent >= 0
        return VStack(spacing: CIQSpacing.xxxs) {
            Text(label)
                .font(CIQFont.caption)
                .foregroundStyle(CIQColors.Fallback.textTertiary)
            Text("\(positive ? "+" : "")\(String(format: "%.1f", percent))%")
                .font(CIQFont.footnoteBold)
                .foregroundStyle(positive ? CIQColors.Fallback.positive : CIQColors.Fallback.negative)
        }
        .frame(maxWidth: .infinity)
    }

    private var recentSalesCard: some View {
        CIQCard {
            VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                Text("Recent Sales")
                    .font(CIQFont.headline)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)

                ForEach(market.recentSales.prefix(5)) { sale in
                    HStack(spacing: CIQSpacing.sm) {
                        VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                            Text(sale.title)
                                .font(CIQFont.footnoteBold)
                                .foregroundStyle(CIQColors.Fallback.textPrimary)
                                .lineLimit(1)
                            Text("\(sale.marketplace) · \(sale.condition)")
                                .font(CIQFont.caption)
                                .foregroundStyle(CIQColors.Fallback.textSecondary)
                        }
                        Spacer()
                        Text(sale.salePrice.currencyFormatted)
                            .font(CIQFont.bodyBold)
                            .foregroundStyle(CIQColors.Fallback.textPrimary)
                    }
                    .padding(.vertical, CIQSpacing.xxs)
                }
            }
        }
    }

    private var gradingUpsell: some View {
        CIQCard {
            VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                HStack(spacing: CIQSpacing.xs) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(CIQColors.Fallback.accentPrimary)
                    Text("Want a grade estimate?")
                        .font(CIQFont.headline)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                }

                Text("Capture the back of the card to unlock AI grading confidence — centering, corners, edges, surface, and PSA-grade probabilities.")
                    .font(CIQFont.subheadline)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let onScanBack {
                    CIQSecondaryButton("Scan the Back", icon: "rectangle.portrait.on.rectangle.portrait") {
                        CIQHaptics.tap()
                        onScanBack()
                    }
                }
            }
        }
    }

    private var stickyBottomBar: some View {
        VStack(spacing: 0) {
            Divider().background(CIQColors.Fallback.border)
            HStack(spacing: CIQSpacing.sm) {
                if savedToCollection {
                    HStack(spacing: CIQSpacing.xxs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(CIQColors.Fallback.positive)
                        Text("Saved")
                            .font(CIQFont.footnoteBold)
                            .foregroundStyle(CIQColors.Fallback.positive)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Button {
                        let item = CollectionItem(cardIdentity: card)
                        item.marketSnapshot = market
                        CollectionSync.add(item, to: modelContext)
                        savedToCollection = true
                        showToast = true
                        CIQHaptics.success()
                    } label: {
                        HStack(spacing: CIQSpacing.xxs) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save")
                        }
                        .font(CIQFont.footnoteBold)
                        .foregroundStyle(CIQColors.Fallback.accentPrimary)
                        .frame(maxWidth: .infinity)
                    }
                }

                ShareLink(item: shareText) {
                    HStack(spacing: CIQSpacing.xxs) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(CIQFont.footnoteBold)
                    .foregroundStyle(CIQColors.Fallback.accentPrimary)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(CIQSpacing.md)
            .background(CIQColors.Fallback.backgroundPrimary)
        }
    }

    private var shareText: String {
        """
        CardIQ: \(card.name)
        \(card.setName) · \(card.displayNumber)

        Estimated Raw Value: \(market.rawEstimatedValue.currencyFormatted)

        ⚠️ AI estimate based on recent sales, not an official appraisal.
        """
    }
}

#Preview("Raw Value Result") {
    NavigationStack {
        RawValueResultView(
            card: MockSeedData.cards[0],
            market: MockSeedData.marketSnapshot(for: MockSeedData.cards[0].id)
        )
    }
}
