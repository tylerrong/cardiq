import Foundation
import Observation
import SwiftUI
import PhotosUI

@Observable
@MainActor
final class ScannerViewModel {
    var currentStep: ScannerStep = .instructions
    var scanMode: ScanMode = .frontAndBack
    var frontImage: Data?
    var backImage: Data?
    var surfaceImage: Data?
    var frontQuality: ImageQualityReport?
    var backQuality: ImageQualityReport?
    var identificationResults: [CardIdentity] = []
    var selectedCard: CardIdentity?
    var gradingReport: GradingReport?
    var marketSnapshot: MarketSnapshot?
    var error: CIQError?
    var showPaywall = false
    var processingSteps: [ProcessingStep] = []
    var isProcessing = false

    private let services: ServiceContainer

    init(services: ServiceContainer = .shared) {
        self.services = services
    }

    /// Entry point from the instructions screen — locks in the chosen mode.
    func start(mode: ScanMode) {
        scanMode = mode
        currentStep = .frontCapture
    }

    func capturedFront(_ imageData: Data) {
        frontImage = imageData
        currentStep = .frontReview
    }

    func assessFrontQuality() async {
        guard let data = frontImage else { return }
        do {
            frontQuality = try await services.imageQuality.assess(image: data, captureType: .front)
            if frontQuality?.passesMinimumQuality == true {
                advanceAfterFront()
            }
        } catch {
            self.error = .poorImageQuality("Could not assess image quality.")
        }
    }

    func acceptFrontWithWarnings() {
        advanceAfterFront()
    }

    /// Front-only jumps straight to analysis; front+back continues to the back capture.
    private func advanceAfterFront() {
        if scanMode.includesGrading {
            currentStep = .backCapture
        } else {
            startProcessing()
        }
    }

    func retakeFront() {
        frontImage = nil
        frontQuality = nil
        currentStep = .frontCapture
    }

    func capturedBack(_ imageData: Data) {
        backImage = imageData
        currentStep = .backReview
    }

    func assessBackQuality() async {
        guard let data = backImage else { return }
        do {
            backQuality = try await services.imageQuality.assess(image: data, captureType: .back)
            if backQuality?.passesMinimumQuality == true {
                currentStep = .optionalSurfaceCapture
            }
        } catch {
            self.error = .poorImageQuality("Could not assess image quality.")
        }
    }

    func acceptBackWithWarnings() {
        currentStep = .optionalSurfaceCapture
    }

    func retakeBack() {
        backImage = nil
        backQuality = nil
        currentStep = .backCapture
    }

    func capturedSurface(_ imageData: Data?) {
        surfaceImage = imageData
        startProcessing()
    }

    func skipSurface() {
        startProcessing()
    }

    func startProcessing() {
        Task {
            let remaining = await services.subscription.remainingScans()
            if remaining <= 0 {
                showPaywall = true
                return
            }
            currentStep = .processing
            isProcessing = true
            processingSteps = ProcessingStep.steps(for: scanMode)
            await runAnalysis()
        }
    }

    private func runAnalysis() async {
        do {
            for i in processingSteps.indices {
                try await Task.sleep(for: .milliseconds(180))
                processingSteps[i].status = .completed
                if i + 1 < processingSteps.count {
                    processingSteps[i + 1].status = .active
                }
            }

            guard let frontData = frontImage else {
                throw CIQError.poorImageQuality("Missing card image.")
            }

            let results = try await services.cardIdentification.identify(frontImage: frontData, backImage: backImage)
            guard !results.isEmpty else { throw CIQError.identificationFailed }
            identificationResults = results

            if let topMatch = results.first, topMatch.identificationConfidence >= 0.85 {
                selectedCard = topMatch
            }

            isProcessing = false
            currentStep = .identificationConfirmation
        } catch let e as CIQError {
            error = e
            isProcessing = false
            currentStep = .error
        } catch {
            self.error = .unknown(error.localizedDescription)
            isProcessing = false
            currentStep = .error
        }
    }

    func confirmIdentification(_ card: CardIdentity) async {
        selectedCard = card
        currentStep = .processing
        isProcessing = true

        do {
            guard let frontData = frontImage else {
                throw CIQError.poorImageQuality("Missing card image.")
            }

            // Grading confidence requires the back; front-only stops at value.
            if scanMode.includesGrading {
                gradingReport = try await services.cardGrading.analyze(
                    cardId: card.id,
                    frontImage: frontData,
                    backImage: backImage ?? frontData,
                    surfaceImage: surfaceImage
                )
            }

            // Market data is a flaky external dependency — fetch best-effort so an
            // outage never loses the scan (which we still want in the dataset).
            let market: MarketSnapshot?
            let marketError: Error?
            do {
                market = try await services.marketData.snapshot(for: card.id)
                marketError = nil
            } catch {
                market = nil
                marketError = error
            }
            marketSnapshot = market

            // Upload the captured images + persist the scan to the cloud (dataset +
            // cross-device history), regardless of whether market data loaded.
            ScanSync.record(
                mode: scanMode,
                card: card,
                report: gradingReport,
                market: market,
                front: frontImage,
                back: backImage,
                surface: surfaceImage
            )

            try await services.subscription.consumeScan()

            guard market != nil else {
                throw marketError ?? CIQError.unknown("Market data could not be loaded.")
            }

            isProcessing = false
            currentStep = .complete
        } catch let e as CIQError {
            error = e
            isProcessing = false
            currentStep = .error
        } catch {
            self.error = .unknown(error.localizedDescription)
            isProcessing = false
            currentStep = .error
        }
    }

    /// From a front-only result: keep the front shot, capture the back, and run grading.
    func upgradeToFullScan() {
        scanMode = .frontAndBack
        gradingReport = nil
        backImage = nil
        backQuality = nil
        surfaceImage = nil
        currentStep = .backCapture
    }

    func retry() {
        error = nil
        isProcessing = false
        frontImage = nil
        backImage = nil
        surfaceImage = nil
        identificationResults = []
        selectedCard = nil
        gradingReport = nil
        marketSnapshot = nil
        currentStep = .frontCapture
    }

    func useMockImages() {
        frontImage = Data("mock_front_image".utf8)
        backImage = Data("mock_back_image".utf8)
    }
}

struct ProcessingStep: Identifiable {
    let id: String
    let label: String
    let icon: String
    var status: StepStatus

    enum StepStatus {
        case pending, active, completed
    }

    static let allSteps: [ProcessingStep] = [
        .init(id: "quality", label: "Checking image quality", icon: "photo.badge.checkmark", status: .active),
        .init(id: "identify", label: "Identifying card", icon: "magnifyingglass", status: .pending),
        .init(id: "centering", label: "Measuring centering", icon: "crop", status: .pending),
        .init(id: "corners", label: "Inspecting corners", icon: "square.dashed", status: .pending),
        .init(id: "edges", label: "Inspecting edges", icon: "rectangle", status: .pending),
        .init(id: "surface", label: "Reviewing surface", icon: "eye", status: .pending),
        .init(id: "market", label: "Finding market sales", icon: "chart.bar", status: .pending),
        .init(id: "roi", label: "Calculating grading ROI", icon: "dollarsign.circle", status: .pending),
    ]

    /// Front-only skips the grading inspection steps — it only identifies and prices the card.
    static let frontOnlySteps: [ProcessingStep] = [
        .init(id: "quality", label: "Checking image quality", icon: "photo.badge.checkmark", status: .active),
        .init(id: "identify", label: "Identifying card", icon: "magnifyingglass", status: .pending),
        .init(id: "market", label: "Finding market sales", icon: "chart.bar", status: .pending),
    ]

    static func steps(for mode: ScanMode) -> [ProcessingStep] {
        mode.includesGrading ? allSteps : frontOnlySteps
    }
}
