import UIKit

extension DesignSystem {
    enum Motion {
        static let durationFast: TimeInterval = 0.15
        static let durationStandard: TimeInterval = 0.25
        static let durationSlow: TimeInterval = 0.4

        // Handoff transition durations.
        /// Push screen (detail/edit/insights/sub-pages).
        static let push: TimeInterval = 0.28
        /// Bottom sheet (Add / Filter) slide-up + dim fade.
        static let sheet: TimeInterval = 0.34
        /// Fade (search / paywall).
        static let fade: TimeInterval = 0.24

        static let easeOut = UIView.AnimationOptions.curveEaseOut
        static let easeInOut = UIView.AnimationOptions.curveEaseInOut

        /// Handoff easing `cubic-bezier(0.32, 0.72, 0, 1)` — approximates the system spring.
        static var systemSpring: UICubicTimingParameters {
            UICubicTimingParameters(
                controlPoint1: CGPoint(x: 0.32, y: 0.72),
                controlPoint2: CGPoint(x: 0.0, y: 1.0)
            )
        }

        @MainActor
        static func standard(_ animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
            UIView.animate(
                withDuration: durationStandard,
                delay: 0,
                options: [easeOut, .allowUserInteraction],
                animations: animations,
                completion: completion
            )
        }

        @MainActor
        static func fast(_ animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
            UIView.animate(
                withDuration: durationFast,
                delay: 0,
                options: [easeOut, .allowUserInteraction],
                animations: animations,
                completion: completion
            )
        }
    }
}
