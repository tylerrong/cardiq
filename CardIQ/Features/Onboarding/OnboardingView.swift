import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentPage = 0
    @State private var selectedType: CollectorType?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pages: [OnboardingPage] = [
        OnboardingPage(icon: "sparkles", title: "Welcome to CardIQ", subtitle: "AI-powered card grading intelligence at your fingertips.", color: CIQColors.Fallback.accentPrimary),
        OnboardingPage(icon: "viewfinder", title: "Scan & Identify", subtitle: "Point your camera at any modern Pokémon card for instant identification.", color: CIQColors.Fallback.accentPrimary),
        OnboardingPage(icon: "magnifyingglass", title: "Estimate Condition", subtitle: "Get detailed AI analysis of centering, corners, edges, and surface quality.", color: CIQColors.Fallback.accentSecondary),
        OnboardingPage(icon: "dollarsign.circle", title: "Know Before You Grade", subtitle: "Calculate whether professional grading will be profitable before you spend.", color: CIQColors.Fallback.positive),
        OnboardingPage(icon: "chart.line.uptrend.xyaxis", title: "Track Your Collection", subtitle: "Monitor portfolio value, track gains, and manage your entire collection.", color: CIQColors.Fallback.accentPrimary),
    ]

    private var totalPages: Int { pages.count + 1 }

    var body: some View {
        ZStack {
            CIQColors.Fallback.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }

                    CollectorTypeSelectionView(selectedType: $selectedType)
                        .tag(pages.count)
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .animation(reduceMotion ? .none : CIQAnimation.standard, value: currentPage)

                VStack(spacing: CIQSpacing.md) {
                    PageIndicator(current: currentPage, total: totalPages)

                    if currentPage == pages.count {
                        CIQPrimaryButton("Get Started", icon: "arrow.right") {
                            appState.completeOnboarding(type: selectedType ?? .casual)
                        }
                        .opacity(selectedType == nil ? 0.5 : 1.0)
                        .disabled(selectedType == nil)

                        Button("Skip for now") {
                            appState.completeOnboarding(type: selectedType ?? .casual)
                        }
                        .font(CIQFont.subheadline)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                    } else {
                        CIQPrimaryButton("Continue") {
                            withAnimation { currentPage += 1 }
                        }

                        if currentPage == 0 {
                            Button("I've used CardIQ before") {
                                appState.completeOnboarding(type: .casual)
                            }
                            .font(CIQFont.subheadline)
                            .foregroundStyle(CIQColors.Fallback.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, CIQSpacing.xl)
                .padding(.bottom, CIQSpacing.xxxl)
            }
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: CIQSpacing.xl) {
            Spacer()
            Image(systemName: page.icon)
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(page.color)
                .accessibilityHidden(true)

            VStack(spacing: CIQSpacing.sm) {
                Text(page.title)
                    .font(CIQFont.displayLarge)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(CIQFont.body)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, CIQSpacing.xl)
            }
            Spacer()
            Spacer()
        }
        .padding(CIQSpacing.xl)
    }
}

struct CollectorTypeSelectionView: View {
    @Binding var selectedType: CollectorType?

    var body: some View {
        VStack(spacing: CIQSpacing.xl) {
            Spacer()
            Text("What kind of collector are you?")
                .font(CIQFont.displayMedium)
                .foregroundStyle(CIQColors.Fallback.textPrimary)
                .multilineTextAlignment(.center)

            Text("We'll tailor your experience accordingly.")
                .font(CIQFont.body)
                .foregroundStyle(CIQColors.Fallback.textSecondary)

            VStack(spacing: CIQSpacing.sm) {
                ForEach(CollectorType.allCases, id: \.self) { type in
                    CollectorTypeCard(type: type, isSelected: selectedType == type) {
                        selectedType = type
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, CIQSpacing.xl)
    }
}

struct CollectorTypeCard: View {
    let type: CollectorType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: CIQSpacing.md) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? CIQColors.Fallback.accentPrimary : CIQColors.Fallback.textSecondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                    Text(type.displayName)
                        .font(CIQFont.headline)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                    Text(type.description)
                        .font(CIQFont.caption)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? CIQColors.Fallback.accentPrimary : CIQColors.Fallback.textTertiary)
                    .font(.system(size: 22))
            }
            .padding(CIQSpacing.md)
            .background(isSelected ? CIQColors.Fallback.accentPrimary.opacity(0.1) : CIQColors.Fallback.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: CIQRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: CIQRadius.card)
                    .strokeBorder(isSelected ? CIQColors.Fallback.accentPrimary : CIQColors.Fallback.borderSubtle, lineWidth: 1)
            )
        }
        .accessibilityLabel("\(type.displayName). \(type.description)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PageIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: CIQSpacing.xs) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? CIQColors.Fallback.accentPrimary : CIQColors.Fallback.textTertiary)
                    .frame(width: index == current ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
