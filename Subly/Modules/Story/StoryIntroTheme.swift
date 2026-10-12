import UIKit

/// Appearance-dependent treatment of the intro cards (What's New card 01,
/// Recap card 01): graphite in dark mode, warm paper in light mode. The
/// coloured feature cards keep their own colours in both appearances.
enum StoryIntroTheme: Equatable {
    case graphite
    case paper

    static func resolve(_ style: UIUserInterfaceStyle) -> StoryIntroTheme {
        style == .dark ? .graphite : .paper
    }

    static func resolve(_ traits: UITraitCollection) -> StoryIntroTheme {
        resolve(traits.userInterfaceStyle)
    }

    // MARK: - Tokens

    var background: UIColor {
        switch self {
        case .graphite: return UIColor(hex: "#16181C")
        case .paper: return UIColor(hex: "#F3EFE6")
        }
    }

    var ink: UIColor {
        switch self {
        case .graphite: return UIColor(hex: "#F4F5F7")
        case .paper: return UIColor(hex: "#1D1B16")
        }
    }

    func ink(alpha: CGFloat) -> UIColor {
        switch self {
        case .graphite: return UIColor(red: 235/255, green: 238/255, blue: 245/255, alpha: alpha)
        case .paper: return UIColor(red: 29/255, green: 27/255, blue: 22/255, alpha: alpha)
        }
    }

    var secondary: UIColor { ink(alpha: self == .graphite ? 0.6 : 0.7) }
    var tertiary: UIColor { ink(alpha: self == .graphite ? 0.4 : 0.45) }
    var dimmedDecimals: UIColor { ink(alpha: 0.4) }

    /// Accent for the current month bar / comparison line / headline word.
    var accent: UIColor {
        switch self {
        case .graphite: return UIColor(hex: "#C8F169")
        case .paper: return UIColor(hex: "#1D1B16")
        }
    }

    /// "▴ … more than …" line.
    var comparison: UIColor {
        switch self {
        case .graphite: return UIColor(hex: "#C8F169")
        case .paper: return UIColor(hex: "#5F7F1C")
        }
    }

    /// Previous month bars.
    var barPrevious: UIColor {
        switch self {
        case .graphite: return UIColor(white: 1, alpha: 0.12)
        case .paper: return ink(alpha: 0.12)
        }
    }

    var barLabel: UIColor { ink(alpha: self == .graphite ? 0.4 : 0.55) }

    var progressDone: UIColor {
        switch self {
        case .graphite: return UIColor(white: 1, alpha: 0.9)
        case .paper: return ink(alpha: 0.85)
        }
    }

    var progressUpcoming: UIColor {
        switch self {
        case .graphite: return UIColor(white: 1, alpha: 0.2)
        case .paper: return ink(alpha: 0.18)
        }
    }

    var closeBackground: UIColor {
        switch self {
        case .graphite: return UIColor(white: 1, alpha: 0.1)
        case .paper: return ink(alpha: 0.1)
        }
    }

    /// 64pt app-mark tile on the What's New intro.
    var markTile: UIColor {
        switch self {
        case .graphite: return UIColor(hex: "#22252C")
        case .paper: return UIColor(hex: "#1A1C21")
        }
    }

    var markTileBorder: UIColor? {
        switch self {
        case .graphite: return UIColor(white: 1, alpha: 0.08)
        case .paper: return nil
        }
    }

    /// Feature list rows on the What's New intro.
    var rowBackground: UIColor {
        switch self {
        case .graphite: return UIColor(hex: "#1F2126")
        case .paper: return .white
        }
    }

    var rowBorder: UIColor? {
        switch self {
        case .graphite: return UIColor(white: 1, alpha: 0.06)
        case .paper: return nil
        }
    }

    var rowShadow: (color: UIColor, offset: CGSize, radius: CGFloat)? {
        switch self {
        case .graphite: return nil
        case .paper: return (UIColor(red: 29/255, green: 27/255, blue: 22/255, alpha: 0.06), CGSize(width: 0, height: 1), 1)
        }
    }

    var prefersLightStatusBar: Bool { self == .graphite }

    /// Story chrome palette for a card drawn in this theme.
    var palette: RecapPalette {
        RecapPalette(
            background: .solid(background),
            ink: ink,
            secondary: secondary,
            tertiary: tertiary,
            accent: accent,
            muted: barPrevious,
            progressDone: progressDone,
            progressUpcoming: progressUpcoming,
            closeBackground: closeBackground,
            prefersLightStatusBar: prefersLightStatusBar
        )
    }
}
