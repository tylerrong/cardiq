import SwiftUI

enum CIQColors {
    static let backgroundPrimary = Color("BackgroundPrimary")
    static let backgroundSecondary = Color("BackgroundSecondary")
    static let backgroundTertiary = Color("BackgroundTertiary")
    static let backgroundCard = Color("BackgroundCard")

    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textTertiary = Color("TextTertiary")

    static let accentPrimary = Color("AccentPrimary")
    static let accentSecondary = Color("AccentSecondary")

    static let positive = Color("Positive")
    static let warning = Color("Warning")
    static let negative = Color("Negative")

    static let border = Color("Border")
    static let borderSubtle = Color("BorderSubtle")

    static let overlay = Color.black.opacity(0.6)

    enum Fallback {
        static let backgroundPrimary = Color(red: 0.07, green: 0.07, blue: 0.08)
        static let backgroundSecondary = Color(red: 0.11, green: 0.11, blue: 0.12)
        static let backgroundTertiary = Color(red: 0.15, green: 0.15, blue: 0.16)
        static let backgroundCard = Color(red: 0.13, green: 0.13, blue: 0.14)
        static let textPrimary = Color.white
        static let textSecondary = Color(white: 0.6)
        static let textTertiary = Color(white: 0.4)
        static let accentPrimary = Color(red: 0.2, green: 0.83, blue: 0.6)
        static let accentSecondary = Color(red: 0.15, green: 0.68, blue: 0.5)
        static let positive = Color(red: 0.2, green: 0.83, blue: 0.6)
        static let warning = Color(red: 1.0, green: 0.76, blue: 0.03)
        static let negative = Color(red: 1.0, green: 0.35, blue: 0.37)
        static let border = Color(white: 0.2)
        static let borderSubtle = Color(white: 0.15)
    }
}
