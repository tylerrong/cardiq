import Foundation

/// What the user chose to scan. Drives how far the flow goes and which
/// results are produced.
enum ScanMode: String, Sendable {
    /// Front image only — identifies the card and its raw market value.
    case frontOnly
    /// Front + back — adds AI grading confidence on top of identification and value.
    case frontAndBack

    var title: String {
        switch self {
        case .frontOnly: "Front Only"
        case .frontAndBack: "Front & Back"
        }
    }

    var subtitle: String {
        switch self {
        case .frontOnly: "Identify the card and its market price"
        case .frontAndBack: "Adds AI grading confidence"
        }
    }

    var icon: String {
        switch self {
        case .frontOnly: "rectangle.portrait"
        case .frontAndBack: "rectangle.portrait.on.rectangle.portrait"
        }
    }

    /// Whether this mode runs the grading analysis (corners, edges, surface, grade).
    var includesGrading: Bool { self == .frontAndBack }
}

enum ScannerStep: Int, CaseIterable, Sendable {
    case instructions
    case frontCapture
    case frontReview
    case backCapture
    case backReview
    case optionalSurfaceCapture
    case processing
    case identificationConfirmation
    case complete
    case error

    var title: String {
        switch self {
        case .instructions: "Get Ready"
        case .frontCapture: "Front of Card"
        case .frontReview: "Review Front"
        case .backCapture: "Back of Card"
        case .backReview: "Review Back"
        case .optionalSurfaceCapture: "Surface Detail"
        case .processing: "Analyzing"
        case .identificationConfirmation: "Confirm Card"
        case .complete: "Results"
        case .error: "Error"
        }
    }

    var instruction: String {
        switch self {
        case .instructions: "Position the card on a dark, non-reflective surface with even lighting."
        case .frontCapture: "Align the front of the card within the guide. Hold steady."
        case .frontReview: "Review the captured image for clarity and coverage."
        case .backCapture: "Flip the card over. Align the back within the guide."
        case .backReview: "Review the back image for clarity and coverage."
        case .optionalSurfaceCapture: "Optional: Capture a close-up of the surface for detailed analysis."
        case .processing: "Analyzing your card..."
        case .identificationConfirmation: "Confirm the identified card."
        case .complete: "Analysis complete."
        case .error: "Something went wrong."
        }
    }

    /// Progress fraction for the bar, scaled to the active mode so front-only
    /// fills smoothly across its shorter flow instead of jumping.
    /// Identification + confirmation now happen right after the front capture,
    /// and `.processing` occurs twice — `identified` distinguishes the quick
    /// identify pass from the final analysis.
    func progress(for mode: ScanMode, identified: Bool = false) -> Double {
        switch mode {
        case .frontAndBack:
            switch self {
            case .instructions: 0
            case .frontCapture: 0.10
            case .frontReview: 0.20
            case .processing: identified ? 0.85 : 0.28
            case .identificationConfirmation: 0.35
            case .backCapture: 0.50
            case .backReview: 0.62
            case .optionalSurfaceCapture: 0.72
            case .complete: 1.0
            case .error: 0
            }
        case .frontOnly:
            // No back/surface steps in this flow.
            switch self {
            case .instructions: 0
            case .frontCapture: 0.2
            case .frontReview: 0.4
            case .processing: identified ? 0.8 : 0.5
            case .identificationConfirmation: 0.6
            case .complete: 1.0
            case .backCapture, .backReview, .optionalSurfaceCapture: 0.4
            case .error: 0
            }
        }
    }
}
