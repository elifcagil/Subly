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

    /// Lowercased name fragment → (initial, tile hex, foreground hex).
    private static let brands: [(match: String, initial: String, bg: String, fg: String)] = [
        ("netflix", "N", "#2B2D33", "#E5484D"),
        ("spotify", "S", "#1DB954", "#0A2A16"),
        ("icloud", "i", "#3A3D45", "#7FB3FF"),
        ("chatgpt", "G", "#E8E5DE", "#0D8A6A"),
        ("openai", "G", "#E8E5DE", "#0D8A6A"),
        ("youtube", "Y", "#8C3B3B", "#FFFFFF"),
        ("notion", "N", "#54565E", "#FFFFFF"),
        ("linkedin", "in", "#2D64BC", "#FFFFFF"),
        ("disney", "D", "#1B2A6B", "#FFFFFF"),
        ("figma", "F", "#2C2C2C", "#A259D6"),
        ("apple music", "A", "#2B2D33", "#FA5A6B"),
        ("apple one", "A", "#2B2D33", "#FFFFFF"),
        ("amazon", "a", "#232F3E", "#FF9900"),
        ("headspace", "H", "#F47D31", "#FFFFFF"),
        ("audible", "A", "#232F3E", "#F8991C"),
        ("hbo", "H", "#2A1B47", "#B18CFF"),
        ("claude", "C", "#2B2A26", "#D97757")
    ]

    static func appearance(forName name: String, categoryName: String?) -> Appearance {
        let key = name.lowercased()
        if let brand = brands.first(where: { key.contains($0.match) }) {
            return Appearance(
                initial: brand.initial,
                background: UIColor(hex: brand.bg),
                foreground: UIColor(hex: brand.fg)
            )
        }
        return Appearance(
            initial: initial(forName: name),
            background: DesignSystem.Colors.avatarBackground,
            foreground: DesignSystem.Colors.textPrimary
        )
    }

    static func initial(forName name: String) -> String {
        let words = name.split(separator: " ").filter { !$0.isEmpty }
        guard let first = words.first?.first else { return "•" }
        return String(first).uppercased()
    }

    // Retained for legacy callers.
    static func monogram(forName name: String) -> String { initial(forName: name) }
    static func categoryColor(named categoryName: String?) -> UIColor {
        DesignSystem.Colors.accent
    }
}
