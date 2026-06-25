import SwiftUI

// MARK: - GradeBadge

struct GradeBadge: View {
    let grade: String

    private var gradeColor: Color {
        let numericString = grade
            .replacingOccurrences(of: "PSA ", with: "")
            .replacingOccurrences(of: "BGS ", with: "")
            .replacingOccurrences(of: "CGC ", with: "")
        guard let value = Double(numericString) else {
            return CIQColors.Fallback.accentPrimary
        }
        switch value {
        case 9.5...: return CIQColors.Fallback.accentPrimary
        case 8.5..<9.5: return CIQColors.Fallback.positive
        case 7..<8.5: return CIQColors.Fallback.warning
        default: return CIQColors.Fallback.negative
        }
    }

    var body: some View {
        Text(grade)
            .font(CIQFont.captionBold)
            .foregroundStyle(gradeColor)
            .padding(.horizontal, CIQSpacing.xs)
            .padding(.vertical, CIQSpacing.xxxs)
            .background(gradeColor.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - RecommendationBadge

struct RecommendationBadge: View {
    let recommendation: GradeRecommendation

    private var displayText: String {
        switch recommendation {
        case .grade: "GRADE"
        case .considerGrading: "CONSIDER"
        case .sellRaw: "SELL RAW"
        case .hold: "HOLD"
        case .insufficientData: "REVIEW"
        }
    }

    private var badgeColor: Color {
        switch recommendation {
        case .grade: CIQColors.Fallback.accentPrimary
        case .considerGrading: CIQColors.Fallback.warning
        case .sellRaw: CIQColors.Fallback.warning
        case .hold: CIQColors.Fallback.textSecondary
        case .insufficientData: CIQColors.Fallback.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: CIQSpacing.xxxs) {
            Image(systemName: recommendation.icon)
                .font(.system(size: 10))
            Text(displayText)
                .font(CIQFont.captionBold)
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, CIQSpacing.xs)
        .padding(.vertical, CIQSpacing.xxxs)
        .background(badgeColor.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - PriceChangeLabel

struct PriceChangeLabel: View {
    let percentageChange: Double

    private var isPositive: Bool {
        percentageChange >= 0
    }

    private var color: Color {
        isPositive ? CIQColors.Fallback.positive : CIQColors.Fallback.negative
    }

    private var arrowIcon: String {
        isPositive ? "arrow.up.right" : "arrow.down.right"
    }

    var body: some View {
        HStack(spacing: CIQSpacing.xxxs) {
            Image(systemName: arrowIcon)
                .font(.system(size: 10, weight: .bold))
            Text(String(format: "%@%.1f%%", isPositive ? "+" : "", percentageChange))
                .font(CIQFont.captionBold)
        }
        .foregroundStyle(color)
    }
}

// MARK: - DataFreshnessLabel

struct DataFreshnessLabel: View {
    let text: String
    var icon: String = "clock"

    var body: some View {
        HStack(spacing: CIQSpacing.xxxs) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(CIQFont.caption)
        }
        .foregroundStyle(CIQColors.Fallback.textTertiary)
    }
}

// MARK: - CIQRichSectionHeader

struct CIQRichSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(CIQFont.caption)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(CIQFont.subheadline)
                        .foregroundStyle(CIQColors.Fallback.accentPrimary)
                }
            }
        }
    }
}

// MARK: - FilterChipRow

struct FilterChipRow<T: Hashable>: View {
    @Binding var selected: T
    let options: [T]
    let label: (T) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CIQSpacing.xs) {
                ForEach(options, id: \.self) { option in
                    chipButton(for: option)
                }
            }
            .padding(.horizontal, CIQSpacing.md)
            .padding(.trailing, CIQSpacing.md)
        }
    }

    private func chipButton(for option: T) -> some View {
        let isActive = selected == option
        return Button {
            withAnimation(CIQAnimation.quick) {
                selected = option
            }
        } label: {
            Text(label(option))
                .font(CIQFont.captionBold)
                .foregroundStyle(
                    isActive
                        ? Color.black
                        : CIQColors.Fallback.textSecondary
                )
                .padding(.horizontal, CIQSpacing.sm)
                .padding(.vertical, CIQSpacing.xs)
                .background(
                    isActive
                        ? CIQColors.Fallback.accentPrimary
                        : CIQColors.Fallback.backgroundCard
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isActive
                                ? Color.clear
                                : CIQColors.Fallback.borderSubtle,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Badges") {
    VStack(spacing: CIQSpacing.md) {
        HStack(spacing: CIQSpacing.xs) {
            GradeBadge(grade: "PSA 10")
            GradeBadge(grade: "9.0")
            GradeBadge(grade: "7.5")
            GradeBadge(grade: "5.0")
        }

        HStack(spacing: CIQSpacing.xs) {
            RecommendationBadge(recommendation: .grade)
            RecommendationBadge(recommendation: .considerGrading)
            RecommendationBadge(recommendation: .sellRaw)
            RecommendationBadge(recommendation: .hold)
        }

        HStack(spacing: CIQSpacing.md) {
            PriceChangeLabel(percentageChange: 5.2)
            PriceChangeLabel(percentageChange: -3.1)
            PriceChangeLabel(percentageChange: 0.0)
        }

        DataFreshnessLabel(text: "Updated 8 min ago")
        DataFreshnessLabel(text: "Based on 34 sales", icon: "chart.bar")

        CIQRichSectionHeader(
            title: "Grading Opportunities",
            subtitle: "3 cards with grading upside",
            actionTitle: "See All",
            action: {}
        )
    }
    .padding()
    .background(CIQColors.Fallback.backgroundPrimary)
}
