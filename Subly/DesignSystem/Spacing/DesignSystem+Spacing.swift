import CoreGraphics

extension DesignSystem {
    enum Spacing {
        // Generic scale (legacy callers).
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48

        // v5 semantic spacing.
        /// Screen horizontal padding.
        static let screenH: CGFloat = 24
        /// Card content horizontal inset.
        static let cardPadding: CGFloat = 18
        /// Card row vertical padding.
        static let rowV: CGFloat = 13
        /// Gap between side-by-side cards.
        static let cardGap: CGFloat = 12
        /// Vertical rhythm between content-stack blocks.
        static let section: CGFloat = 16
        /// Floating tab bar / FAB inset from screen edges.
        static let barInset: CGFloat = 20
        static let statusBarClearance: CGFloat = 56
    }
}
