import UIKit

extension DesignSystem {
    enum Shadow {
        struct Token {
            let color: UIColor
            let opacity: Float
            let radius: CGFloat
            let offset: CGSize
        }

        static let low = Token(
            color: .black,
            opacity: 0.04,
            radius: 4,
            offset: CGSize(width: 0, height: 1)
        )

        static let medium = Token(
            color: .black,
            opacity: 0.08,
            radius: 10,
            offset: CGSize(width: 0, height: 2)
        )

        static let high = Token(
            color: .black,
            opacity: 0.12,
            radius: 20,
            offset: CGSize(width: 0, height: 6)
        )

        // Handoff colored elevation tokens.

        /// Primary coral CTA — `0 10px 24px rgba(238,123,78,0.32)`.
        static let coralCTA = Token(
            color: DesignSystem.Colors.accent,
            opacity: 0.32,
            radius: 24,
            offset: CGSize(width: 0, height: 10)
        )

        /// Premium card — `0 12px 26px rgba(224,94,140,0.28)`.
        static let premium = Token(
            color: DesignSystem.Colors.premiumGradientEnd,
            opacity: 0.28,
            radius: 26,
            offset: CGSize(width: 0, height: 12)
        )

        /// Floating / onboarding cards — `0 14–18px 30–36px rgba(60,40,20,0.10–0.12)`.
        static let floating = Token(
            color: UIColor(red: 60.0 / 255, green: 40.0 / 255, blue: 20.0 / 255, alpha: 1),
            opacity: 0.11,
            radius: 33,
            offset: CGSize(width: 0, height: 16)
        )

        /// Applies a shadow token to a layer (does not set `cornerRadius`).
        static func apply(_ token: Token, to layer: CALayer) {
            layer.shadowColor = token.color.cgColor
            layer.shadowOpacity = token.opacity
            layer.shadowRadius = token.radius
            layer.shadowOffset = token.offset
        }
    }
}
