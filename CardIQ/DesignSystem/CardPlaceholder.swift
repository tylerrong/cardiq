import SwiftUI

struct CardPlaceholder: View {
    let card: CardIdentity?
    var size: PlaceholderSize = .medium

    enum PlaceholderSize {
        case small, medium, large

        var iconSize: CGFloat {
            switch self {
            case .small: 16
            case .medium: 28
            case .large: 48
            }
        }

        var fontSize: Font {
            switch self {
            case .small: CIQFont.caption
            case .medium: CIQFont.footnote
            case .large: CIQFont.subheadline
            }
        }
    }

    private var accentColor: Color {
        guard let card else { return CIQColors.Fallback.textTertiary }
        switch card.rarity {
        case .specialArt, .specialIllustrationRare, .hyperRare:
            return CIQColors.Fallback.accentPrimary
        case .fullArt, .altArt, .illustrationRare:
            return CIQColors.Fallback.accentSecondary
        case .ultraRare, .secretRare:
            return CIQColors.Fallback.warning
        default:
            return CIQColors.Fallback.textTertiary
        }
    }

    private var icon: String {
        guard let card else { return "rectangle.portrait" }
        if card.isHolo || card.rarity == .holo { return "sparkles" }
        if card.isReverseHolo { return "light.beacon.max" }
        switch card.rarity {
        case .specialArt, .specialIllustrationRare, .hyperRare, .fullArt, .altArt:
            return "star.fill"
        case .ultraRare, .secretRare:
            return "diamond.fill"
        case .illustrationRare, .trainerGallery:
            return "paintbrush.fill"
        default:
            return "rectangle.portrait"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CIQRadius.sm)
                .fill(CIQColors.Fallback.backgroundTertiary)
            VStack(spacing: size == .small ? 2 : CIQSpacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: size.iconSize))
                    .foregroundStyle(accentColor)
                if size != .small, let card {
                    Text(card.name)
                        .font(size.fontSize)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, CIQSpacing.xxs)
                }
            }
        }
    }
}
