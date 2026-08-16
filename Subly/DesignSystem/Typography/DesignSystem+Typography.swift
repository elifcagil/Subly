import UIKit

extension DesignSystem {
    /// Typography tokens (v5). Reference px sizes from README mapped onto
    /// Dynamic Type via `UIFontMetrics`. Weights: 800 → `.heavy`, 700 →
    /// `.bold`, 600 → `.semibold`, 500 → `.medium`. Money roles use tabular
    /// (monospaced) figures.
    enum Typography {

        // MARK: Builder

        static func scaled(
            _ size: CGFloat,
            weight: UIFont.Weight,
            relativeTo style: UIFont.TextStyle,
            tabular: Bool = false
        ) -> UIFont {
            var descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
            if tabular { descriptor = descriptor.addingAttributes(tabularFigures) }
            let base = UIFont(descriptor: descriptor, size: size)
            return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
        }

        private static let tabularFigures: [UIFontDescriptor.AttributeName: Any] = [
            .featureSettings: [[
                UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector
            ]]
        ]

        // MARK: Tracking

        enum Tracking {
            static let heroAmount: CGFloat = -1.4
            static let largeTitle: CGFloat = -0.6
            static let title: CGFloat = -0.4
            static let sectionHeader: CGFloat = 0
        }

        static func apply(_ font: UIFont, tracking: CGFloat, to label: UILabel) {
            label.font = font
            guard let text = label.text, !text.isEmpty else { return }
            label.attributedText = NSAttributedString(string: text, attributes: [.font: font, .kern: tracking])
        }

        // MARK: Roles — titles

        /// Screen large title (32 / 800 / −0.6).
        static var largeTitle: UIFont { scaled(32, weight: .heavy, relativeTo: .largeTitle) }
        /// Sheet & detail title (24 / 800 / −0.4).
        static var title: UIFont { scaled(24, weight: .heavy, relativeTo: .title1) }
        /// Sheet section title (20 / 800).
        static var sheetSectionTitle: UIFont { scaled(20, weight: .heavy, relativeTo: .title2) }
        /// Onboarding headline (33 / 800).
        static var onboardingHeadline: UIFont { scaled(33, weight: .heavy, relativeTo: .largeTitle) }

        // MARK: Roles — rows & sections

        /// Section label (14 / 700).
        static var sectionHeader: UIFont { scaled(14, weight: .bold, relativeTo: .subheadline) }
        static var headline: UIFont { sectionHeader }
        static var groupHeader: UIFont { scaled(12, weight: .bold, relativeTo: .caption1) }
        /// Card row title (16 / 600).
        static var rowTitle: UIFont { scaled(16, weight: .semibold, relativeTo: .body) }
        /// Body / settings row (15 / 600).
        static var body: UIFont { scaled(15, weight: .semibold, relativeTo: .body) }
        static var subhead: UIFont { scaled(14, weight: .medium, relativeTo: .subheadline) }
        /// Secondary / meta (13 / 500).
        static var footnote: UIFont { scaled(13, weight: .medium, relativeTo: .footnote) }
        static var secondaryMeta: UIFont { footnote }
        /// Micro-labels (11 / 700).
        static var caption: UIFont { scaled(11, weight: .bold, relativeTo: .caption2) }
        static var tabLabel: UIFont { scaled(10, weight: .semibold, relativeTo: .caption2) }

        // MARK: Roles — monetary (tabular)

        /// Hero amount (48 / 800 / −1.4, tnum; decimals dimmed by the label).
        static var heroAmount: UIFont { scaled(48, weight: .heavy, relativeTo: .largeTitle, tabular: true) }
        /// Detail price (28 / 800, tnum).
        static var detailAmount: UIFont { scaled(28, weight: .heavy, relativeTo: .title1, tabular: true) }
        /// Stat-card amount (22 / 800, tnum).
        static var statAmount: UIFont { scaled(22, weight: .heavy, relativeTo: .title2, tabular: true) }
        /// Default display amount for ``SublyAmountLabel``.
        static var amount: UIFont { scaled(28, weight: .heavy, relativeTo: .title1, tabular: true) }
        /// Row value (16 / 700, tnum).
        static var amountCompact: UIFont { scaled(16, weight: .bold, relativeTo: .body, tabular: true) }
    }
}
