import Foundation
import Observation
import SwiftUI
import PhotosUI

@Observable
@MainActor
final class ScannerViewModel {
    var currentStep: ScannerStep = .instructions
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

    func capturedFront(_ imageData: Data) {
        frontImage = imageData
        currentStep = .frontReview
    }

    func assessFrontQuality() async {
        guard let data = frontImage else { return }
        do {
            frontQuality = try await services.imageQuality.assess(image: data, captureType: .front)
            if frontQuality?.passesMinimumQuality == true {
                currentStep = .backCapture
            }
        } catch {
            self.error = .poorImageQuality("Could not assess image quality.")
        }
    }

    func acceptFrontWithWarnings() {
        currentStep = .backCapture
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
            processingSteps = ProcessingStep.allSteps
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

            guard let frontData = frontImage, let backData = backImage else {
                throw CIQError.poorImageQuality("Missing card images.")
            }

            let results = try await services.cardIdentification.identify(frontImage: frontData, backImage: backData)
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
            guard let frontData = frontImage, let backData = backImage else {
                throw CIQError.poorImageQuality("Missing card images.")
            }

            let report = try await services.cardGrading.analyze(
                cardId: card.id,
                frontImage: frontData,
                backImage: backData,
                surfaceImage: surfaceImage
            )
            gradingReport = report

            let market = try await services.marketData.snapshot(for: card.id)
            marketSnapshot = market

            try await services.subscription.consumeScan()

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

    func retry() {
        error = nil
        currentStep = .instructions
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
}
