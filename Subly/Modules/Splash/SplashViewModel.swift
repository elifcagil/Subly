import Foundation
import UIKit

/// Subly launch screen. A calm coral-wash background with the centered app
/// mark, wordmark, tagline, and a thin determinate progress bar near the
/// bottom. Kept under ~1s — it covers cold-launch before the first data load,
/// then hands off to the main shell (or onboarding).
@MainActor
final class SplashViewModel {

    /// How long the branded splash is shown before handing off.
    private(set) var displayDuration: TimeInterval = 0.9

    var onFinished: (() -> Void)?

    func start() {
        // A touch shorter under Reduce Motion — same calm fade either way.
        displayDuration = UIAccessibility.isReduceMotionEnabled ? 0.6 : 0.9
    }

    func didFinishAnimation() {
        onFinished?()
    }
}
