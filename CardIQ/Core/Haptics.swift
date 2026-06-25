import SwiftUI

enum CIQHaptics {
    #if os(iOS)
    private static let impact = UIImpactFeedbackGenerator(style: .medium)
    private static let notification = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()
    #endif

    static func success() {
        #if os(iOS)
        notification.notificationOccurred(.success)
        #endif
    }

    static func warning() {
        #if os(iOS)
        notification.notificationOccurred(.warning)
        #endif
    }

    static func error() {
        #if os(iOS)
        notification.notificationOccurred(.error)
        #endif
    }

    static func tap() {
        #if os(iOS)
        impact.impactOccurred()
        #endif
    }

    static func select() {
        #if os(iOS)
        selection.selectionChanged()
        #endif
    }
}
