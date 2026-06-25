import SwiftUI

enum CIQSpacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
    static let xxxxl: CGFloat = 48
}

enum CIQRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let card: CGFloat = 16
    static let button: CGFloat = 12
    static let sheet: CGFloat = 24
}

enum CIQShadow {
    static let sm = ShadowStyle.drop(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    static let md = ShadowStyle.drop(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    static let lg = ShadowStyle.drop(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
}

enum CIQAnimation {
    static let quick: Animation = .easeInOut(duration: 0.2)
    static let standard: Animation = .easeInOut(duration: 0.3)
    static let slow: Animation = .easeInOut(duration: 0.5)
    static let spring: Animation = .spring(response: 0.4, dampingFraction: 0.8)
}
