import UIKit

/// Live mini visual on a feature card. Subclasses animate on entrance.
class WhatsNewVisualView: UIView {

    static func make(_ visual: WhatsNewPayload.FeatureCard.Visual) -> WhatsNewVisualView {
        switch visual {
        case .homeWidgets: return WhatsNewHomeWidgetVisual()
        case .lockScreenWidgets: return WhatsNewLockScreenVisual()
        case .reminders: return WhatsNewReminderVisual()
        case .quietHours: return WhatsNewQuietHoursVisual()
        }
    }

    func playEntrance(reduceMotion: Bool, card: StoryCardView) {}
}

/// Track + progress ring drawn with shape layers (12 o'clock, clockwise).
final class WhatsNewRingView: UIView {
    private let track = CAShapeLayer()
    private let progress = CAShapeLayer()
    private let radius: CGFloat
    private let lineWidth: CGFloat

    init(side: CGFloat, radius: CGFloat, lineWidth: CGFloat, trackColor: UIColor, progressColor: UIColor) {
        self.radius = radius
        self.lineWidth = lineWidth
        super.init(frame: .zero)
        let center = CGPoint(x: side / 2, y: side / 2)
        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true)
        for layer in [track, progress] {
            layer.path = path.cgPath
            layer.fillColor = UIColor.clear.cgColor
            layer.lineWidth = lineWidth
            layer.lineCap = .round
            layer.frame = CGRect(x: 0, y: 0, width: side, height: side)
            self.layer.addSublayer(layer)
        }
        track.strokeColor = trackColor.cgColor
        progress.strokeColor = progressColor.cgColor
        progress.strokeEnd = 0
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: side),
            heightAnchor.constraint(equalToConstant: side)
        ])
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setProgress(_ value: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progress.strokeEnd = value
        CATransaction.commit()
    }
}

// MARK: - 02 Home Screen widgets: medium widget with 3 rings

final class WhatsNewHomeWidgetVisual: WhatsNewVisualView {
    private struct Item { let name: String; let when: String; let progress: CGFloat }
    private var rings: [(ring: WhatsNewRingView, target: CGFloat)] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 1, alpha: 0.12)
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor(white: 1, alpha: 0.14).cgColor

        let items = [
            Item(name: "Netflix", when: Strings.WhatsNew.widgetWhenTomorrow, progress: 0.97),
            Item(name: "Spotify", when: Strings.WhatsNew.widgetWhenDays(3), progress: 0.9),
            Item(name: "ChatGPT", when: Strings.WhatsNew.widgetWhenDays(6), progress: 0.8)
        ]
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 6
        for item in items {
            let ring = WhatsNewRingView(side: 64, radius: 27.3, lineWidth: 5.6,
                                        trackColor: UIColor(white: 1, alpha: 0.18), progressColor: .white)
            let tile = RecapServiceTileView(name: item.name, side: 34, radius: 10, fontSize: 14)
            ring.addSubview(tile)
            NSLayoutConstraint.activate([
                tile.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
                tile.centerYAnchor.constraint(equalTo: ring.centerYAnchor)
            ])
            rings.append((ring, item.progress))
            let when = RecapTypography.label(12, weight: .bold, color: .white, lines: 1)
            when.text = item.when
            when.textAlignment = .center
            let column = UIStackView(arrangedSubviews: [ring, when])
            column.axis = .vertical
            column.alignment = .center
            column.spacing = 6
            row.addArrangedSubview(column)
        }
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func playEntrance(reduceMotion: Bool, card: StoryCardView) {
        card.animate(duration: 0.9, reduceMotion: reduceMotion) { [weak self] t in
            self?.rings.forEach { $0.ring.setProgress($0.target * CGFloat(t)) }
        }
    }
}

// MARK: - 03 Lock Screen: inline line, clock, 4 circular widgets

final class WhatsNewLockScreenVisual: WhatsNewVisualView {
    private var rings: [(ring: WhatsNewRingView, target: CGFloat)] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0, alpha: 0.18)
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor(white: 1, alpha: 0.12).cgColor

        let inline = RecapTypography.label(13, weight: .semibold, color: UIColor(white: 1, alpha: 0.85), lines: 1)
        inline.text = Strings.WhatsNew.lockInlineSample
        inline.textAlignment = .center
        let clock = UILabel()
        clock.attributedText = NSAttributedString(string: "9:41", attributes: [
            .font: RecapTypography.font(60, weight: .bold, tabular: true), .foregroundColor: UIColor.white, .kern: -1.5
        ])
        clock.textAlignment = .center

        let items: [(initial: String, short: String, progress: CGFloat)] = [("N", "1d", 0.97), ("S", "3d", 0.9), ("C", "6d", 0.8), ("Y", "14d", 0.53)]
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 10
        for item in items {
            let host = UIView()
            host.backgroundColor = UIColor(white: 1, alpha: 0.14)
            host.layer.cornerRadius = 28
            host.translatesAutoresizingMaskIntoConstraints = false
            let ring = WhatsNewRingView(side: 56, radius: 23.3, lineWidth: 3.9,
                                        trackColor: UIColor(white: 1, alpha: 0.28), progressColor: .white)
            host.addSubview(ring)
            let initial = RecapTypography.label(16, weight: .heavy, color: .white, lines: 1)
            initial.text = item.initial
            initial.textAlignment = .center
            let short = RecapTypography.label(9.5, weight: .bold, color: UIColor(white: 1, alpha: 0.8), lines: 1)
            short.text = item.short
            short.textAlignment = .center
            let center = UIStackView(arrangedSubviews: [initial, short])
            center.axis = .vertical
            center.alignment = .center
            center.spacing = 1
            center.translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(center)
            NSLayoutConstraint.activate([
                host.widthAnchor.constraint(equalToConstant: 56),
                host.heightAnchor.constraint(equalToConstant: 56),
                ring.centerXAnchor.constraint(equalTo: host.centerXAnchor),
                ring.centerYAnchor.constraint(equalTo: host.centerYAnchor),
                center.centerXAnchor.constraint(equalTo: host.centerXAnchor),
                center.centerYAnchor.constraint(equalTo: host.centerYAnchor)
            ])
            rings.append((ring, item.progress))
            row.addArrangedSubview(host)
        }
        let stack = UIStackView(arrangedSubviews: [inline, clock, row])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.setCustomSpacing(14, after: clock)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func playEntrance(reduceMotion: Bool, card: StoryCardView) {
        card.animate(duration: 0.9, reduceMotion: reduceMotion) { [weak self] t in
            self?.rings.forEach { $0.ring.setProgress($0.target * CGFloat(t)) }
        }
    }
}

// MARK: - 04 Reminders: banner + 3 actions

final class WhatsNewReminderVisual: WhatsNewVisualView {
    private let banner = UIView()
    private let actions = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let bannerFill = UIColor(red: 30/255, green: 20/255, blue: 14/255, alpha: 0.55)
        let stroke = UIColor(white: 1, alpha: 0.14)

        banner.backgroundColor = bannerFill
        banner.layer.cornerRadius = 20
        banner.layer.cornerCurve = .continuous
        banner.layer.borderWidth = 1
        banner.layer.borderColor = stroke.cgColor
        let mark = RecapMarkView(frame: CGRect(x: 0, y: 0, width: 34, height: 34))
        mark.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mark.widthAnchor.constraint(equalToConstant: 34),
            mark.heightAnchor.constraint(equalToConstant: 34)
        ])
        let title = RecapTypography.label(14, weight: .bold, color: .white, lines: 1)
        title.text = Strings.WhatsNew.remindersSampleTitle
        let time = RecapTypography.label(11.5, weight: .regular, color: UIColor(white: 1, alpha: 0.55), lines: 1)
        time.text = Strings.WhatsNew.remindersSampleTime
        time.setContentCompressionResistancePriority(.required, for: .horizontal)
        let titleRow = UIStackView(arrangedSubviews: [title, time])
        titleRow.axis = .horizontal
        titleRow.spacing = 8
        let body = RecapTypography.label(13, weight: .regular, color: UIColor(white: 1, alpha: 0.8))
        body.text = Strings.WhatsNew.remindersSampleBody
        let text = UIStackView(arrangedSubviews: [titleRow, body])
        text.axis = .vertical
        text.spacing = 1
        let bannerStack = UIStackView(arrangedSubviews: [mark, text])
        bannerStack.axis = .horizontal
        bannerStack.alignment = .top
        bannerStack.spacing = 11
        bannerStack.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(bannerStack)
        NSLayoutConstraint.activate([
            bannerStack.topAnchor.constraint(equalTo: banner.topAnchor, constant: 13),
            bannerStack.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -13),
            bannerStack.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            bannerStack.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -14)
        ])

        actions.backgroundColor = bannerFill
        actions.layer.cornerRadius = 16
        actions.layer.cornerCurve = .continuous
        actions.layer.borderWidth = 1
        actions.layer.borderColor = stroke.cgColor
        actions.clipsToBounds = true
        let list = UIStackView()
        list.axis = .vertical
        let rows: [(String, UIColor, UIFont.Weight)] = [
            (Strings.Reminders.actionKeep, UIColor(hex: "#C8F169"), .semibold),
            (Strings.Reminders.actionRemindTomorrow, .white, .medium),
            (Strings.Reminders.actionReview, .white, .medium)
        ]
        for (index, row) in rows.enumerated() {
            let label = RecapTypography.label(14.5, weight: row.2, color: row.1, lines: 1)
            label.text = row.0
            let host = UIView()
            label.translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: host.topAnchor, constant: 11),
                label.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -11),
                label.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -16)
            ])
            if index < rows.count - 1 {
                let separator = UIView()
                separator.backgroundColor = UIColor(white: 1, alpha: 0.1)
                separator.translatesAutoresizingMaskIntoConstraints = false
                host.addSubview(separator)
                NSLayoutConstraint.activate([
                    separator.heightAnchor.constraint(equalToConstant: 1),
                    separator.bottomAnchor.constraint(equalTo: host.bottomAnchor),
                    separator.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                    separator.trailingAnchor.constraint(equalTo: host.trailingAnchor)
                ])
            }
            list.addArrangedSubview(host)
        }
        list.translatesAutoresizingMaskIntoConstraints = false
        actions.addSubview(list)
        NSLayoutConstraint.activate([
            list.topAnchor.constraint(equalTo: actions.topAnchor),
            list.bottomAnchor.constraint(equalTo: actions.bottomAnchor),
            list.leadingAnchor.constraint(equalTo: actions.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: actions.trailingAnchor)
        ])

        let stack = UIStackView(arrangedSubviews: [banner, actions])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The banner slides down 12pt and fades in; the actions follow.
    override func playEntrance(reduceMotion: Bool, card: StoryCardView) {
        guard !reduceMotion else { return }
        banner.alpha = 0
        banner.transform = CGAffineTransform(translationX: 0, y: -12)
        actions.alpha = 0
        UIView.animate(withDuration: 0.45, delay: 0.1, options: .curveEaseOut) {
            self.banner.alpha = 1
            self.banner.transform = .identity
        }
        UIView.animate(withDuration: 0.35, delay: 0.4, options: .curveEaseOut) {
            self.actions.alpha = 1
        }
    }
}

// MARK: - 05 Quiet hours: 24h ring with the 22–08 arc

final class WhatsNewQuietHoursVisual: WhatsNewVisualView {
    private let arc = CAShapeLayer()
    private let side: CGFloat = 170

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        let ringHost = UIView()
        ringHost.translatesAutoresizingMaskIntoConstraints = false
        let center = CGPoint(x: side / 2, y: side / 2)
        let radius = side * 0.4
        let lineWidth = side * 0.09
        let track = CAShapeLayer()
        track.path = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true).cgPath
        track.fillColor = UIColor.clear.cgColor
        track.strokeColor = UIColor(white: 1, alpha: 0.14).cgColor
        track.lineWidth = lineWidth
        ringHost.layer.addSublayer(track)
        // 22:00 → 08:00 clockwise, 12 o'clock = midnight.
        let start = -CGFloat.pi / 2 + (22.0 / 24.0) * 2 * .pi
        let end = -CGFloat.pi / 2 + (8.0 / 24.0 + 1) * 2 * .pi
        arc.path = UIBezierPath(arcCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true).cgPath
        arc.fillColor = UIColor.clear.cgColor
        arc.strokeColor = UIColor.white.cgColor
        arc.lineWidth = lineWidth
        arc.lineCap = .round
        arc.strokeEnd = 0
        ringHost.layer.addSublayer(arc)

        let hours = RecapTypography.label(26, weight: .heavy, color: .white, tabular: true, lines: 1)
        hours.text = "22–08"
        hours.textAlignment = .center
        let caption = RecapTypography.label(11.5, weight: .semibold, color: UIColor(white: 1, alpha: 0.7), lines: 1)
        caption.text = Strings.WhatsNew.quietHoursDefault
        caption.textAlignment = .center
        let labels = UIStackView(arrangedSubviews: [hours, caption])
        labels.axis = .vertical
        labels.alignment = .center
        labels.translatesAutoresizingMaskIntoConstraints = false
        ringHost.addSubview(labels)
        addSubview(ringHost)
        NSLayoutConstraint.activate([
            ringHost.widthAnchor.constraint(equalToConstant: side),
            ringHost.heightAnchor.constraint(equalToConstant: side),
            ringHost.centerXAnchor.constraint(equalTo: centerXAnchor),
            ringHost.topAnchor.constraint(equalTo: topAnchor),
            ringHost.bottomAnchor.constraint(equalTo: bottomAnchor),
            labels.centerXAnchor.constraint(equalTo: ringHost.centerXAnchor),
            labels.centerYAnchor.constraint(equalTo: ringHost.centerYAnchor)
        ])
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func playEntrance(reduceMotion: Bool, card: StoryCardView) {
        card.animate(duration: 0.9, reduceMotion: reduceMotion) { [weak self] t in
            guard let self else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.arc.strokeEnd = CGFloat(t)
            CATransaction.commit()
        }
    }
}
