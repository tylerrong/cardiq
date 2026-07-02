import SwiftUI
import PhotosUI
import ImageIO
#if canImport(UIKit)
import UIKit
#endif

struct ScannerFlowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ScannerViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                CIQColors.Fallback.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    if viewModel.currentStep != .complete {
                        scannerProgress
                    }

                    Group {
                        switch viewModel.currentStep {
                        case .instructions:
                            InstructionsView(onStart: { viewModel.start(mode: $0) })
                        case .frontCapture:
                            CaptureView(
                                title: "Front of Card",
                                instruction: ScannerStep.frontCapture.instruction,
                                onCapture: { viewModel.capturedFront($0) },
                                onImport: { viewModel.capturedFront($0) }
                            )
                        case .frontReview:
                            ImageReviewView(
                                imageData: viewModel.frontImage,
                                quality: viewModel.frontQuality,
                                side: "Front",
                                onAccept: { Task { await viewModel.assessFrontQuality() } },
                                onAcceptWithWarnings: { viewModel.acceptFrontWithWarnings() },
                                onRetake: { viewModel.retakeFront() }
                            )
                        case .backCapture:
                            CaptureView(
                                title: "Back of Card",
                                instruction: ScannerStep.backCapture.instruction,
                                onCapture: { viewModel.capturedBack($0) },
                                onImport: { viewModel.capturedBack($0) }
                            )
                        case .backReview:
                            ImageReviewView(
                                imageData: viewModel.backImage,
                                quality: viewModel.backQuality,
                                side: "Back",
                                onAccept: { Task { await viewModel.assessBackQuality() } },
                                onAcceptWithWarnings: { viewModel.acceptBackWithWarnings() },
                                onRetake: { viewModel.retakeBack() }
                            )
                        case .optionalSurfaceCapture:
                            SurfaceCaptureView(
                                onCapture: { viewModel.capturedSurface($0) },
                                onSkip: { viewModel.skipSurface() }
                            )
                        case .processing:
                            ProcessingView(steps: viewModel.processingSteps)
                        case .identificationConfirmation:
                            IdentificationView(
                                results: viewModel.identificationResults,
                                selectedCard: viewModel.selectedCard,
                                onConfirm: { card in Task { await viewModel.confirmIdentification(card) } }
                            )
                        case .complete:
                            if let card = viewModel.selectedCard {
                                if let report = viewModel.gradingReport,
                                   let market = viewModel.marketSnapshot {
                                    GradeReportView(card: card, report: report, market: market, onDismiss: { dismiss() })
                                } else {
                                    RawValueResultView(
                                        card: card,
                                        market: viewModel.marketSnapshot,
                                        onScanBack: { viewModel.upgradeToFullScan() },
                                        onDismiss: { dismiss() }
                                    )
                                }
                            }
                        case .error:
                            if let error = viewModel.error {
                                CIQErrorView(error: error) { viewModel.retry() }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if viewModel.currentStep != .complete {
                        Button("Close") { dismiss() }
                            .foregroundStyle(CIQColors.Fallback.textSecondary)
                    }
                }
            }
            .ciqNavigationBarStyle()
            .sheet(isPresented: $viewModel.showPaywall) {
                PaywallView()
            }
        }
    }

    private var scannerProgress: some View {
        VStack(spacing: CIQSpacing.xs) {
            CIQProgressBar(value: viewModel.currentStep.progress(for: viewModel.scanMode), height: 4)
            Text(viewModel.currentStep.title)
                .font(CIQFont.footnoteBold)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
        }
        .padding(.horizontal, CIQSpacing.md)
        .padding(.top, CIQSpacing.xs)
    }
}

struct InstructionsView: View {
    let onStart: (ScanMode) -> Void

    var body: some View {
        VStack(spacing: CIQSpacing.lg) {
            Spacer(minLength: 0)
            Image(systemName: "viewfinder")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(CIQColors.Fallback.accentPrimary)

            VStack(spacing: CIQSpacing.xs) {
                Text("Scan Your Card")
                    .font(CIQFont.displayMedium)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)

                Text("For the best results:")
                    .font(CIQFont.body)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
            }

            VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                InstructionRow(icon: "light.max", text: "Use even, indirect lighting")
                InstructionRow(icon: "rectangle.portrait", text: "Remove the card from its sleeve")
                InstructionRow(icon: "circle.fill", text: "Place on a dark, flat surface")
                InstructionRow(icon: "hand.raised.slash", text: "Hold the phone steady")
                InstructionRow(icon: "arrow.up.left.and.arrow.down.right", text: "Fill the frame with the card")
            }

            Spacer(minLength: 0)

            VStack(spacing: CIQSpacing.sm) {
                Text("What do you want to scan?")
                    .font(CIQFont.footnoteBold)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScanModeOption(mode: .frontOnly, isRecommended: false, action: { onStart(.frontOnly) })
                ScanModeOption(mode: .frontAndBack, isRecommended: true, action: { onStart(.frontAndBack) })
            }
            .padding(.horizontal, CIQSpacing.xl)
            .padding(.bottom, CIQSpacing.xxxl)
        }
    }
}

/// A tappable card representing one scan mode, shown at the bottom of the instructions screen.
struct ScanModeOption: View {
    let mode: ScanMode
    let isRecommended: Bool
    let action: () -> Void

    var body: some View {
        Button {
            CIQHaptics.tap()
            action()
        } label: {
            HStack(spacing: CIQSpacing.md) {
                Image(systemName: mode.icon)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(CIQColors.Fallback.accentPrimary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                    HStack(spacing: CIQSpacing.xs) {
                        Text(mode.title)
                            .font(CIQFont.bodyBold)
                            .foregroundStyle(CIQColors.Fallback.textPrimary)
                        if isRecommended {
                            CIQBadge(text: "Full Report", color: CIQColors.Fallback.accentPrimary)
                        }
                    }
                    Text(mode.subtitle)
                        .font(CIQFont.footnote)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
            }
            .padding(CIQSpacing.md)
            .background(CIQColors.Fallback.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: CIQRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: CIQRadius.card)
                    .strokeBorder(
                        isRecommended ? CIQColors.Fallback.accentPrimary.opacity(0.5) : CIQColors.Fallback.borderSubtle,
                        lineWidth: 1
                    )
            }
        }
        .accessibilityLabel("\(mode.title). \(mode.subtitle)")
    }
}

struct InstructionRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(CIQColors.Fallback.accentPrimary)
                .frame(width: 28)
            Text(text)
                .font(CIQFont.subheadline)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
        }
        .padding(.horizontal, CIQSpacing.xxl)
    }
}

struct CaptureView: View {
    let title: String
    let instruction: String
    let onCapture: (Data) -> Void
    let onImport: (Data) -> Void
    @State private var showFlash = false
    @State private var selectedPhoto: PhotosPickerItem?
    #if canImport(UIKit)
    @StateObject private var camera = CardCameraController()

    private var detectionColor: Color {
        switch camera.detection {
        case .searching: return CIQColors.Fallback.borderSubtle
        case .adjusting: return CIQColors.Fallback.warning
        case .ready: return CIQColors.Fallback.positive
        }
    }
    private var detectionText: String {
        switch camera.detection {
        case .searching: return "Point at a card"
        case .adjusting: return "Move closer and center the card"
        case .ready: return "Looks good — tap to capture"
        }
    }
    #endif

    private var flashIcon: String {
        #if canImport(UIKit)
        camera.torchOn ? "bolt.fill" : "bolt.slash.fill"
        #else
        "bolt.slash.fill"
        #endif
    }

    private var flashTint: Color {
        #if canImport(UIKit)
        camera.torchOn ? CIQColors.Fallback.accentPrimary : CIQColors.Fallback.textSecondary
        #else
        CIQColors.Fallback.textSecondary
        #endif
    }

    var body: some View {
        ZStack {
        VStack(spacing: CIQSpacing.md) {
            Spacer()

            ZStack {
                #if canImport(UIKit)
                CameraPreview(session: camera.session) { devicePoint in
                    CIQHaptics.tap()
                    camera.focus(at: devicePoint)
                }
                if camera.cameraUnavailable {
                    VStack(spacing: CIQSpacing.sm) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(CIQColors.Fallback.textTertiary)
                        Text("Camera Unavailable")
                            .font(CIQFont.footnoteBold)
                            .foregroundStyle(CIQColors.Fallback.textPrimary)
                        Text("Use Import below to add a photo of the card instead.")
                            .font(CIQFont.caption)
                            .foregroundStyle(CIQColors.Fallback.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, CIQSpacing.lg)
                    }
                } else {
                    CardAlignmentOverlay()
                }
                #else
                Color.black
                CardAlignmentOverlay()
                #endif
            }
            .frame(width: 260, height: 364)
            .clipShape(RoundedRectangle(cornerRadius: CIQRadius.lg))
            .overlay {
                #if canImport(UIKit)
                RoundedRectangle(cornerRadius: CIQRadius.lg)
                    .strokeBorder(detectionColor, lineWidth: 3)
                    .animation(.easeInOut(duration: 0.2), value: camera.detection)
                #endif
            }
            .accessibilityLabel("Card camera preview")

            Text(instruction)
                .font(CIQFont.subheadline)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CIQSpacing.xxl)

            #if canImport(UIKit)
            if !camera.cameraUnavailable {
                CIQBadge(text: detectionText, color: detectionColor)
            }
            #endif

            Spacer()

            HStack(spacing: CIQSpacing.xxl) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    VStack(spacing: CIQSpacing.xxs) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                        Text("Import")
                            .font(CIQFont.caption)
                    }
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                }
                .onChange(of: selectedPhoto) { _, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self) {
                            onImport(data)
                        }
                    }
                }

                Button {
                    CIQHaptics.tap()
                    showFlash = true
                    #if canImport(UIKit)
                    camera.capture()
                    #endif
                } label: {
                    Circle()
                        .fill(.white)
                        .frame(width: 72, height: 72)
                        .overlay {
                            Circle()
                                .strokeBorder(CIQColors.Fallback.accentPrimary, lineWidth: 3)
                                .frame(width: 64, height: 64)
                        }
                }
                .accessibilityLabel("Take photo")

                Button {
                    CIQHaptics.tap()
                    #if canImport(UIKit)
                    camera.toggleTorch()
                    #endif
                } label: {
                    VStack(spacing: CIQSpacing.xxs) {
                        Image(systemName: flashIcon)
                            .font(.system(size: 24))
                        Text("Flash")
                            .font(CIQFont.caption)
                    }
                    .foregroundStyle(flashTint)
                }
                .accessibilityLabel("Toggle flash")
            }
            .padding(.bottom, CIQSpacing.xxxl)
        }

        if showFlash {
            Color.white
                .ignoresSafeArea()
                .opacity(0.8)
                .allowsHitTesting(false)
        }
        }
        #if canImport(UIKit)
        .onAppear {
            camera.onCapture = { data in
                showFlash = false
                onCapture(data)
            }
            camera.onCaptureFailed = {
                showFlash = false
            }
            camera.start()
        }
        .onDisappear { camera.stop() }
        #endif
    }
}

struct SurfaceCaptureView: View {
    let onCapture: (Data?) -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: CIQSpacing.xl) {
            Spacer()
            Image(systemName: "eye.circle")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(CIQColors.Fallback.accentPrimary)

            VStack(spacing: CIQSpacing.sm) {
                Text("Surface Close-Up")
                    .font(CIQFont.displayMedium)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                Text("Optional: Take a close-up photo of the card surface to improve surface scoring accuracy.")
                    .font(CIQFont.subheadline)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, CIQSpacing.xl)

            Spacer()

            VStack(spacing: CIQSpacing.sm) {
                CIQPrimaryButton("Take Close-Up") {
                    onCapture(Data("mock_surface_image".utf8))
                }
                CIQSecondaryButton("Skip This Step", action: onSkip)
            }
            .padding(.horizontal, CIQSpacing.xl)
            .padding(.bottom, CIQSpacing.xxxl)
        }
    }
}

struct ImageReviewView: View {
    let imageData: Data?
    let quality: ImageQualityReport?
    let side: String
    let onAccept: () -> Void
    let onAcceptWithWarnings: () -> Void
    let onRetake: () -> Void

    private var capturedImage: CGImage? {
        guard let imageData,
              let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: CIQSpacing.lg) {
                Group {
                    if let capturedImage {
                        Image(decorative: capturedImage, scale: 1, orientation: .up)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: CIQRadius.card))
                    } else {
                        RoundedRectangle(cornerRadius: CIQRadius.card)
                            .fill(CIQColors.Fallback.backgroundTertiary)
                            .frame(height: 300)
                            .overlay {
                                VStack(spacing: CIQSpacing.xs) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 48))
                                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                                    Text("\(side) Image Captured")
                                        .font(CIQFont.footnote)
                                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                                }
                            }
                    }
                }
                .padding(.horizontal, CIQSpacing.md)

                if let quality {
                    qualitySection(quality)
                }

                VStack(spacing: CIQSpacing.sm) {
                    CIQPrimaryButton("Accept & Continue", action: onAccept)

                    if let quality, !quality.passesMinimumQuality, !quality.retakeInstructions.isEmpty {
                        CIQSecondaryButton("Accept Anyway", action: onAcceptWithWarnings)
                    }

                    Button("Retake Photo", action: onRetake)
                        .font(CIQFont.subheadline)
                        .foregroundStyle(CIQColors.Fallback.negative)
                }
                .padding(.horizontal, CIQSpacing.md)
                .padding(.bottom, CIQSpacing.xxxl)
            }
        }
    }

    @ViewBuilder
    private func qualitySection(_ quality: ImageQualityReport) -> some View {
        CIQCard {
            VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                HStack {
                    Text("Image Quality")
                        .font(CIQFont.headline)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                    Spacer()
                    CIQBadge(
                        text: quality.passesMinimumQuality ? "Pass" : "Retake Suggested",
                        color: quality.passesMinimumQuality ? CIQColors.Fallback.positive : CIQColors.Fallback.warning
                    )
                }

                HStack {
                    Text("Overall Score")
                        .font(CIQFont.subheadline)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                    Spacer()
                    Text("\(Int(quality.overallScore * 100))%")
                        .font(CIQFont.bodyBold)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                }

                CIQProgressBar(
                    value: quality.overallScore,
                    color: quality.passesMinimumQuality ? CIQColors.Fallback.positive : CIQColors.Fallback.warning
                )

                if !quality.retakeInstructions.isEmpty {
                    VStack(alignment: .leading, spacing: CIQSpacing.xs) {
                        Text("Suggestions")
                            .font(CIQFont.footnoteBold)
                            .foregroundStyle(CIQColors.Fallback.textSecondary)
                        ForEach(quality.retakeInstructions, id: \.self) { instruction in
                            HStack(alignment: .top, spacing: CIQSpacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(CIQFont.caption)
                                    .foregroundStyle(CIQColors.Fallback.warning)
                                Text(instruction)
                                    .font(CIQFont.footnote)
                                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                            }
                        }
                    }
                }

                HStack(spacing: CIQSpacing.lg) {
                    qualityIndicator("Blur", passed: !quality.isBlurry)
                    qualityIndicator("Glare", passed: !quality.hasGlare)
                    qualityIndicator("Cropped", passed: !quality.isCropped)
                    qualityIndicator("Sleeved", passed: !quality.isSleeved)
                }
            }
        }
        .padding(.horizontal, CIQSpacing.md)
    }

    private func qualityIndicator(_ label: String, passed: Bool) -> some View {
        VStack(spacing: CIQSpacing.xxxs) {
            Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(passed ? CIQColors.Fallback.positive : CIQColors.Fallback.negative)
            Text(label)
                .font(CIQFont.caption)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
        }
    }
}

struct ProcessingView: View {
    let steps: [ProcessingStep]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: CIQSpacing.xxl) {
            Spacer()

            if !reduceMotion {
                ProgressView()
                    .controlSize(.large)
                    .tint(CIQColors.Fallback.accentPrimary)
                    .scaleEffect(1.5)
            }

            Text("Analyzing Your Card")
                .font(CIQFont.displayMedium)
                .foregroundStyle(CIQColors.Fallback.textPrimary)

            VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    ProcessingStepRow(step: step)
                        .slideUp(delay: Double(index) * 0.08)
                }
            }
            .padding(.horizontal, CIQSpacing.xxxl)

            Spacer()

            CIQDisclaimerView()
                .padding(.horizontal, CIQSpacing.md)
                .padding(.bottom, CIQSpacing.xxl)
        }
    }
}

struct CardAlignmentOverlay: View {
    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cornerLength: CGFloat = 28
    private let lineWidth: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let color = CIQColors.Fallback.accentPrimary.opacity(breathing ? 0.9 : 0.5)

            ZStack {
                // Corner brackets
                Group {
                    cornerBracket(x: 0, y: 0, dx: 1, dy: 1)
                    cornerBracket(x: w, y: 0, dx: -1, dy: 1)
                    cornerBracket(x: 0, y: h, dx: 1, dy: -1)
                    cornerBracket(x: w, y: h, dx: -1, dy: -1)
                }
                .foregroundStyle(color)

                VStack(spacing: CIQSpacing.sm) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(CIQColors.Fallback.accentPrimary.opacity(0.4))
                    Text("Position card here")
                        .font(CIQFont.footnote)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    private func cornerBracket(x: CGFloat, y: CGFloat, dx: CGFloat, dy: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: x, y: y + dy * cornerLength))
            path.addLine(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + dx * cornerLength, y: y))
        }
        .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}

struct ProcessingStepRow: View {
    let step: ProcessingStep

    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            Group {
                switch step.status {
                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(CIQColors.Fallback.positive)
                        .transition(.scale.combined(with: .opacity))
                case .active:
                    ProgressView()
                        .controlSize(.small)
                        .tint(CIQColors.Fallback.accentPrimary)
                case .pending:
                    Image(systemName: "circle")
                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                }
            }
            .frame(width: 22)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: step.status == .completed)

            Text(step.label)
                .font(CIQFont.subheadline)
                .foregroundStyle(
                    step.status == .pending ? CIQColors.Fallback.textTertiary : CIQColors.Fallback.textPrimary
                )
                .animation(.easeInOut(duration: 0.2), value: step.status == .pending)

            Spacer()
        }
    }
}

#Preview("Scanner Flow") {
    ScannerFlowView()
        .environment(AppState())
}
