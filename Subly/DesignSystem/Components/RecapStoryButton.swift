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

    /// Geometry. The header icon is 40pt; the What's New finale reuses the
    /// component at 132pt.
    struct Metrics {
        var side: CGFloat
        var ringRadius: CGFloat
        var lineWidth: CGFloat
        var tileSide: CGFloat
        var tileBorder: CGFloat
        var markSide: CGFloat

        static let header = Metrics(side: 40, ringRadius: 18, lineWidth: 2.5, tileSide: 30, tileBorder: 2, markSide: 24)
        static let hero = Metrics(side: 132, ringRadius: 59.4, lineWidth: 5.3, tileSide: 100, tileBorder: 5, markSide: 68)
    }

    /// Fixed tile colours (e.g. on a graphite story card) instead of the
    /// screen-background-derived ones.
    struct TileColors {
        var fill: UIColor
        var border: UIColor
    }

    let metrics: Metrics
    var tileColors: TileColors? {
        didSet { applyColors() }
    }

    private static let spinKey = "subly.recap.spin"

    init(metrics: Metrics = .header) {
        self.metrics = metrics
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: metrics.side, height: metrics.side)))
        configure()
    }

    override convenience init(frame: CGRect) {
        self.init(metrics: .header)
    }

    required init?(coder: NSCoder) {
        self.metrics = .header
        super.init(coder: coder)
        configure()
    }

    deinit {
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
    }

    override var intrinsicContentSize: CGSize { CGSize(width: metrics.side, height: metrics.side) }

    private func configure() {
        let side = metrics.side
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: side),
            heightAnchor.constraint(equalToConstant: side)
        ])

        let center = CGPoint(x: side / 2, y: side / 2)
        let path = UIBezierPath(arcCenter: center, radius: metrics.ringRadius, startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true)
        for shape in [trackLayer, arcLayer] {
            shape.path = path.cgPath
            shape.fillColor = UIColor.clear.cgColor
            shape.lineCap = .round
            shape.frame = CGRect(x: 0, y: 0, width: side, height: side)
        }
        ringContainer.frame = CGRect(x: 0, y: 0, width: side, height: side)
        ringContainer.addSublayer(trackLayer)
        ringContainer.addSublayer(arcLayer)
        layer.addSublayer(ringContainer)

        // Tile with a gap (border in the screen background colour).
        let tileInset = (side - metrics.tileSide) / 2
        tileView.frame = CGRect(x: tileInset, y: tileInset, width: metrics.tileSide, height: metrics.tileSide)
        tileView.layer.cornerRadius = metrics.tileSide / 2
        tileView.layer.borderWidth = metrics.tileBorder
        tileView.isUserInteractionEnabled = false
        addSubview(tileView)
        let markInset = (metrics.tileSide - metrics.markSide) / 2
        markView.frame = CGRect(x: markInset, y: markInset, width: metrics.markSide, height: metrics.markSide)
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
        trackLayer.lineWidth = metrics.lineWidth
        arcLayer.lineWidth = metrics.lineWidth
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
        if let tileColors {
            tileView.backgroundColor = tileColors.fill
            tileView.layer.borderColor = tileColors.border.cgColor
            arcLayer.strokeColor = UIColor(hex: "#C8F169").cgColor
            trackLayer.strokeColor = UIColor(white: 1, alpha: 0.10).cgColor
            return
        }
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
