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

    /// Identification runs right after the front is captured — for front+back
    /// scans the user confirms the card BEFORE flipping it, so a misread front
    /// never wastes a back capture.
    private func advanceAfterFront() {
        identifyFront()
    }

    private func identifyFront() {
        Task {
            currentStep = .processing
            isProcessing = true
            processingSteps = ProcessingStep.identifySteps
            await animateSteps()

            do {
                guard let frontData = frontImage else {
                    throw CIQError.poorImageQuality("Missing card image.")
                }
                let results = try await services.cardIdentification.identify(frontImage: frontData, backImage: nil)
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
    }

    func retakeFront() {
        frontImage = nil
        frontQuality = nil
        identificationResults = []
        selectedCard = nil
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

    /// Runs the paid analysis (grading + market) once captures are done. The
    /// card was already identified and confirmed after the front capture.
    func startProcessing() {
        Task {
            guard let card = selectedCard else {
                // Shouldn't happen — confirmation precedes the back capture —
                // but recover by re-identifying rather than dead-ending.
                identifyFront()
                return
            }
            let remaining = await services.subscription.remainingScans()
            if remaining <= 0 {
                showPaywall = true
                return
            }
            currentStep = .processing
            isProcessing = true
            processingSteps = ProcessingStep.steps(for: scanMode)
            await animateSteps()
            await finishAnalysis(card)
        }
    }

    private func animateSteps() async {
        for i in processingSteps.indices {
            try? await Task.sleep(for: .milliseconds(180))
            processingSteps[i].status = .completed
            if i + 1 < processingSteps.count {
                processingSteps[i + 1].status = .active
            }
        }
    }

    /// User confirmed the identified card. Front+back continues to the back
    /// capture; front-only goes straight to the (paid) market analysis.
    func confirmIdentification(_ card: CardIdentity) async {
        selectedCard = card
        if scanMode.includesGrading && backImage == nil {
            currentStep = .backCapture
            return
        }

        let remaining = await services.subscription.remainingScans()
        if remaining <= 0 {
            showPaywall = true
            return
        }
        currentStep = .processing
        isProcessing = true
        processingSteps = ProcessingStep.steps(for: scanMode)
        await animateSteps()
        await finishAnalysis(card)
    }

    private func finishAnalysis(_ card: CardIdentity) async {
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

            // Market data is a flaky external dependency — retry a couple times,
            // best-effort, so a transient outage never loses the scan.
            var market: MarketSnapshot?
            var marketError: Error?
            for attempt in 0..<3 {
                do {
                    market = try await services.marketData.snapshot(for: card.id)
                    marketError = nil
                    break
                } catch {
                    marketError = error
                    if attempt < 2 { try? await Task.sleep(for: .milliseconds(600)) }
                }
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

            // Front-only can still show the identified card without a price;
            // grading needs market for the report/ROI, so surface the error there.
            if market == nil && scanMode.includesGrading {
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

    /// Identification pass right after the front capture (free, on-device).
    static let identifySteps: [ProcessingStep] = [
        .init(id: "quality", label: "Checking image quality", icon: "photo.badge.checkmark", status: .active),
        .init(id: "identify", label: "Identifying card", icon: "magnifyingglass", status: .pending),
    ]

    /// Post-confirmation analysis: the card is already identified, so these
    /// are the grading/market steps only.
    static func steps(for mode: ScanMode) -> [ProcessingStep] {
        var steps = mode.includesGrading
            ? Array(allSteps.dropFirst(2))          // centering → ROI
            : Array(frontOnlySteps.dropFirst(2))    // market only
        if !steps.isEmpty { steps[0].status = .active }
        return steps
    }
}
