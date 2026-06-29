import SwiftUI
import SwiftData

struct GradeROIView: View {
    let card: CardIdentity
    let report: GradingReport
    let market: MarketSnapshot
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: GradeROIViewModel
    @State private var savedToCollection = false
    @State private var showShareSheet = false

    init(card: CardIdentity, report: GradingReport, market: MarketSnapshot) {
        self.card = card
        self.report = report
        self.market = market
        self._viewModel = State(initialValue: GradeROIViewModel(report: report, market: market))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: CIQSpacing.lg) {
                recommendationHeader
                inputsSection
                outcomesTable
                expectedValueSection
                maxBuyPriceSection
                CIQDisclaimerView("ROI calculations are estimates based on current market data and AI grading predictions. Actual results may vary.")

                actionsSection
            }
            .padding(CIQSpacing.md)
        }
        .background(CIQColors.Fallback.backgroundPrimary)
        .navigationTitle("Grading ROI")
        .ciqInlineTitle()
        .ciqNavigationBarStyle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
            }
        }
    }

    private var recommendationHeader: some View {
        CIQCard {
            VStack(spacing: CIQSpacing.md) {
                Image(systemName: viewModel.result.recommendation.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(colorForRecommendation(viewModel.result.recommendation))
                    .scaleIn(delay: 0.2)

                Text(viewModel.result.recommendation.displayName)
                    .font(CIQFont.displayMedium)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                    .slideUp(delay: 0.4)

                Text(viewModel.result.explanation)
                    .font(CIQFont.subheadline)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .slideUp(delay: 0.6)
            }
        }
    }

    private var inputsSection: some View {
        CIQCard {
            VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                Text("Inputs")
                    .font(CIQFont.headline)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)

                ROIInputField(label: "Purchase Price", value: $viewModel.input.purchasePrice, format: .currency)
                ROIInputField(label: "Grading Fee", value: $viewModel.input.gradingFee, format: .currency)
                ROIInputField(label: "Shipping", value: $viewModel.input.shippingCost, format: .currency)
                ROIInputField(label: "Insurance", value: $viewModel.input.insuranceCost, format: .currency)
                ROIInputField(label: "Selling Fee %", value: $viewModel.input.sellingFeePercentage, format: .percent)
            }
        }
    }

    private var outcomesTable: some View {
        CIQCard {
            VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                Text("Outcome Analysis")
                    .font(CIQFont.headline)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)

                ForEach(viewModel.outcomes) { outcome in
                    OutcomeRow(outcome: outcome)
                }
            }
        }
    }

    private var expectedValueSection: some View {
        CIQCard {
            VStack(spacing: CIQSpacing.sm) {
                Text("Expected Outcome (Probability-Weighted)")
                    .font(CIQFont.headline)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)

                CIQMetricRow(
                    "Expected Graded Value",
                    value: viewModel.result.expectedGradedValue.currencyFormatted,
                    valueColor: CIQColors.Fallback.accentPrimary
                )
                CIQMetricRow("Total Cost Basis", value: viewModel.result.totalCostBasis.currencyFormatted)
                CIQMetricRow("Expected Net Proceeds", value: viewModel.result.expectedNetProceeds.currencyFormatted)

                Divider().background(CIQColors.Fallback.border)

                CIQMetricRow(
                    "Expected Profit",
                    value: viewModel.result.expectedProfit.signedCurrencyFormatted,
                    valueColor: viewModel.result.expectedProfit >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative
                )
                CIQMetricRow(
                    "Expected ROI",
                    value: viewModel.result.expectedROI.percentFormatted,
                    valueColor: viewModel.result.expectedROI >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative
                )
            }
        }
    }

    private var maxBuyPriceSection: some View {
        CIQCard {
            VStack(spacing: CIQSpacing.sm) {
                HStack(spacing: CIQSpacing.xs) {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(CIQColors.Fallback.accentPrimary)
                    Text("Maximum Buy Price")
                        .font(CIQFont.headline)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                }

                Text(viewModel.result.maximumRecommendedBuyPrice.currencyFormatted)
                    .font(CIQFont.heroValue)
                    .foregroundStyle(CIQColors.Fallback.accentPrimary)

                Text("The highest price you should pay for this card to achieve your \(Int(viewModel.input.requiredMarginPercentage))% required margin after grading and selling costs.")
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: CIQSpacing.sm) {
            if savedToCollection {
                HStack(spacing: CIQSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(CIQColors.Fallback.positive)
                    Text("Saved to Collection")
                        .font(CIQFont.headline)
                        .foregroundStyle(CIQColors.Fallback.positive)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CIQSpacing.md)
            } else {
                CIQPrimaryButton("Save to Collection", icon: "square.and.arrow.down") {
                    saveToCollection()
                }
            }

            ShareLink(item: shareText) {
                HStack(spacing: CIQSpacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Share Report")
                        .font(CIQFont.headline)
                }
                .foregroundStyle(CIQColors.Fallback.accentPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CIQSpacing.md)
                .background(CIQColors.Fallback.accentPrimary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: CIQRadius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: CIQRadius.button)
                        .strokeBorder(CIQColors.Fallback.accentPrimary.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    private func saveToCollection() {
        let item = CollectionItem(
            cardIdentity: card,
            purchasePrice: viewModel.input.purchasePrice > 0 ? viewModel.input.purchasePrice : nil,
            purchaseDate: Date()
        )
        item.gradingReport = report
        item.marketSnapshot = market
        CollectionSync.add(item, to: modelContext)
        savedToCollection = true
        CIQHaptics.success()
    }

    private var shareText: String {
        let grade = String(format: "%.1f", report.estimatedGrade)
        let rec = viewModel.result.recommendation.displayName
        let raw = market.rawEstimatedValue.currencyFormatted
        let psa10 = market.psa10EstimatedValue.currencyFormatted
        let profit = viewModel.result.expectedProfit.signedCurrencyFormatted
        return """
        CardIQ Grade Report: \(card.name)
        \(card.setName) · \(card.displayNumber)

        Estimated Grade: \(grade) (\(report.gradeDescriptor))
        Recommendation: \(rec)

        Raw Value: \(raw)
        PSA 10 Value: \(psa10)
        Expected Profit: \(profit)

        \(viewModel.result.explanation)

        ⚠️ This is an AI estimate, not an official grade.
        """
    }

    private func colorForRecommendation(_ rec: GradeRecommendation) -> Color {
        switch rec {
        case .grade: CIQColors.Fallback.positive
        case .considerGrading: CIQColors.Fallback.accentPrimary
        case .sellRaw: CIQColors.Fallback.warning
        case .hold: CIQColors.Fallback.textSecondary
        case .insufficientData: CIQColors.Fallback.textTertiary
        }
    }
}

struct ROIInputField: View {
    let label: String
    @Binding var value: Double
    let format: InputFormat

    enum InputFormat { case currency, percent }

    var body: some View {
        HStack {
            Text(label)
                .font(CIQFont.subheadline)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
            Spacer()
            HStack(spacing: CIQSpacing.xxs) {
                Text(format == .currency ? "$" : "")
                    .font(CIQFont.subheadline)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
                TextField("", value: $value, format: .number.precision(.fractionLength(2)))
                    .font(CIQFont.mono)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                    .ciqDecimalKeyboard()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text(format == .percent ? "%" : "")
                    .font(CIQFont.subheadline)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
            }
        }
    }
}

struct OutcomeRow: View {
    let outcome: GradeOutcome

    var body: some View {
        VStack(spacing: CIQSpacing.xs) {
            HStack {
                Text(outcome.label)
                    .font(CIQFont.bodyBold)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                if outcome.probability < 1.0 {
                    CIQBadge(
                        text: "\(Int(outcome.probability * 100))%",
                        color: CIQColors.Fallback.textSecondary
                    )
                }
                Spacer()
                Text(outcome.profit.signedCurrencyFormatted)
                    .font(CIQFont.bodyBold)
                    .foregroundStyle(outcome.profit >= 0 ? CIQColors.Fallback.positive : CIQColors.Fallback.negative)
            }
            HStack {
                Text("Sale: \(outcome.estimatedSalePrice.currencyFormatted)")
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
                Spacer()
                Text("ROI: \(outcome.roi.percentFormatted)")
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
            }
            Divider().background(CIQColors.Fallback.borderSubtle)
        }
    }
}

@Observable
@MainActor
final class GradeROIViewModel {
    var input: ROIInput = .default {
        didSet { recalculate() }
    }
    var result: GradeROIResult
    var outcomes: [GradeOutcome]

    private let report: GradingReport
    private let market: MarketSnapshot
    private let calculator: GradeROICalculator = DefaultGradeROICalculator()

    init(report: GradingReport, market: MarketSnapshot) {
        self.report = report
        self.market = market
        self.result = DefaultGradeROICalculator().calculate(gradingReport: report, marketSnapshot: market, input: .default)
        self.outcomes = DefaultGradeROICalculator().outcomes(gradingReport: report, marketSnapshot: market, input: .default)
    }

    private func recalculate() {
        result = calculator.calculate(gradingReport: report, marketSnapshot: market, input: input)
        outcomes = calculator.outcomes(gradingReport: report, marketSnapshot: market, input: input)
    }
}

#Preview {
    NavigationStack {
        GradeROIView(
            card: MockSeedData.cards[0],
            report: MockSeedData.gradingReport(for: MockSeedData.cards[0].id),
            market: MockSeedData.marketSnapshot(for: MockSeedData.cards[0].id)
        )
    }
}
