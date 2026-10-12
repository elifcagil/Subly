import UIKit

/// Story-style recap entry in the Dashboard header: the Subly mark on its dark
/// tile, framed by a spinning 72% accent arc. Product decision: the ring keeps
/// spinning after the recap was opened too — `.seen` only changes the
/// accessibility label, never the visuals.
/// 40×40 with a 44×44 hit area.
final class RecapStoryButton: UIControl {

    enum State: Equatable {
        case ready
        case seen
    }

    private(set) var storyState: State = .ready

    private let ringContainer = CALayer()
    private let trackLayer = CAShapeLayer()
    private let arcLayer = CAShapeLayer()
    private let tileView = UIView()
    private let markView = RecapStoryMarkView()
    private var foregroundObserver: NSObjectProtocol?
    private var isSpinPaused = false

    private static let side: CGFloat = 40
    private static let ringRadius: CGFloat = 18
    private static let spinKey = "subly.recap.spin"

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    deinit {
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
    }

    override var intrinsicContentSize: CGSize { CGSize(width: Self.side, height: Self.side) }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.side),
            heightAnchor.constraint(equalToConstant: Self.side)
        ])

        let center = CGPoint(x: Self.side / 2, y: Self.side / 2)
        let path = UIBezierPath(arcCenter: center, radius: Self.ringRadius, startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true)
        for shape in [trackLayer, arcLayer] {
            shape.path = path.cgPath
            shape.fillColor = UIColor.clear.cgColor
            shape.lineCap = .round
            shape.frame = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)
        }
        ringContainer.frame = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)
        ringContainer.addSublayer(trackLayer)
        ringContainer.addSublayer(arcLayer)
        layer.addSublayer(ringContainer)

        // 30pt tile with a 2pt gap (border in the screen background colour).
        tileView.frame = CGRect(x: 5, y: 5, width: 30, height: 30)
        tileView.layer.cornerRadius = 15
        tileView.layer.borderWidth = 2
        tileView.isUserInteractionEnabled = false
        addSubview(tileView)
        markView.frame = CGRect(x: 3, y: 3, width: 24, height: 24)
        tileView.addSubview(markView)

        isAccessibilityElement = true
        accessibilityTraits = .button
        applyColors()
        setState(.ready, animated: false)

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.restartSpinIfNeeded()
        }
    }

    // MARK: - Hit area / press

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -2, dy: -2).contains(point)
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.92, y: 0.92) : .identity
            }
        }
    }

    // MARK: - State

    func setState(_ state: State, animated: Bool) {
        storyState = state
        let duration = animated ? 0.25 : 0
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        // Same look in both states: the arc stays and keeps spinning.
        trackLayer.lineWidth = 2.5
        arcLayer.lineWidth = 2.5
        arcLayer.opacity = 1
        arcLayer.strokeEnd = UIAccessibility.isReduceMotionEnabled ? 1 : 0.72
        CATransaction.commit()
        // The mark stays at full opacity in both states (product decision:
        // the icon never looks disabled); only the ring changes.
        tileView.alpha = 1
        applyColors()
        restartSpinIfNeeded()
    }

    /// Stops the spin while the Dashboard is off screen (energy).
    func pauseSpin() {
        isSpinPaused = true
        ringContainer.removeAnimation(forKey: Self.spinKey)
    }

    func resumeSpin() {
        isSpinPaused = false
        restartSpinIfNeeded()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        restartSpinIfNeeded()
    }

    private func restartSpinIfNeeded() {
        ringContainer.removeAnimation(forKey: Self.spinKey)
        guard window != nil, !isSpinPaused, !UIAccessibility.isReduceMotionEnabled else { return }
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = 2 * Double.pi
        spin.duration = 1.6
        spin.repeatCount = .infinity
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        spin.isRemovedOnCompletion = false
        ringContainer.add(spin, forKey: Self.spinKey)
    }

    // MARK: - Colours

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyColors()
    }

    private func applyColors() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        tileView.backgroundColor = UIColor(hex: isDark ? "#1A1C21" : "#1B1D22")
        tileView.layer.borderColor = DesignSystem.Colors.background.resolvedColor(with: traitCollection).cgColor
        arcLayer.strokeColor = UIColor(hex: isDark ? "#C8F169" : "#8CB33A").cgColor
        trackLayer.strokeColor = (isDark ? UIColor(white: 1, alpha: 0.10) : UIColor(white: 0, alpha: 0.08)).cgColor
    }
}

/// The stack mark (100-grid geometry), drawn with layers.
private final class RecapStoryMarkView: UIView {
    private let bars: [CALayer] = (0..<3).map { _ in CALayer() }
    private let colors = [UIColor(hex: "#4A5240"), UIColor(hex: "#8CA85B"), UIColor(hex: "#C8F169")]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        for (bar, color) in zip(bars, colors) {
            bar.backgroundColor = color.cgColor
            layer.addSublayer(bar)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let unit = bounds.width / 100
        let origins: [(CGFloat, CGFloat)] = [(30, 26), (27, 43), (24, 60)]
        for (bar, origin) in zip(bars, origins) {
            bar.frame = CGRect(x: origin.0 * unit, y: origin.1 * unit, width: 46 * unit, height: 15 * unit)
            bar.cornerRadius = 6 * unit
        }
    }
}
