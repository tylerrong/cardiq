import SwiftUI

struct IdentificationView: View {
    let results: [CardIdentity]
    let selectedCard: CardIdentity?
    let onConfirm: (CardIdentity) -> Void
    /// Confirm button label — "Confirm & Scan Back" when the back capture
    /// still follows, so the user knows what's next.
    var confirmLabel: String = "Confirm This Card"
    /// Escape hatch when the photo itself was the problem.
    var onRetake: (() -> Void)?
    @State private var searchText = ""
    @State private var showManualEntry = false
    @State private var showAlternatives = false

    private var filteredResults: [CardIdentity] {
        if searchText.isEmpty { return results }
        let query = searchText.lowercased()
        return results.filter {
            $0.name.lowercased().contains(query) ||
            $0.setName.lowercased().contains(query) ||
            $0.cardNumber.lowercased().contains(query)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: CIQSpacing.lg) {
                    if !showAlternatives, let card = selectedCard ?? results.first {
                        topMatchSection(card)
                    }

                    if results.count > 1 || showAlternatives {
                        alternativeMatchesSection
                            .id("alternatives")
                    }
                }
                .padding(CIQSpacing.md)
            }
            .onChange(of: showAlternatives) { _, show in
                if show {
                    withAnimation {
                        proxy.scrollTo("alternatives", anchor: .top)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func topMatchSection(_ card: CardIdentity) -> some View {
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
                    if let variant = card.variant {
                        CIQMetricRow("Variant", value: variant)
                    }
                }

                if card.identificationConfidence < 0.85 {
                    HStack(spacing: CIQSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(CIQColors.Fallback.warning)
                        Text("Low confidence match. Please verify this is the correct card.")
                            .font(CIQFont.footnote)
                            .foregroundStyle(CIQColors.Fallback.warning)
                    }
                    .padding(CIQSpacing.sm)
                    .background(CIQColors.Fallback.warning.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))
                }

                CIQPrimaryButton(confirmLabel, icon: "checkmark") {
                    onConfirm(card)
                }

                HStack(spacing: CIQSpacing.lg) {
                    Button("Not this card") {
                        withAnimation { showAlternatives = true }
                    }
                    if let onRetake {
                        Button("Retake photo", action: onRetake)
                    }
                }
                .font(CIQFont.subheadline)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
            }
        }
    }

    private var alternativeMatchesSection: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            CIQSectionHeader("Alternative Matches")

            TextField("Search cards...", text: $searchText)
                .font(CIQFont.body)
                .padding(CIQSpacing.sm)
                .background(CIQColors.Fallback.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))
                .foregroundStyle(CIQColors.Fallback.textPrimary)

            let displayResults = showAlternatives ? Array(filteredResults) : Array(filteredResults.dropFirst().prefix(4))
            ForEach(displayResults) { card in
                Button { onConfirm(card) } label: {
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

                        Text("\(Int(card.identificationConfidence * 100))%")
                            .font(CIQFont.footnoteBold)
                            .foregroundStyle(CIQColors.Fallback.textSecondary)

                        Image(systemName: "chevron.right")
                            .font(CIQFont.caption)
                            .foregroundStyle(CIQColors.Fallback.textTertiary)
                    }
                    .padding(CIQSpacing.sm)
                    .background(CIQColors.Fallback.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))
                }
            }
        }
    }
}

#Preview {
    IdentificationView(
        results: Array(MockSeedData.cards.prefix(5)),
        selectedCard: MockSeedData.cards[0],
        onConfirm: { _ in }
    )
    .background(CIQColors.Fallback.backgroundPrimary)
}
