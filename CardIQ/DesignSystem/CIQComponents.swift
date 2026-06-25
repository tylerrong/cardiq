import SwiftUI

struct CIQCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(CIQSpacing.md)
            .background(CIQColors.Fallback.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: CIQRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: CIQRadius.card)
                    .strokeBorder(CIQColors.Fallback.borderSubtle, lineWidth: 1)
            )
    }
}

struct CIQPrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: CIQSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(CIQFont.headline)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, CIQSpacing.md)
            .background(CIQColors.Fallback.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: CIQRadius.button))
        }
        .accessibilityLabel(title)
    }
}

struct CIQSecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: CIQSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
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
        .accessibilityLabel(title)
    }
}

struct CIQBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(CIQFont.captionBold)
            .foregroundStyle(color)
            .padding(.horizontal, CIQSpacing.xs)
            .padding(.vertical, CIQSpacing.xxxs)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

struct CIQProgressBar: View {
    let value: Double
    let color: Color
    let height: CGFloat

    init(value: Double, color: Color = CIQColors.Fallback.accentPrimary, height: CGFloat = 8) {
        self.value = value
        self.color = color
        self.height = height
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(CIQColors.Fallback.backgroundTertiary)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

struct CIQGradeCircle: View {
    let grade: Double
    let size: CGFloat

    var gradeColor: Color {
        switch grade {
        case 9.5...10: CIQColors.Fallback.accentPrimary
        case 8.5..<9.5: CIQColors.Fallback.positive
        case 7..<8.5: CIQColors.Fallback.warning
        default: CIQColors.Fallback.negative
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(gradeColor.opacity(0.2), lineWidth: 4)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: grade / 10)
                .stroke(gradeColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
            Text(String(format: "%.1f", grade))
                .font(size > 80 ? CIQFont.heroGrade : CIQFont.displayLarge)
                .foregroundStyle(gradeColor)
                .fontDesign(.rounded)
        }
    }
}

struct CIQMetricRow: View {
    let label: String
    let value: String
    let valueColor: Color

    init(_ label: String, value: String, valueColor: Color = CIQColors.Fallback.textPrimary) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }

    var body: some View {
        HStack {
            Text(label)
                .font(CIQFont.subheadline)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
            Spacer()
            Text(value)
                .font(CIQFont.bodyBold)
                .foregroundStyle(valueColor)
        }
    }
}

struct CIQSectionHeader: View {
    let title: String
    let action: (() -> Void)?

    init(_ title: String, action: (() -> Void)? = nil) {
        self.title = title
        self.action = action
    }

    var body: some View {
        HStack {
            Text(title)
                .font(CIQFont.headline)
                .foregroundStyle(CIQColors.Fallback.textPrimary)
            Spacer()
            if let action {
                Button("See All", action: action)
                    .font(CIQFont.subheadline)
                    .foregroundStyle(CIQColors.Fallback.accentPrimary)
            }
        }
    }
}

struct CIQEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(icon: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: CIQSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(CIQColors.Fallback.textTertiary)
            Text(title)
                .font(CIQFont.headline)
                .foregroundStyle(CIQColors.Fallback.textPrimary)
            Text(message)
                .font(CIQFont.subheadline)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                CIQPrimaryButton(actionTitle, action: action)
                    .frame(maxWidth: 200)
            }
        }
        .padding(CIQSpacing.xxxl)
    }
}

struct CIQErrorView: View {
    let error: CIQError
    let retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: CIQSpacing.md) {
            Image(systemName: error.icon)
                .font(.system(size: 40))
                .foregroundStyle(CIQColors.Fallback.negative)
            Text(error.userMessage)
                .font(CIQFont.headline)
                .foregroundStyle(CIQColors.Fallback.textPrimary)
                .multilineTextAlignment(.center)
            Text(error.recoverySuggestion)
                .font(CIQFont.subheadline)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
                .multilineTextAlignment(.center)
            if let retryAction {
                CIQPrimaryButton("Try Again", icon: "arrow.clockwise", action: retryAction)
                    .frame(maxWidth: 200)
            }
        }
        .padding(CIQSpacing.xxxl)
    }
}

struct CIQLoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: CIQSpacing.md) {
            ProgressView()
                .controlSize(.large)
                .tint(CIQColors.Fallback.accentPrimary)
            Text(message)
                .font(CIQFont.subheadline)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
        }
    }
}

struct CIQDisclaimerView: View {
    let text: String

    init(_ text: String = "This is an AI estimate, not an official grade. Results may vary from professional grading services.") {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: CIQSpacing.xs) {
            Image(systemName: "info.circle")
                .font(CIQFont.caption)
            Text(text)
                .font(CIQFont.caption)
        }
        .foregroundStyle(CIQColors.Fallback.textTertiary)
        .padding(CIQSpacing.sm)
        .background(CIQColors.Fallback.backgroundTertiary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))
    }
}
