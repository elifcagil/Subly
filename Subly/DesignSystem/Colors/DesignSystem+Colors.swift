import UIKit

extension DesignSystem {
    /// Semantic, theme-aware color tokens backed by the Asset Catalog (v5:
    /// graphite / warm-white foundation + electric-lime accent).
    ///
    /// Every token resolves through an asset with an **Any** and a **Dark**
    /// appearance, so Dark Mode is automatic — never branch on
    /// `traitCollection.userInterfaceStyle`.
    ///
    /// **Critical accent rule:** the accent *fill* (``accent``) stays lime in
    /// both themes and always carries near-black ``accentOnFill`` content.
    /// Accent *text / strokes* on light surfaces use ``accentText`` (olive in
    /// Light, lime in Dark) — lime text on white fails contrast.
    enum Colors {

        // MARK: Surfaces

        /// `bg/base` — screen background (`#F4F4F6` / `#0E0F12`).
        static let background = asset("Background", fallback: .systemBackground)
        static var bg: UIColor { background }
        /// `bg/surface` — cards & list groups (`#FFFFFF` / `#1A1C21`).
        static let surface = asset("Surface", fallback: .secondarySystemBackground)
        /// `bg/surfaceSecondary` — sheet body, inner groups.
        static let surfaceSecondary = asset("SurfaceSecondary", fallback: .tertiarySystemBackground)
        static let surfaceElevated = asset("SurfaceElevated", fallback: surfaceSecondary)
        /// `bg/sheet` — modal sheet background.
        static let sheet = asset("Sheet", fallback: surface)
        /// `bg/avatar` — neutral avatar/tile background.
        static let avatarBackground = asset("AvatarBg", fallback: surfaceSecondary)

        // MARK: Ink (text)

        /// `ink/primary` (`#16181C` / `#F4F5F7`).
        static let textPrimary = asset("TextPrimary", fallback: .label)
        /// `ink/secondary` (~60%).
        static let textSecondary = asset("TextSecondary", fallback: .secondaryLabel)
        /// `ink/tertiary` (~40%).
        static let textTertiary = asset("TextTertiary", fallback: .tertiaryLabel)
        static var inkPrimary: UIColor { textPrimary }
        static var inkSecondary: UIColor { textSecondary }
        static var inkTertiary: UIColor { textTertiary }
        static let primary = textPrimary

        // MARK: Lines

        /// `stroke/hairline` — card borders & separators.
        static let separator = asset("Separator", fallback: .separator)
        static var hairline: UIColor { separator }
        /// `stroke/control` — chip & button borders.
        static let strokeControl = asset("StrokeControl", fallback: separator)

        // MARK: Accent (electric lime)

        /// `accent/fill` — buttons, FAB, selected chip, today cell, toggle-on
        /// (`#C8F169`, same in both themes).
        static let accent = asset("AccentColor", fallback: .systemGreen)
        /// `accent/text` — links, highlights, chart labels (olive `#5F7F1C` in
        /// Light, lime `#C8F169` in Dark).
        static let accentText = asset("AccentDeep", fallback: accent)
        /// Legacy alias — maps to ``accentText``.
        static var accentDeep: UIColor { accentText }
        /// `accent/onFill` — text/icons on the lime fill (`#141609`, both themes).
        static let accentOnFill = asset("AccentOnFill", fallback: .black)
        /// `accent/tint` — soft accent backgrounds.
        static let accentTint = asset("AccentTint", fallback: accent.withAlphaComponent(0.12))

        // MARK: Status

        /// `danger` (`#F87171`).
        static let danger = asset("DangerColor", fallback: .systemRed)
        static var destructive: UIColor { danger }
        static let dangerTint = asset("DangerTint", fallback: danger.withAlphaComponent(0.12))

        // MARK: Charts

        /// Inactive bar color (`chart/dim`).
        static let chartDim = asset("ChartDim", fallback: textTertiary)
        /// Category-bar shades, accent → deep, per README §02. The first shade
        /// tracks the accent token so it follows the muted light-mode lime.
        static let categoryShades: [UIColor] = [
            asset("AccentColor", fallback: UIColor(hex: "#C8F169")),
            UIColor(hex: "#7AA05A"),
            UIColor(hex: "#4A5240"),
            UIColor(hex: "#2E3229")
        ]

        // MARK: Legacy tokens (still referenced by not-yet-reworked features)

        static let success = asset("SuccessColor", fallback: .systemGreen)
        static var positive: UIColor { success }
        static let positiveTint = asset("PositiveTint", fallback: success.withAlphaComponent(0.16))
        static let warning = asset("WarningColor", fallback: .systemOrange)
        static let heroWashStart = asset("HeroWashStart", fallback: accentTint)
        static let heroWashEnd = asset("HeroWashEnd", fallback: accentTint)
        static let premiumGradientStart = asset("PremiumGradStart", fallback: accent)
        static let premiumGradientEnd = asset("PremiumGradEnd", fallback: accent)

        private static func asset(_ name: String, fallback: UIColor) -> UIColor {
            UIColor(named: name) ?? fallback
        }
    }
}
