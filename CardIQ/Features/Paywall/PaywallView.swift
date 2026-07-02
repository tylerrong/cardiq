import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var selectedPlan: String = "collector_pro"
    @State private var billingPeriod: BillingPeriod = .yearly
    @State private var isPurchasing = false

    enum BillingPeriod { case monthly, yearly }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CIQSpacing.xl) {
                    headerSection
                    billingToggle
                    plansSection
                    featuresComparison
                    legalSection
                }
                .padding(CIQSpacing.md)
            }
            .background(CIQColors.Fallback.backgroundPrimary)
            .navigationTitle("Upgrade")
            .ciqInlineTitle()
            .ciqNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: CIQSpacing.sm) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(CIQColors.Fallback.accentPrimary)
            Text("Unlock Full Grading Intelligence")
                .font(CIQFont.displayMedium)
                .foregroundStyle(CIQColors.Fallback.textPrimary)
                .multilineTextAlignment(.center)
            Text("Make smarter grading decisions with detailed analysis, ROI calculations, and market data.")
                .font(CIQFont.subheadline)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var billingToggle: some View {
        HStack(spacing: 0) {
            billingButton("Monthly", period: .monthly)
            billingButton("Yearly (Save 33%)", period: .yearly)
        }
        .background(CIQColors.Fallback.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))
    }

    private func billingButton(_ title: String, period: BillingPeriod) -> some View {
        Button {
            billingPeriod = period
        } label: {
            Text(title)
                .font(CIQFont.footnoteBold)
                .foregroundStyle(billingPeriod == period ? .black : CIQColors.Fallback.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CIQSpacing.sm)
                .background(billingPeriod == period ? CIQColors.Fallback.accentPrimary : .clear)
                .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))
        }
    }

    private var plansSection: some View {
        VStack(spacing: CIQSpacing.sm) {
            planCard(
                name: "Free",
                price: "$0",
                period: "",
                features: ["3 grading reports/month", "Basic market estimate", "Manual collection"],
                isSelected: selectedPlan == "free",
                isCurrent: true,
                action: { selectedPlan = "free" }
            )

            planCard(
                name: "Collector Pro",
                price: billingPeriod == .monthly ? "$14.99" : "$9.99",
                period: "/month",
                features: ["50 grading reports/month", "Full grading breakdown", "Grade ROI calculator", "Market charts & comps", "Collection valuation"],
                isSelected: selectedPlan == "collector_pro",
                isCurrent: false,
                action: { selectedPlan = "collector_pro" }
            )

            planCard(
                name: "Dealer",
                price: "",
                period: "",
                features: ["Bulk intake", "Max buy-price calc", "Inventory export", "Team accounts"],
                isSelected: false,
                isCurrent: false,
                isComingSoon: true,
                action: {}
            )

            if selectedPlan == "collector_pro" {
                CIQPrimaryButton(isPurchasing ? "Processing..." : "Subscribe Now") {
                    isPurchasing = true
                    Task {
                        // Mock purchase until StoreKit lands — but a real state
                        // change: the tier and scan allowance actually update.
                        _ = try? await ServiceContainer.shared.subscription.purchase(planId: selectedPlan)
                        await appState.refreshSubscription()
                        isPurchasing = false
                        dismiss()
                    }
                }
                .disabled(isPurchasing)
            }
        }
    }

    private func planCard(
        name: String, price: String, period: String,
        features: [String], isSelected: Bool, isCurrent: Bool,
        isComingSoon: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                HStack {
                    Text(name)
                        .font(CIQFont.headline)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                    if isCurrent {
                        CIQBadge(text: "Current", color: CIQColors.Fallback.textSecondary)
                    }
                    if isComingSoon {
                        CIQBadge(text: "Coming Soon", color: CIQColors.Fallback.warning)
                    }
                    Spacer()
                    if !price.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(price)
                                .font(CIQFont.displayMedium)
                                .foregroundStyle(CIQColors.Fallback.textPrimary)
                            Text(period)
                                .font(CIQFont.footnote)
                                .foregroundStyle(CIQColors.Fallback.textSecondary)
                        }
                    }
                }

                ForEach(features, id: \.self) { feature in
                    HStack(spacing: CIQSpacing.xs) {
                        Image(systemName: "checkmark")
                            .font(CIQFont.caption)
                            .foregroundStyle(CIQColors.Fallback.accentPrimary)
                        Text(feature)
                            .font(CIQFont.subheadline)
                            .foregroundStyle(CIQColors.Fallback.textSecondary)
                    }
                }
            }
            .padding(CIQSpacing.md)
            .background(CIQColors.Fallback.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: CIQRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: CIQRadius.card)
                    .strokeBorder(isSelected ? CIQColors.Fallback.accentPrimary : CIQColors.Fallback.borderSubtle, lineWidth: isSelected ? 2 : 1)
            )
        }
        .disabled(isComingSoon)
        .opacity(isComingSoon ? 0.6 : 1.0)
    }

    private var featuresComparison: some View {
        CIQCard {
            VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                Text("What's Included")
                    .font(CIQFont.headline)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)

                FeatureComparisonRow(feature: "Monthly Scans", free: "3", pro: "50")
                FeatureComparisonRow(feature: "Grading Breakdown", free: "Basic", pro: "Full")
                FeatureComparisonRow(feature: "Grade ROI", free: "—", pro: "✓")
                FeatureComparisonRow(feature: "Market Charts", free: "—", pro: "✓")
                FeatureComparisonRow(feature: "Comparable Sales", free: "—", pro: "✓")
                FeatureComparisonRow(feature: "Collection Valuation", free: "—", pro: "✓")
                FeatureComparisonRow(feature: "Export", free: "—", pro: "✓")
            }
        }
    }

    private var legalSection: some View {
        VStack(spacing: CIQSpacing.sm) {
            Button("Restore Purchases") {
            }
            .font(CIQFont.subheadline)
            .foregroundStyle(CIQColors.Fallback.accentPrimary)

            HStack(spacing: CIQSpacing.md) {
                Button("Terms of Service") {}
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
                Button("Privacy Policy") {}
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
            }

            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                .font(CIQFont.caption)
                .foregroundStyle(CIQColors.Fallback.textTertiary)
                .multilineTextAlignment(.center)
        }
    }
}

struct FeatureComparisonRow: View {
    let feature: String
    let free: String
    let pro: String

    var body: some View {
        HStack {
            Text(feature)
                .font(CIQFont.subheadline)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(free)
                .font(CIQFont.footnote)
                .foregroundStyle(CIQColors.Fallback.textTertiary)
                .frame(width: 50, alignment: .center)
            Text(pro)
                .font(CIQFont.footnoteBold)
                .foregroundStyle(CIQColors.Fallback.accentPrimary)
                .frame(width: 50, alignment: .center)
        }
    }
}

#Preview {
    PaywallView()
}
