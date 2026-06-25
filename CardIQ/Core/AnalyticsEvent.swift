import Foundation

enum AnalyticsEvent: Sendable {
    case onboardingStarted
    case onboardingCompleted(collectorType: String)
    case scanStarted
    case frontCaptureCompleted
    case backCaptureCompleted
    case imageRetakeRequested(reason: String)
    case cardIdentified(cardId: String, confidence: Double)
    case cardIdentificationCorrected(originalId: String, correctedId: String)
    case gradeReportViewed(cardId: String, estimatedGrade: Double)
    case gradeROIViewed(cardId: String)
    case cardSaved(cardId: String)
    case paywallViewed(source: String)
    case subscriptionStarted(tier: String)
    case officialGradeAdded(cardId: String, predicted: Double, official: Double)
    case reportShared(cardId: String)

    var name: String {
        switch self {
        case .onboardingStarted: "onboarding_started"
        case .onboardingCompleted: "onboarding_completed"
        case .scanStarted: "scan_started"
        case .frontCaptureCompleted: "front_capture_completed"
        case .backCaptureCompleted: "back_capture_completed"
        case .imageRetakeRequested: "image_retake_requested"
        case .cardIdentified: "card_identified"
        case .cardIdentificationCorrected: "card_identification_corrected"
        case .gradeReportViewed: "grade_report_viewed"
        case .gradeROIViewed: "grade_roi_viewed"
        case .cardSaved: "card_saved"
        case .paywallViewed: "paywall_viewed"
        case .subscriptionStarted: "subscription_started"
        case .officialGradeAdded: "official_grade_added"
        case .reportShared: "report_shared"
        }
    }
}
