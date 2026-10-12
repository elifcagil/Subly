import Foundation

/// Service-tile appearance as plain hex strings — shared by the app
/// (`SublyBrandAppearance` → `UIColor`) and the widget extension (SwiftUI
/// `Color`). Brand tiles keep their colors in both themes; anything unknown
/// gets the neutral avatar treatment (`isBrand == false`) so each side can
/// substitute its own theme-aware surface.
struct BrandTile: Hashable, Sendable {
    let initial: String
    /// `#RRGGBB`, or nil for the neutral (theme-aware) tile.
    let backgroundHex: String?
    let foregroundHex: String?

    var isBrand: Bool { backgroundHex != nil }
}

enum BrandPalette {

    /// Lowercased name fragment → (initial, tile hex, foreground hex).
    /// Order matters: the first match wins.
    static let brands: [(match: String, initial: String, bg: String, fg: String)] = [
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

    static func tile(forName name: String) -> BrandTile {
        let key = name.lowercased()
        if let brand = brands.first(where: { key.contains($0.match) }) {
            return BrandTile(initial: brand.initial, backgroundHex: brand.bg, foregroundHex: brand.fg)
        }
        return BrandTile(initial: initial(forName: name), backgroundHex: nil, foregroundHex: nil)
    }

    static func initial(forName name: String) -> String {
        let words = name.split(separator: " ").filter { !$0.isEmpty }
        guard let first = words.first?.first else { return "•" }
        return String(first).uppercased()
    }
}
