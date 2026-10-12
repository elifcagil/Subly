import UIKit

/// 24-hour ring: track, tick marks, the quiet arc with moon/sun handles and
/// the duration in the centre. Handles drag with 5-minute snapping.
final class QuietHoursRingView: UIView {

    enum Handle { case start, end }

    private static let side: CGFloat = 200
    private static let radius: CGFloat = 80
    private static let strokeWidth: CGFloat = 18

    private let trackLayer = CAShapeLayer()
    private let ticksLayer = CAShapeLayer()
    private let majorTicksLayer = CAShapeLayer()
    private let arcLayer = CAShapeLayer()
    private let startHandle = UIView()
    private let endHandle = UIView()
    private let startGlyph = UIImageView(image: UIImage(systemName: "moon.fill"))
    private let endGlyph = UIImageView(image: UIImage(systemName: "sun.max.fill"))
    private let durationLabel = UILabel()
    private let captionLabel = UILabel()
    private var hourLabels: [UILabel] = []

    private(set) var startMinutes = 22 * 60
    private(set) var endMinutes = 8 * 60
    private var draggingHandle: Handle?
    private var selectedHandle: Handle = .start
    private var lastHapticMinutes = 0

    var haptics: HapticsService?
    /// Called on every snapped step while dragging and once on release.
    var onChange: ((_ startMinutes: Int, _ endMinutes: Int, _ final: Bool) -> Void)?
    var durationText: String = "" { didSet { durationLabel.text = durationText } }
    var accessibilityValueText: String = "" { didSet { accessibilityValue = accessibilityValueText } }

    override init(frame: CGRect) {
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: Self.side, height: Self.side)))
        configure()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: CGSize { CGSize(width: Self.side, height: Self.side) }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.side),
            heightAnchor.constraint(equalToConstant: Self.side)
        ])
        let center = CGPoint(x: Self.side / 2, y: Self.side / 2)

        trackLayer.path = UIBezierPath(arcCenter: center, radius: Self.radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true).cgPath
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.lineWidth = Self.strokeWidth
        layer.addSublayer(trackLayer)

        let minor = UIBezierPath()
        let major = UIBezierPath()
        for hour in 0..<24 {
            let outer = point(minutes: hour * 60, radius: 62)
            let inner = point(minutes: hour * 60, radius: hour % 6 == 0 ? 54 : 58)
            let path = hour % 6 == 0 ? major : minor
            path.move(to: outer)
            path.addLine(to: inner)
        }
        for (shape, path, width) in [(ticksLayer, minor, 1.2), (majorTicksLayer, major, 2.0)] {
            shape.path = path.cgPath
            shape.lineWidth = width
            shape.lineCap = .round
            layer.addSublayer(shape)
        }
        for hour in stride(from: 0, to: 24, by: 6) {
            let label = UILabel()
            label.text = String(format: "%02d", hour)
            label.font = UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold)
            label.sizeToFit()
            label.center = point(minutes: hour * 60, radius: 44)
            addSubview(label)
            hourLabels.append(label)
        }

        arcLayer.fillColor = UIColor.clear.cgColor
        arcLayer.lineWidth = Self.strokeWidth
        arcLayer.lineCap = .round
        layer.addSublayer(arcLayer)

        for (handle, glyph) in [(startHandle, startGlyph), (endHandle, endGlyph)] {
            handle.bounds = CGRect(x: 0, y: 0, width: 26, height: 26)
            handle.layer.cornerRadius = 13
            glyph.contentMode = .scaleAspectFit
            glyph.frame = CGRect(x: 6, y: 6, width: 14, height: 14)
            handle.addSubview(glyph)
            addSubview(handle)
        }

        durationLabel.font = DesignSystem.Typography.scaled(30, weight: .heavy, relativeTo: .title1, tabular: true)
        durationLabel.textAlignment = .center
        captionLabel.font = DesignSystem.Typography.scaled(12, weight: .semibold, relativeTo: .caption1)
        captionLabel.text = Strings.QuietHours.ofQuiet
        captionLabel.textAlignment = .center
        let centerStack = UIStackView(arrangedSubviews: [durationLabel, captionLabel])
        centerStack.axis = .vertical
        centerStack.spacing = 0
        centerStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(centerStack)
        NSLayoutConstraint.activate([
            centerStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didPan(_:))))

        isAccessibilityElement = true
        accessibilityTraits = .adjustable
        accessibilityLabel = Strings.QuietHours.title
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: Strings.QuietHours.selectStartHandle) { [weak self] _ in self?.selectedHandle = .start; return true },
            UIAccessibilityCustomAction(name: Strings.QuietHours.selectEndHandle) { [weak self] _ in self?.selectedHandle = .end; return true }
        ]
        applyColors()
        render(animated: false)
    }

    // MARK: - Public

    func setRange(startMinutes: Int, endMinutes: Int, animated: Bool) {
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        render(animated: animated)
    }

    // MARK: - Geometry

    private func angle(minutes: Int) -> CGFloat {
        CGFloat(minutes) / 1440 * 2 * .pi
    }

    private func point(minutes: Int, radius: CGFloat) -> CGPoint {
        let a = angle(minutes: minutes)
        return CGPoint(x: Self.side / 2 + radius * sin(a), y: Self.side / 2 - radius * cos(a))
    }

    private func minutes(at location: CGPoint) -> Int {
        let dx = location.x - Self.side / 2
        let dy = location.y - Self.side / 2
        var a = atan2(dx, -dy)   // 0 at top, clockwise
        if a < 0 { a += 2 * .pi }
        let raw = Int((a / (2 * .pi) * 1440).rounded())
        return ((raw + 2) / 5 * 5) % 1440   // 5-minute snapping
    }

    private func render(animated: Bool) {
        let center = CGPoint(x: Self.side / 2, y: Self.side / 2)
        let start = angle(minutes: startMinutes) - .pi / 2
        var end = angle(minutes: endMinutes) - .pi / 2
        if end <= start { end += 2 * .pi }
        let path = UIBezierPath(arcCenter: center, radius: Self.radius, startAngle: start, endAngle: end, clockwise: true)
        CATransaction.begin()
        if animated {
            let animation = CASpringAnimation(keyPath: "path")
            animation.fromValue = arcLayer.presentation()?.path ?? arcLayer.path
            animation.toValue = path.cgPath
            animation.damping = 14
            animation.stiffness = 180
            animation.duration = 0.4
            arcLayer.add(animation, forKey: "path")
        } else {
            CATransaction.setDisableActions(true)
        }
        arcLayer.path = path.cgPath
        CATransaction.commit()
        UIView.animate(withDuration: animated ? 0.4 : 0, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
            self.startHandle.center = self.point(minutes: self.startMinutes, radius: Self.radius)
            self.endHandle.center = self.point(minutes: self.endMinutes, radius: Self.radius)
        }
    }

    // MARK: - Dragging

    @objc private func didPan(_ recognizer: UIPanGestureRecognizer) {
        let location = recognizer.location(in: self)
        switch recognizer.state {
        case .began:
            let toStart = hypot(location.x - startHandle.center.x, location.y - startHandle.center.y)
            let toEnd = hypot(location.x - endHandle.center.x, location.y - endHandle.center.y)
            guard min(toStart, toEnd) < 40 else { draggingHandle = nil; return }
            draggingHandle = toStart <= toEnd ? .start : .end
            selectedHandle = draggingHandle ?? .start
            lastHapticMinutes = draggingHandle == .start ? startMinutes : endMinutes
        case .changed:
            guard let handle = draggingHandle else { return }
            let snapped = minutes(at: location)
            let previous = handle == .start ? startMinutes : endMinutes
            guard snapped != previous else { return }
            if handle == .start { startMinutes = snapped } else { endMinutes = snapped }
            haptics?.play(.selection)
            if snapped / 60 != previous / 60 { haptics?.play(.lightImpact) }
            render(animated: false)
            onChange?(startMinutes, endMinutes, false)
        case .ended, .cancelled:
            guard draggingHandle != nil else { return }
            draggingHandle = nil
            onChange?(startMinutes, endMinutes, true)
        default:
            break
        }
    }

    // MARK: - Accessibility (15-minute steps on the selected handle)

    override func accessibilityIncrement() { nudgeSelected(by: 15) }
    override func accessibilityDecrement() { nudgeSelected(by: -15) }

    private func nudgeSelected(by delta: Int) {
        if selectedHandle == .start {
            startMinutes = ((startMinutes + delta) % 1440 + 1440) % 1440
        } else {
            endMinutes = ((endMinutes + delta) % 1440 + 1440) % 1440
        }
        render(animated: true)
        onChange?(startMinutes, endMinutes, true)
    }

    // MARK: - Colours

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyColors()
    }

    private func applyColors() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        trackLayer.strokeColor = (isDark ? UIColor(white: 1, alpha: 0.08) : UIColor(white: 0, alpha: 0.06)).cgColor
        let tick = DesignSystem.Colors.textPrimary.withAlphaComponent(0.22).resolvedColor(with: traitCollection).cgColor
        ticksLayer.strokeColor = tick
        majorTicksLayer.strokeColor = tick
        let arc = UIColor(hex: isDark ? "#C8F169" : "#8CB33A")
        arcLayer.strokeColor = arc.cgColor
        for handle in [startHandle, endHandle] {
            handle.backgroundColor = isDark ? UIColor(hex: "#141609") : .white
        }
        startGlyph.tintColor = arc
        endGlyph.tintColor = arc
        durationLabel.textColor = DesignSystem.Colors.textPrimary
        captionLabel.textColor = DesignSystem.Colors.textSecondary
        hourLabels.forEach { $0.textColor = DesignSystem.Colors.textPrimary.withAlphaComponent(0.35) }
    }
}
