import SwiftUI

// The "what should I do with it" layer. Collectr/Holodex answer "what's it
// worth"; these views put a decision on every raw card — verdict chips on
// collection cells and a price ladder with a "your copy lands here" marker
// on the card page.

/// Computes the grading verdict for a collection item using the same ROI
/// calculator as the full report. Nil when the item is already graded or is
/// missing a condition read / pricing.
enum GradeVerdict {
    static func compute(for item: CollectionItem) -> GradeROIResult? {
        guard item.officialGrade == nil,
              let report = item.gradingReport,
              let market = item.marketSnapshot, market.rawEstimatedValue > 0
        else { return nil }
        var input = ROIInput.default
        input.purchasePrice = item.purchasePrice ?? 0
        return DefaultGradeROICalculator().calculate(gradingReport: report, marketSnapshot: market, input: input)
    }
}

/// Compact action chip: grade / hold / sell raw, with the expected profit
/// when grading pays.
struct VerdictChip: View {
    let roi: GradeROIResult

    private var color: Color {
        switch roi.recommendation {
        case .grade: CIQColors.Fallback.positive
        case .considerGrading: CIQColors.Fallback.accentPrimary
        case .sellRaw: CIQColors.Fallback.warning
        case .hold, .insufficientData: CIQColors.Fallback.textSecondary
        }
    }

    private var label: String {
        switch roi.recommendation {
        case .grade: "Grade \(roi.expectedProfit.wholeSignedCurrency)"
        case .considerGrading: "Consider Grading"
        case .sellRaw: "Sell Raw"
        case .hold: "Hold"
        case .insufficientData: "No Data"
        }
    }

    var body: some View {
        Text(label)
            .font(CIQFont.captionBold)
            .foregroundStyle(color)
            .padding(.horizontal, CIQSpacing.xs)
            .padding(.vertical, 3)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
            .lineLimit(1)
    }
}

/// The grade ladder: Raw → PSA 8 → 9 → 10 as bars proportional to price,
/// with a marker on the tier the predicted grade lands in — the generic price
/// table becomes a story about this specific copy.
struct GradeLadderView: View {
    let market: MarketSnapshot
    /// Predicted grade for the user's raw copy, when they own one.
    var predictedGrade: Double?

    private struct Rung: Identifiable {
        let id: String
        let value: Double
        let holdsPrediction: Bool
    }

    private var predictedTier: String? {
        guard let g = predictedGrade else { return nil }
        switch g {
        case 9.75...: return "PSA 10"
        case 9..<9.75: return "PSA 9"
        case 8..<9: return "PSA 8"
        default: return "Raw"
        }
    }

    private var rungs: [Rung] {
        [
            ("PSA 10", market.psa10EstimatedValue),
            ("PSA 9", market.psa9EstimatedValue),
            ("PSA 8", market.psa8EstimatedValue),
            ("Raw", market.rawEstimatedValue),
        ].map { Rung(id: $0.0, value: $0.1, holdsPrediction: $0.0 == predictedTier) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            HStack {
                Text("Grade Ladder")
                    .font(CIQFont.headline)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                Spacer()
                if let g = predictedGrade {
                    Text("Your copy: ~\(String(format: "%.1f", g))")
                        .font(CIQFont.captionBold)
                        .foregroundStyle(CIQColors.Fallback.accentPrimary)
                }
            }

            let maxValue = max(rungs.map(\.value).max() ?? 1, 1)
            ForEach(rungs) { rung in
                HStack(spacing: CIQSpacing.sm) {
                    Text(rung.id)
                        .font(rung.holdsPrediction ? CIQFont.captionBold : CIQFont.caption)
                        .foregroundStyle(rung.holdsPrediction ? CIQColors.Fallback.accentPrimary : CIQColors.Fallback.textSecondary)
                        .frame(width: 52, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(CIQColors.Fallback.backgroundTertiary)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(rung.holdsPrediction
                                      ? CIQColors.Fallback.accentPrimary
                                      : CIQColors.Fallback.accentPrimary.opacity(0.25))
                                .frame(width: max(geo.size.width * rung.value / maxValue, 6))
                        }
                    }
                    .frame(height: 14)

                    Text(rung.value.currencyFormatted)
                        .font(rung.holdsPrediction ? CIQFont.footnoteBold : CIQFont.footnote)
                        .foregroundStyle(rung.holdsPrediction ? CIQColors.Fallback.textPrimary : CIQColors.Fallback.textSecondary)
                        .frame(width: 86, alignment: .trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .overlay(alignment: .leading) {
                    if rung.holdsPrediction {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(CIQColors.Fallback.accentPrimary)
                            .frame(width: 3)
                            .offset(x: -CIQSpacing.sm)
                    }
                }
            }
        }
    }
}

private extension Double {
    /// "+$797" — whole-dollar signed amount for tight chips.
    var wholeSignedCurrency: String {
        let sign = self >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(self).rounded()))"
    }
}
