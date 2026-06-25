import SwiftUI

struct CardArtworkView: View {
    let card: CardIdentity?
    var gradeBadge: String? = nil
    var recommendationBadge: GradeRecommendation? = nil
    var size: ArtworkSize = .medium

    enum ArtworkSize {
        case small
        case medium
        case large
        case hero

        var width: CGFloat? {
            switch self {
            case .small: 60
            case .medium: 100
            case .large: 150
            case .hero: nil
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: CIQRadius.xs
            case .medium: CIQRadius.sm
            case .large: CIQRadius.md
            case .hero: CIQRadius.lg
            }
        }

        var nameFont: Font {
            switch self {
            case .small: CIQFont.caption
            case .medium: CIQFont.footnote
            case .large: CIQFont.subheadline
            case .hero: CIQFont.headline
            }
        }

        var setCodeFont: Font {
            switch self {
            case .small: .system(size: 8, weight: .regular)
            case .medium: CIQFont.caption
            case .large: CIQFont.caption
            case .hero: CIQFont.footnote
            }
        }

        var gradeBadgeFont: Font {
            switch self {
            case .small: .system(size: 9, weight: .bold)
            case .medium: CIQFont.captionBold
            case .large: CIQFont.captionBold
            case .hero: CIQFont.footnoteBold
            }
        }

        var showSetCode: Bool {
            self != .small
        }

        var showRecommendation: Bool {
            switch self {
            case .small: false
            default: true
            }
        }
    }

    // MARK: - Rarity Gradient

    private var rarityGradient: LinearGradient {
        guard let card else {
            return LinearGradient(
                colors: [
                    CIQColors.Fallback.backgroundTertiary,
                    CIQColors.Fallback.backgroundCard
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        let colors: [Color]
        switch card.rarity {
        case .specialArt, .specialIllustrationRare:
            colors = [
                CIQColors.Fallback.accentPrimary.opacity(0.3),
                CIQColors.Fallback.accentSecondary.opacity(0.2),
                CIQColors.Fallback.backgroundCard
            ]
        case .fullArt, .altArt, .illustrationRare:
            colors = [
                Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.3),
                Color(red: 0.3, green: 0.15, blue: 0.5).opacity(0.2),
                CIQColors.Fallback.backgroundCard
            ]
        case .ultraRare, .secretRare, .hyperRare:
            colors = [
                CIQColors.Fallback.warning.opacity(0.25),
                Color(red: 0.8, green: 0.5, blue: 0.1).opacity(0.15),
                CIQColors.Fallback.backgroundCard
            ]
        case .holo, .reverseHolo, .trainerGallery:
            colors = [
                CIQColors.Fallback.accentPrimary.opacity(0.15),
                CIQColors.Fallback.backgroundTertiary,
                CIQColors.Fallback.backgroundCard
            ]
        default:
            colors = [
                CIQColors.Fallback.backgroundTertiary,
                CIQColors.Fallback.backgroundCard
            ]
        }

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Grade Badge Color

    private func gradeColor(for text: String) -> Color {
        let numericString = text
            .replacingOccurrences(of: "PSA ", with: "")
            .replacingOccurrences(of: "BGS ", with: "")
            .replacingOccurrences(of: "CGC ", with: "")
        guard let value = Double(numericString) else {
            return CIQColors.Fallback.accentPrimary
        }
        switch value {
        case 9.5...: return CIQColors.Fallback.accentPrimary
        case 9..<9.5: return CIQColors.Fallback.positive
        case 7..<9: return CIQColors.Fallback.warning
        default: return CIQColors.Fallback.negative
        }
    }

    // MARK: - Recommendation Helpers

    private func recommendationText(_ rec: GradeRecommendation) -> String {
        switch rec {
        case .grade: "GRADE"
        case .considerGrading: "CONSIDER"
        case .sellRaw: "SELL RAW"
        case .hold: "HOLD"
        case .insufficientData: "REVIEW"
        }
    }

    private func recommendationColor(_ rec: GradeRecommendation) -> Color {
        switch rec {
        case .grade: CIQColors.Fallback.accentPrimary
        case .considerGrading: CIQColors.Fallback.warning
        case .sellRaw: CIQColors.Fallback.warning
        case .hold: CIQColors.Fallback.textSecondary
        case .insufficientData: CIQColors.Fallback.textTertiary
        }
    }

    // MARK: - Body

    var body: some View {
        let content = cardContent
            .aspectRatio(5.0 / 7.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .strokeBorder(CIQColors.Fallback.borderSubtle, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                gradeBadgeOverlay
            }
            .overlay(alignment: .bottom) {
                recommendationBadgeOverlay
            }

        if let width = size.width {
            content.frame(width: width)
        } else {
            content
        }
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        if let imageURL = card?.imageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    fallbackView
                case .empty:
                    loadingView
                @unknown default:
                    fallbackView
                }
            }
        } else {
            fallbackView
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ZStack {
            rarityGradient
            ProgressView()
                .tint(CIQColors.Fallback.textTertiary)
        }
    }

    // MARK: - Fallback View

    private var fallbackView: some View {
        ZStack {
            rarityGradient

            // Holo shimmer overlay
            if card?.isHolo == true || card?.rarity == .holo || card?.rarity == .reverseHolo {
                holoShimmerOverlay
            }

            // Card info
            VStack(spacing: CIQSpacing.xs) {
                Spacer()

                if let card {
                    Text(card.name)
                        .font(size.nameFont)
                        .fontWeight(.semibold)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(size == .small ? 2 : 3)
                        .padding(.horizontal, CIQSpacing.xxs)
                } else {
                    Image(systemName: "rectangle.portrait")
                        .font(.system(size: size == .small ? 16 : 28))
                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                }

                Spacer()

                if size.showSetCode, let card {
                    Text(card.displayNumber)
                        .font(size.setCodeFont)
                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                        .padding(.bottom, CIQSpacing.xs)
                }
            }
            .padding(CIQSpacing.xxs)
        }
    }

    // MARK: - Holo Shimmer

    private var holoShimmerOverlay: some View {
        GeometryReader { geo in
            let stripeWidth = max(geo.size.width * 0.15, 8)
            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(0.08),
                    .white.opacity(0.15),
                    .white.opacity(0.08),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: stripeWidth)
            .rotationEffect(.degrees(-35))
            .offset(x: geo.size.width * 0.35, y: -geo.size.height * 0.1)
        }
        .clipped()
    }

    // MARK: - Grade Badge Overlay

    @ViewBuilder
    private var gradeBadgeOverlay: some View {
        if let gradeBadge {
            let color = gradeColor(for: gradeBadge)
            Text(gradeBadge)
                .font(size.gradeBadgeFont)
                .foregroundStyle(color)
                .padding(.horizontal, CIQSpacing.xs)
                .padding(.vertical, CIQSpacing.xxxs)
                .background(color.opacity(0.2))
                .clipShape(Capsule())
                .padding(CIQSpacing.xxs)
        }
    }

    // MARK: - Recommendation Badge Overlay

    @ViewBuilder
    private var recommendationBadgeOverlay: some View {
        if size.showRecommendation, let rec = recommendationBadge {
            let color = recommendationColor(rec)
            Text(recommendationText(rec))
                .font(CIQFont.captionBold)
                .foregroundStyle(color)
                .padding(.horizontal, CIQSpacing.xs)
                .padding(.vertical, CIQSpacing.xxxs)
                .background(color.opacity(0.15))
                .clipShape(Capsule())
                .padding(.bottom, CIQSpacing.xxs)
        }
    }
}

// MARK: - Previews

#Preview("Sizes") {
    let sampleCard = CardIdentity(
        id: "preview-1",
        category: .pokemon,
        name: "Charizard ex",
        setName: "Obsidian Flames",
        setCode: "OBF",
        cardNumber: "215",
        year: 2023,
        variant: nil,
        rarity: .specialArt,
        language: "EN",
        isFirstEdition: false,
        isHolo: true,
        isReverseHolo: false,
        imageURL: nil,
        identificationConfidence: 0.95
    )

    ScrollView {
        VStack(spacing: CIQSpacing.xl) {
            HStack(spacing: CIQSpacing.md) {
                CardArtworkView(card: sampleCard, gradeBadge: "9.5", size: .small)
                CardArtworkView(card: sampleCard, gradeBadge: "9.5", recommendationBadge: .grade, size: .medium)
                CardArtworkView(card: sampleCard, gradeBadge: "PSA 10", recommendationBadge: .grade, size: .large)
            }

            CardArtworkView(card: sampleCard, gradeBadge: "9.5", recommendationBadge: .grade, size: .hero)
                .padding(.horizontal, CIQSpacing.xxxl)

            CardArtworkView(card: nil, size: .medium)
        }
        .padding()
    }
    .background(CIQColors.Fallback.backgroundPrimary)
}
