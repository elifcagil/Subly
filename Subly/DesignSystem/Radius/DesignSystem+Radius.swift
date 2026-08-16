import CoreGraphics

extension DesignSystem {
    enum Radius {
        // Generic scale (legacy callers).
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 16
        static let pill: CGFloat = 999

        // v5 semantic radii.
        /// Cards & list groups.
        static let card: CGFloat = 20
        /// Detail hero tile (72×72) — also generic large-card radius.
        static let hero: CGFloat = 20
        /// Filter chip (height 32).
        static let chip: CGFloat = 16
        /// Search-filter chip (height 30).
        static let chipSmall: CGFloat = 15
        /// Primary/paired button.
        static let button: CGFloat = 26
        /// Bottom-sheet top corners.
        static let sheet: CGFloat = 28
        /// Floating tab-bar pill (height 58) and FAB (58×58) → 29.
        static let bar: CGFloat = 29
        /// List service tile (40×40).
        static let tileSmall: CGFloat = 12
        /// Catalog service tile (44×44).
        static let tileCatalog: CGFloat = 13
        /// Detail service tile (72×72).
        static let tileDetail: CGFloat = 20
        /// Calendar cell.
        static let calendarCell: CGFloat = 11
        /// Toggle track.
        static let toggleTrack: CGFloat = 13

        /// Service-tile radius proportional to side (12 at 40pt).
        static func tile(forSide side: CGFloat) -> CGFloat { side * (12.0 / 40.0) }
    }
}
