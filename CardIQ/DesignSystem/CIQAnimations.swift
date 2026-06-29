import SwiftUI

struct CIQToast: View {
    let message: String
    let icon: String
    var color: Color = CIQColors.Fallback.positive

    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4)
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Text(message)
                .font(CIQFont.footnoteBold)
                .foregroundStyle(CIQColors.Fallback.textPrimary)
            Spacer()
        }
        .padding(.vertical, CIQSpacing.sm)
        .padding(.horizontal, CIQSpacing.md)
        .background(CIQColors.Fallback.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CIQRadius.md)
                .strokeBorder(CIQColors.Fallback.borderSubtle, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .padding(.horizontal, CIQSpacing.lg)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let icon: String
    var color: Color = CIQColors.Fallback.positive

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if isPresented {
                CIQToast(message: message, icon: icon, color: color)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                isPresented = false
                            }
                        }
                    }
                    .padding(.top, CIQSpacing.xs)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented)
    }
}

extension View {
    func ciqToast(isPresented: Binding<Bool>, message: String, icon: String = "checkmark.circle.fill", color: Color = CIQColors.Fallback.positive) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, icon: icon, color: color))
    }
}

struct AnimatedGradeCircle: View {
    let grade: Double
    let size: CGFloat
    @State private var animatedProgress: Double = 0
    @State private var displayedGrade: Double = 0
    @State private var showPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

            if showPulse {
                Circle()
                    .strokeBorder(gradeColor.opacity(0.3), lineWidth: 2)
                    .frame(width: size + 12, height: size + 12)
                    .scaleEffect(showPulse ? 1.15 : 1.0)
                    .opacity(showPulse ? 0 : 0.5)
            }

            Circle()
                .trim(from: 0, to: animatedProgress / 10)
                .stroke(gradeColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)

            Text(String(format: "%.1f", displayedGrade))
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundStyle(gradeColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: size * 0.84)
                .contentTransition(.numericText())
        }
        .onAppear {
            if reduceMotion {
                animatedProgress = grade
                displayedGrade = grade
                return
            }
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7).delay(0.2)) {
                animatedProgress = grade
            }
            animateCounter()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation(.easeOut(duration: 0.8)) {
                    showPulse = true
                }
            }
        }
        .accessibilityLabel("Estimated grade: \(String(format: "%.1f", grade))")
    }

    private func animateCounter() {
        let steps = 20
        let stepDuration = 1.0 / Double(steps)
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Double(i) * stepDuration) {
                let progress = Double(i) / Double(steps)
                let eased = 1 - pow(1 - progress, 3)
                displayedGrade = grade * eased
            }
        }
    }
}

struct AnimatedProgressBar: View {
    let value: Double
    let color: Color
    let height: CGFloat
    @State private var animatedValue: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    .frame(width: geo.size.width * min(max(animatedValue, 0), 1))
            }
        }
        .frame(height: height)
        .onAppear {
            if reduceMotion {
                animatedValue = value
                return
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { _, newVal in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animatedValue = newVal
            }
        }
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ShimmerView: View {
    @State private var phase: CGFloat = -1
    let height: CGFloat

    init(height: CGFloat = 20) {
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: CIQRadius.xs)
            .fill(CIQColors.Fallback.backgroundTertiary)
            .frame(height: height)
            .overlay {
                GeometryReader { geo in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, CIQColors.Fallback.backgroundSecondary.opacity(0.6), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * 0.4)
                        .offset(x: geo.size.width * phase)
                }
                .clipped()
            }
            .clipShape(RoundedRectangle(cornerRadius: CIQRadius.xs))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

struct CIQSkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CIQSpacing.sm) {
            ShimmerView(height: 140)
            ShimmerView(height: 16)
                .frame(width: 120)
            ShimmerView(height: 12)
                .frame(width: 80)
        }
        .padding(CIQSpacing.md)
        .background(CIQColors.Fallback.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.card))
    }
}

struct CIQSkeletonRow: View {
    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            ShimmerView(height: 60)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: CIQSpacing.xs) {
                ShimmerView(height: 14)
                    .frame(width: 140)
                ShimmerView(height: 10)
                    .frame(width: 90)
            }
            Spacer()
            ShimmerView(height: 14)
                .frame(width: 60)
        }
        .padding(CIQSpacing.sm)
        .background(CIQColors.Fallback.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.sm))
    }
}

struct AnimatedCounterText: View {
    let value: Double
    let format: CounterFormat
    @State private var displayedValue: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum CounterFormat {
        case currency, percent, number
    }

    var formattedText: String {
        switch format {
        case .currency: displayedValue.currencyFormatted
        case .percent: displayedValue.percentFormatted
        case .number: String(format: "%.1f", displayedValue)
        }
    }

    var body: some View {
        Text(formattedText)
            .onAppear {
                if reduceMotion {
                    displayedValue = value
                    return
                }
                animateCounter()
            }
            .onChange(of: value) { _, _ in
                animateCounter()
            }
    }

    private func animateCounter() {
        let start = displayedValue
        let steps = 25
        let duration = 0.8
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration * Double(i) / Double(steps)) {
                let progress = Double(i) / Double(steps)
                let eased = 1 - pow(1 - progress, 3)
                displayedValue = start + (value - start) * eased
            }
        }
    }
}

struct ScaleInModifier: ViewModifier {
    @State private var appeared = false
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared || reduceMotion ? 1.0 : 0.8)
            .opacity(appeared || reduceMotion ? 1.0 : 0)
            .onAppear {
                guard !reduceMotion else {
                    appeared = true
                    return
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) {
                    appeared = true
                }
            }
    }
}

struct SlideUpModifier: ViewModifier {
    @State private var appeared = false
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(y: appeared || reduceMotion ? 0 : 20)
            .opacity(appeared || reduceMotion ? 1.0 : 0)
            .onAppear {
                guard !reduceMotion else {
                    appeared = true
                    return
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func scaleIn(delay: Double = 0) -> some View {
        modifier(ScaleInModifier(delay: delay))
    }

    func slideUp(delay: Double = 0) -> some View {
        modifier(SlideUpModifier(delay: delay))
    }
}
