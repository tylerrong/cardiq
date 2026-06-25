import SwiftUI
import PhotosUI

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
                            InstructionsView(onStart: { viewModel.currentStep = .frontCapture })
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
                            if let card = viewModel.selectedCard,
                               let report = viewModel.gradingReport,
                               let market = viewModel.marketSnapshot {
                                GradeReportView(card: card, report: report, market: market, onDismiss: { dismiss() })
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
            CIQProgressBar(value: viewModel.currentStep.progress, height: 4)
            Text(viewModel.currentStep.title)
                .font(CIQFont.footnoteBold)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
        }
        .padding(.horizontal, CIQSpacing.md)
        .padding(.top, CIQSpacing.xs)
    }
}

struct InstructionsView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: CIQSpacing.xxl) {
            Spacer()
            Image(systemName: "viewfinder")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(CIQColors.Fallback.accentPrimary)

            VStack(spacing: CIQSpacing.sm) {
                Text("Scan Your Card")
                    .font(CIQFont.displayMedium)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)

                Text("For the best results:")
                    .font(CIQFont.body)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
            }

            VStack(alignment: .leading, spacing: CIQSpacing.md) {
                InstructionRow(icon: "light.max", text: "Use even, indirect lighting")
                InstructionRow(icon: "rectangle.portrait", text: "Remove the card from its sleeve")
                InstructionRow(icon: "circle.fill", text: "Place on a dark, flat surface")
                InstructionRow(icon: "hand.raised.slash", text: "Hold the phone steady")
                InstructionRow(icon: "arrow.up.left.and.arrow.down.right", text: "Fill the frame with the card")
            }

            Spacer()

            CIQPrimaryButton("Start Scanning", icon: "camera.fill", action: onStart)
                .padding(.horizontal, CIQSpacing.xl)
                .padding(.bottom, CIQSpacing.xxxl)
        }
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
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(spacing: CIQSpacing.md) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: CIQRadius.card)
                    .strokeBorder(CIQColors.Fallback.accentPrimary, style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .frame(width: 260, height: 364)
                    .accessibilityLabel("Card alignment guide")

                VStack(spacing: CIQSpacing.sm) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(CIQColors.Fallback.accentPrimary.opacity(0.6))
                    Text("Position card here")
                        .font(CIQFont.footnote)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                }
            }

            Text(instruction)
                .font(CIQFont.subheadline)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CIQSpacing.xxl)

            HStack(spacing: CIQSpacing.xs) {
                CIQBadge(text: "Lighting: Good", color: CIQColors.Fallback.positive)
                CIQBadge(text: "Stable", color: CIQColors.Fallback.positive)
            }

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
                        } else {
                            onCapture(Data("mock_image_from_picker".utf8))
                        }
                    }
                }

                Button {
                    onCapture(Data("mock_captured_image".utf8))
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
                } label: {
                    VStack(spacing: CIQSpacing.xxs) {
                        Image(systemName: "bolt.slash.fill")
                            .font(.system(size: 24))
                        Text("Flash")
                            .font(CIQFont.caption)
                    }
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                }
            }
            .padding(.bottom, CIQSpacing.xxxl)
        }
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

    var body: some View {
        ScrollView {
            VStack(spacing: CIQSpacing.lg) {
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
                ForEach(steps) { step in
                    HStack(spacing: CIQSpacing.sm) {
                        Group {
                            switch step.status {
                            case .completed:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(CIQColors.Fallback.positive)
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

                        Text(step.label)
                            .font(CIQFont.subheadline)
                            .foregroundStyle(
                                step.status == .pending ? CIQColors.Fallback.textTertiary : CIQColors.Fallback.textPrimary
                            )

                        Spacer()
                    }
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

struct ScanLaunchView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            VStack(spacing: CIQSpacing.lg) {
                CIQPrimaryButton("Start New Scan", icon: "camera.fill") {
                    appState.showScanner = true
                }
                .padding(.horizontal, CIQSpacing.md)
                .padding(.top, CIQSpacing.md)

                ScanHistoryView()
            }
            .background(CIQColors.Fallback.backgroundPrimary)
            .navigationTitle("Scan")
            .ciqNavigationBarStyle()
        }
    }
}

#Preview("Scanner Flow") {
    ScannerFlowView()
        .environment(AppState())
}

#Preview("Scan Launch") {
    ScanLaunchView()
        .environment(AppState())
}
