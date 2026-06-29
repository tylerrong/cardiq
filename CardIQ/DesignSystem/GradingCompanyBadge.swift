import SwiftUI

/// Renders a grading company's logo (PSA / Beckett / CGC) on a white chip so the
/// colored marks read against the dark theme. Falls back to a text badge for
/// unknown companies or when the asset is missing.
struct GradingCompanyBadge: View {
    let company: String
    var height: CGFloat = 16

    private var assetName: String? {
        switch company.lowercased() {
        case "psa": "grading-psa"
        case "cgc": "grading-cgc"
        case "bgs", "beckett", "bvg": "grading-beckett"
        default: nil
        }
    }

    private var hasAsset: Bool {
        #if canImport(UIKit)
        if let assetName { return UIImage(named: assetName) != nil }
        return false
        #else
        return false
        #endif
    }

    var body: some View {
        if let assetName, hasAsset {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .padding(.horizontal, height * 0.4)
                .padding(.vertical, height * 0.28)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: CIQRadius.xs))
        } else {
            Text(company.uppercased())
                .font(.system(size: height * 0.78, weight: .bold, design: .rounded))
                .foregroundStyle(CIQColors.Fallback.textPrimary)
                .padding(.horizontal, CIQSpacing.xs)
                .padding(.vertical, CIQSpacing.xxxs)
                .background(CIQColors.Fallback.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: CIQRadius.xs))
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        GradingCompanyBadge(company: "PSA")
        GradingCompanyBadge(company: "BGS")
        GradingCompanyBadge(company: "CGC")
        GradingCompanyBadge(company: "SGC")
    }
    .padding()
    .background(CIQColors.Fallback.backgroundPrimary)
}
