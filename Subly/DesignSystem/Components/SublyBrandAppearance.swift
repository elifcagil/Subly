import UIKit

/// v5 service-tile appearance: a **solid brand-colored tile** with a paired
/// foreground initial. Brand tiles keep their own colors in both themes; unknown
/// / custom subscriptions fall back to the neutral avatar background with ink.
///
/// No real brand artwork is embedded — an original tile + initial treatment.
enum SublyBrandAppearance {

    struct Appearance {
        let initial: String
        let background: UIColor
        let foreground: UIColor

        // Back-compat aliases (older call sites).
        var monogram: String { initial }
        var color: UIColor { background }
    }

    /// Backed by the UIKit-free `BrandPalette` so the widget extension draws
    /// the same tiles.
    static func appearance(forName name: String, categoryName: String?) -> Appearance {
        let tile = BrandPalette.tile(forName: name)
        if let bg = tile.backgroundHex, let fg = tile.foregroundHex {
            return Appearance(initial: tile.initial, background: UIColor(hex: bg), foreground: UIColor(hex: fg))
        }
        return Appearance(
            initial: tile.initial,
            background: DesignSystem.Colors.avatarBackground,
            foreground: DesignSystem.Colors.textPrimary
        )
    }

    static func initial(forName name: String) -> String {
        BrandPalette.initial(forName: name)
    }

    // Retained for legacy callers.
    static func monogram(forName name: String) -> String { initial(forName: name) }
    static func categoryColor(named categoryName: String?) -> UIColor {
        DesignSystem.Colors.accent
    }
}
