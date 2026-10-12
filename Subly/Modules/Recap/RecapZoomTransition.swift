import UIKit

/// Zooms the Recap from the header icon's frame to full screen (corner
/// radius 20 → 0, ~0.35s spring) and back on dismiss.
final class RecapZoomTransition: NSObject, UIViewControllerTransitioningDelegate {

    private weak var sourceView: UIView?

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        sourceView.map { Animator(sourceView: $0, isPresenting: true) }
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        sourceView.map { Animator(sourceView: $0, isPresenting: false) }
    }

    private final class Animator: NSObject, UIViewControllerAnimatedTransitioning {
        private let sourceView: UIView
        private let isPresenting: Bool

        init(sourceView: UIView, isPresenting: Bool) {
            self.sourceView = sourceView
            self.isPresenting = isPresenting
        }

        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval { 0.35 }

        func animateTransition(using context: UIViewControllerContextTransitioning) {
            let container = context.containerView
            guard let recap = context.viewController(forKey: isPresenting ? .to : .from) else {
                context.completeTransition(false)
                return
            }
            let finalFrame = context.finalFrame(for: recap)
            let sourceFrame = sourceView.convert(sourceView.bounds, to: container)
            let reduceMotion = UIAccessibility.isReduceMotionEnabled

            if isPresenting { container.addSubview(recap.view) }
            recap.view.frame = finalFrame
            recap.view.layer.cornerCurve = .continuous
            recap.view.clipsToBounds = true

            let apply: (Bool) -> Void = { zoomedOut in
                if zoomedOut {
                    let scale = CGAffineTransform(scaleX: sourceFrame.width / finalFrame.width, y: sourceFrame.height / finalFrame.height)
                    recap.view.transform = scale
                    recap.view.center = CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)
                    recap.view.layer.cornerRadius = 20 / scale.a
                    recap.view.alpha = reduceMotion ? 0 : 1
                } else {
                    recap.view.transform = .identity
                    recap.view.frame = finalFrame
                    recap.view.layer.cornerRadius = 0
                    recap.view.alpha = 1
                }
            }

            apply(isPresenting)
            if reduceMotion {
                recap.view.transform = .identity
                recap.view.frame = finalFrame
                recap.view.alpha = isPresenting ? 0 : 1
                UIView.animate(withDuration: 0.2, animations: { recap.view.alpha = self.isPresenting ? 1 : 0 }) { _ in
                    context.completeTransition(!context.transitionWasCancelled)
                }
                return
            }
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0.4) {
                apply(!self.isPresenting)
            } completion: { _ in
                if !self.isPresenting { recap.view.removeFromSuperview() }
                context.completeTransition(!context.transitionWasCancelled)
            }
        }
    }
}
