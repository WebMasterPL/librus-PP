import SwiftUI
import UIKit

/// Design tokens for the whole app. One place to tune look & feel.
enum Theme {
    // MARK: Spacing (4 / 8 rhythm)
    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: Corner radius
    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let pill: CGFloat = 999
    }

    // MARK: Motion — short, spatial, context-aware
    enum Motion {
        /// Quick UI state changes (toggles, chips, badges).
        static let quick: Animation = .easeOut(duration: 0.18)
        /// Content appearing / cards / list changes.
        static let standard: Animation = .spring(response: 0.36, dampingFraction: 0.86)
        /// Larger transitions (navigation-adjacent, sheets).
        static let emphasized: Animation = .spring(response: 0.5, dampingFraction: 0.82)
    }
}

// MARK: - Semantic colors (system-driven, adapt to light/dark/contrast automatically)

extension Color {
    /// Screen background.
    static let appGroupedBackground = Color(uiColor: .systemGroupedBackground)
    /// Elevated surface (cards, tiles).
    static let appSurface = Color(uiColor: .secondarySystemGroupedBackground)
    /// Surface nested inside a card.
    static let appSurfaceRaised = Color(uiColor: .tertiarySystemGroupedBackground)
    /// Hairline borders / dividers.
    static let appHairline = Color(uiColor: .separator)
    /// Subtle fill for chips / progress tracks.
    static let appFill = Color(uiColor: .tertiarySystemFill)

    static let positive = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.20, green: 0.80, blue: 0.44, alpha: 1)
        : UIColor(red: 0.09, green: 0.64, blue: 0.29, alpha: 1) })
    static let negative = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.97, green: 0.44, blue: 0.44, alpha: 1)
        : UIColor(red: 0.86, green: 0.15, blue: 0.15, alpha: 1) })
    static let warning = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.96, green: 0.62, blue: 0.07, alpha: 1)
        : UIColor(red: 0.85, green: 0.47, blue: 0.02, alpha: 1) })
    static let info = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.38, green: 0.65, blue: 0.98, alpha: 1)
        : UIColor(red: 0.15, green: 0.45, blue: 0.90, alpha: 1) })
}

// MARK: - Grade colour scale (1 red → 6 green)

func gradeColor(for value: Double?) -> Color {
    guard let value else { return .secondary }
    switch value {
    case ..<1.75: return .negative
    case ..<2.75: return .warning
    case ..<3.75: return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.92, green: 0.78, blue: 0.20, alpha: 1)
        : UIColor(red: 0.78, green: 0.60, blue: 0.00, alpha: 1) })
    case ..<4.75: return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.40, green: 0.78, blue: 0.60, alpha: 1)
        : UIColor(red: 0.18, green: 0.60, blue: 0.42, alpha: 1) })
    default: return .positive
    }
}

func attendanceColor(_ kind: AttendanceKind) -> Color {
    switch kind {
    case .present, .presentCustom: return .positive
    case .absent: return .negative
    case .absentExcused: return .warning
    case .belated: return .info
    case .released: return .info
    }
}

// MARK: - Elevation

extension View {
    /// Soft, iOS-appropriate card shadow (barely-there depth).
    func cardShadow(_ strong: Bool = false) -> some View {
        shadow(color: .black.opacity(strong ? 0.10 : 0.05),
               radius: strong ? 14 : 6, x: 0, y: strong ? 6 : 2)
    }
}

// MARK: - Haptics

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}
