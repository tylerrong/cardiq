import SwiftUI
import SwiftData

struct GradeReportView: View {
    let card: CardIdentity
    let report: GradingReport
    let market: MarketSnapshot
    var onDismiss: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @State private var showROI = false
    @State private var selectedDefect: DetectedDefect?
    @State private var savedToCollection = false
    @State private var hasSavedScanRecord = false

    @State private var showToast = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: CIQSpacing.lg) {
                    gradeHeader
                    CIQDisclaimerView()
                        .slideUp(delay: 1.2)
                    probabilitiesSection
                        .slideUp(delay: 1.4)
                    categoryScoresSection
                        .slideUp(delay: 1.6)
                    centeringSection
                        .slideUp(delay: 1.8)
                    if !report.detectedDefects.isEmpty {
                        defectsSection
                            .slideUp(delay: 2.0)
                    }
                    holdingBackSection
                        .slideUp(delay: 2.2)
                    marketQuickView
                        .slideUp(delay: 2.4)
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
        .sheet(isPresented: $showROI) {
            NavigationStack {
                GradeROIView(card: card, report: report, market: market)
            }
        }
        .sheet(item: $selectedDefect) { defect in
            DefectDetailSheet(defect: defect)
                .presentationDetents([.medium])
        }
        .task {
            CIQHaptics.success()
            guard !hasSavedScanRecord else { return }
            let record = ScanRecord(cardIdentity: card, gradingReport: report, marketSnapshot: market)
            modelContext.insert(record)
            try? modelContext.save()
            hasSavedScanRecord = true
        }
        .ciqToast(isPresented: $showToast, message: "Saved to collection")
    }

    private var gradeHeader: some View {
        CIQCard {
            VStack(spacing: CIQSpacing.md) {
                AnimatedGradeCircle(grade: report.estimatedGrade, size: 140)

                Text(report.gradeDescriptor)
                    .font(CIQFont.title)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                    .slideUp(delay: 0.8)

                HStack(spacing: CIQSpacing.sm) {
                    CIQBadge(text: "PSA Scale", color: CIQColors.Fallback.textSecondary)
                    CIQBadge(
                        text: "\(Int(report.confidence * 100))% confidence",
                        color: report.confidence >= 0.8 ? CIQColors.Fallback.positive : CIQColors.Fallback.warning
                    )
                }
                .slideUp(delay: 1.0)

                Text("\(card.setName) · \(card.displayNumber)")
                    .font(CIQFont.footnote)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
            }
        }
    }

    private var probabilitiesSection: some View {
        CIQCard {
            VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                Text("Grade Probabilities")
                    .font(CIQFont.headline)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)

                ProbabilityBar(label: "PSA 10", probability: report.psa10Probability, color: CIQColors.Fallback.accentPrimary)
                ProbabilityBar(label: "PSA 9", probability: report.psa9Probability, color: CIQColors.Fallback.positive)
                ProbabilityBar(label: "PSA 8", probability: report.psa8Probability, color: CIQColors.Fallback.warning)
                ProbabilityBar(label: "PSA 7-", probability: report.psa7OrLowerProbability, color: CIQColors.Fallback.negative)
            }
        }
    }

    private var categoryScoresSection: some View {
        CIQCard {
            VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                Text("Category Scores")
                    .font(CIQFont.headline)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)

                CategoryScoreRow(label: "Centering", score: centeringScore, maxScore: 10)
                CategoryScoreRow(label: "Corners", score: report.cornerScore, maxScore: 10)
                CategoryScoreRow(label: "Edges", score: report.edgeScore, maxScore: 10)
                CategoryScoreRow(label: "Surface", score: report.surfaceScore, maxScore: 10)
                CategoryScoreRow(label: "Print Quality", score: report.printQualityScore, maxScore: 10)
            }
        }
    }

    private var centeringScore: Double {
        let hDiff = abs(report.frontCenteringHorizontal - 0.5)
        let vDiff = abs(report.frontCenteringVertical - 0.5)
        return max(5, 10 - (hDiff + vDiff) * 20)
    }

    private var centeringSection: some View {
        CIQCard {
            VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                Text("Centering Measurements")
                    .font(CIQFont.headline)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)

                HStack(spacing: CIQSpacing.xl) {
                    VStack(alignment: .leading, spacing: CIQSpacing.xs) {
                        Text("Front")
                            .font(CIQFont.footnoteBold)
                            .foregroundStyle(CIQColors.Fallback.textSecondary)
                        CenteringDisplay(label: "Horizontal", value: report.frontCenteringHorizontal)
                        CenteringDisplay(label: "Vertical", value: report.frontCenteringVertical)
                    }
                    VStack(alignment: .leading, spacing: CIQSpacing.xs) {
                        Text("Back")
                            .font(CIQFont.footnoteBold)
                            .foregroundStyle(CIQColors.Fallback.textSecondary)
                        CenteringDisplay(label: "Horizontal", value: report.backCenteringHorizontal)
                        CenteringDisplay(label: "Vertical", value: report.backCenteringVertical)
                    }
                }

                HStack(spacing: CIQSpacing.xs) {
                    Image(systemName: "info.circle")
                        .font(CIQFont.caption)
                    Text("PSA 10 requires 55/45 or better centering on front; 75/25 on back.")
                        .font(CIQFont.caption)
                }
                .foregroundStyle(CIQColors.Fallback.textTertiary)
            }
        }
    }

    private var defectsSection: some View {
        CIQCard {
            VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                Text("Detected Issues")
                    .font(CIQFont.headline)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)

                ForEach(report.detectedDefects) { defect in
                    Button { selectedDefect = defect } label: {
                        HStack(spacing: CIQSpacing.sm) {
                            Image(systemName: defect.type.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(defect.severity == .severe ? CIQColors.Fallback.negative : CIQColors.Fallback.warning)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                                Text(defect.type.displayName)
                                    .font(CIQFont.bodyBold)
                                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                                Text(defect.locationDescription)
                                    .font(CIQFont.caption)
                                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                            }

                            Spacer()

                            CIQBadge(
                                text: defect.severity.displayName,
                                color: defect.severity == .severe ? CIQColors.Fallback.negative : CIQColors.Fallback.warning
                            )

                            Image(systemName: "chevron.right")
                                .font(CIQFont.caption)
                                .foregroundStyle(CIQColors.Fallback.textTertiary)
                        }
                        .padding(CIQSpacing.sm)
                        .background(CIQColors.Fallback.backgroundTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))
                    }
                }
            }
        }
    }

    private var holdingBackSection: some View {
        CIQCard {
            VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                HStack(spacing: CIQSpacing.xs) {
                    Image(systemName: "exclamationmark.bubble")
                        .foregroundStyle(CIQColors.Fallback.warning)
                    Text("What is holding this card back?")
                        .font(CIQFont.headline)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                }

                Text(report.explanation)
                    .font(CIQFont.subheadline)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var marketQuickView: some View {
        CIQCard {
            VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                Text("Market Values")
                    .font(CIQFont.headline)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)

                CIQMetricRow("Raw", value: market.rawEstimatedValue.currencyFormatted)
                CIQMetricRow("PSA 8", value: market.psa8EstimatedValue.currencyFormatted)
                CIQMetricRow("PSA 9", value: market.psa9EstimatedValue.currencyFormatted)
                CIQMetricRow("PSA 10", value: market.psa10EstimatedValue.currencyFormatted, valueColor: CIQColors.Fallback.accentPrimary)

                CIQDisclaimerView("Market values are estimates based on recent sales data.")
            }
        }
    }

    private var stickyBottomBar: some View {
        VStack(spacing: 0) {
            Divider().background(CIQColors.Fallback.border)
            VStack(spacing: CIQSpacing.xs) {
                CIQPrimaryButton("View Grading ROI", icon: "dollarsign.circle") {
                    showROI = true
                }
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
                            item.gradingReport = report
                            item.marketSnapshot = market
                            modelContext.insert(item)
                            try? modelContext.save()
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

                    ShareLink(item: gradeReportShareText) {
                        HStack(spacing: CIQSpacing.xxs) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(CIQFont.footnoteBold)
                        .foregroundStyle(CIQColors.Fallback.accentPrimary)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(CIQSpacing.md)
            .background(CIQColors.Fallback.backgroundPrimary)
        }
    }

    private var gradeReportShareText: String {
        let grade = String(format: "%.1f", report.estimatedGrade)
        return """
        CardIQ Grade Report: \(card.name)
        \(card.setName) · \(card.displayNumber)

        Estimated Grade: \(grade) (\(report.gradeDescriptor))
        Confidence: \(Int(report.confidence * 100))%

        Centering: \(report.centeringDescription)
        Corners: \(String(format: "%.1f", report.cornerScore))
        Edges: \(String(format: "%.1f", report.edgeScore))
        Surface: \(String(format: "%.1f", report.surfaceScore))

        Raw Value: \(market.rawEstimatedValue.currencyFormatted)
        PSA 10 Value: \(market.psa10EstimatedValue.currencyFormatted)

        ⚠️ AI estimate, not an official grade.
        """
    }
}

struct ProbabilityBar: View {
    let label: String
    let probability: Double
    let color: Color

    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            Text(label)
                .font(CIQFont.footnoteBold)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
                .frame(width: 55, alignment: .leading)

            AnimatedProgressBar(value: probability, color: color, height: 12)

            Text("\(Int(probability * 100))%")
                .font(CIQFont.monoLarge)
                .foregroundStyle(CIQColors.Fallback.textPrimary)
                .frame(width: 50, alignment: .trailing)
        }
        .accessibilityLabel("\(label): \(Int(probability * 100)) percent")
    }
}

struct CategoryScoreRow: View {
    let label: String
    let score: Double
    let maxScore: Double

    private var color: Color {
        switch score {
        case 9.5...10: CIQColors.Fallback.accentPrimary
        case 8.5..<9.5: CIQColors.Fallback.positive
        case 7..<8.5: CIQColors.Fallback.warning
        default: CIQColors.Fallback.negative
        }
    }

    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            Text(label)
                .font(CIQFont.subheadline)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
                .frame(width: 100, alignment: .leading)

            AnimatedProgressBar(value: score / maxScore, color: color, height: 8)

            Text(String(format: "%.1f", score))
                .font(CIQFont.monoLarge)
                .foregroundStyle(color)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

struct CenteringDisplay: View {
    let label: String
    let value: Double

    private var formatted: String {
        let pct = Int(value * 100)
        return "\(pct)/\(100 - pct)"
    }

    private var isWithinTolerance: Bool {
        abs(value - 0.5) <= 0.05
    }

    var body: some View {
        HStack(spacing: CIQSpacing.xs) {
            Text(label)
                .font(CIQFont.footnote)
                .foregroundStyle(CIQColors.Fallback.textTertiary)
            Text(formatted)
                .font(CIQFont.mono)
                .foregroundStyle(isWithinTolerance ? CIQColors.Fallback.positive : CIQColors.Fallback.warning)
        }
    }
}

struct DefectDetailSheet: View {
    let defect: DetectedDefect
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CIQSpacing.lg) {
                    HStack(spacing: CIQSpacing.sm) {
                        Image(systemName: defect.type.icon)
                            .font(.system(size: 32))
                            .foregroundStyle(defect.severity == .severe ? CIQColors.Fallback.negative : CIQColors.Fallback.warning)

                        VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                            Text(defect.type.displayName)
                                .font(CIQFont.title)
                                .foregroundStyle(CIQColors.Fallback.textPrimary)
                            CIQBadge(
                                text: defect.severity.displayName,
                                color: defect.severity == .severe ? CIQColors.Fallback.negative : CIQColors.Fallback.warning
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: CIQSpacing.xs) {
                        CIQMetricRow("Confidence", value: "\(Int(defect.confidence * 100))%")
                        CIQMetricRow("Location", value: defect.locationDescription)
                    }

                    VStack(alignment: .leading, spacing: CIQSpacing.xs) {
                        Text("Explanation")
                            .font(CIQFont.headline)
                            .foregroundStyle(CIQColors.Fallback.textPrimary)
                        Text(defect.explanation)
                            .font(CIQFont.body)
                            .foregroundStyle(CIQColors.Fallback.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(CIQSpacing.lg)
            }
            .background(CIQColors.Fallback.backgroundPrimary)
            .navigationTitle("Defect Detail")
            .ciqInlineTitle()
            .ciqNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(CIQColors.Fallback.accentPrimary)
                }
            }
        }
    }
}

#Preview("Grade Report") {
    NavigationStack {
        GradeReportView(
            card: MockSeedData.cards[0],
            report: MockSeedData.gradingReport(for: MockSeedData.cards[0].id),
            market: MockSeedData.marketSnapshot(for: MockSeedData.cards[0].id)
        )
    }
}
