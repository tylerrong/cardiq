import Foundation

enum CIQError: Error, Sendable {
    case cameraUnavailable
    case permissionDenied(String)
    case identificationFailed
    case lowConfidenceMatch(Double)
    case poorImageQuality(String)
    case gradingServiceUnavailable
    case marketDataUnavailable
    case storageFailure(String)
    case subscriptionFailure(String)
    case networkTimeout
    case scanLimitReached
    case unknown(String)

    var userMessage: String {
        switch self {
        case .cameraUnavailable: "Camera Not Available"
        case .permissionDenied(let p): "\(p) Permission Required"
        case .identificationFailed: "Could Not Identify Card"
        case .lowConfidenceMatch: "Low Confidence Match"
        case .poorImageQuality: "Image Quality Too Low"
        case .gradingServiceUnavailable: "Grading Service Unavailable"
        case .marketDataUnavailable: "Market Data Unavailable"
        case .storageFailure: "Storage Error"
        case .subscriptionFailure: "Subscription Error"
        case .networkTimeout: "Connection Timed Out"
        case .scanLimitReached: "Scan Limit Reached"
        case .unknown: "Something Went Wrong"
        }
    }

    var recoverySuggestion: String {
        switch self {
        case .cameraUnavailable:
            "This device does not have a camera. You can import photos from your library instead."
        case .permissionDenied(let p):
            "Please grant \(p) access in Settings to continue."
        case .identificationFailed:
            "Try taking a clearer photo with better lighting, or search for the card manually."
        case .lowConfidenceMatch(let c):
            "The match confidence is \(Int(c * 100))%. Please verify the card details or search manually."
        case .poorImageQuality(let reason):
            reason
        case .gradingServiceUnavailable:
            "The grading analysis is temporarily unavailable. Please try again in a moment."
        case .marketDataUnavailable:
            "Market data could not be loaded. Check your connection and try again."
        case .storageFailure:
            "Could not save data. Please check available storage and try again."
        case .subscriptionFailure:
            "There was a problem with your subscription. Please try again or contact support."
        case .networkTimeout:
            "The request timed out. Please check your internet connection and try again."
        case .scanLimitReached:
            "You've used all your free scans this month. Upgrade to Collector Pro for more."
        case .unknown(let msg):
            msg.isEmpty ? "Please try again. If the problem persists, contact support." : msg
        }
    }

    var icon: String {
        switch self {
        case .cameraUnavailable: "camera.slash"
        case .permissionDenied: "lock.shield"
        case .identificationFailed: "magnifyingglass"
        case .lowConfidenceMatch: "exclamationmark.triangle"
        case .poorImageQuality: "photo.badge.exclamationmark"
        case .gradingServiceUnavailable: "server.rack"
        case .marketDataUnavailable: "chart.line.downtrend.xyaxis"
        case .storageFailure: "externaldrive.badge.exclamationmark"
        case .subscriptionFailure: "creditcard.trianglebadge.exclamationmark"
        case .networkTimeout: "wifi.exclamationmark"
        case .scanLimitReached: "lock.fill"
        case .unknown: "exclamationmark.circle"
        }
    }
}
