import UIKit

// MARK: - 01 Intro (graphite / paper)

final class WhatsNewIntroCardView: StoryCardView {

    override var followsAppearance: Bool { true }

    init(features: [WhatsNewPayload.Feature], palette: RecapPalette) {
        super.init(palette: palette)
        let theme = palette.prefersLightStatusBar ? StoryIntroTheme.graphite : .paper

        let mark = RecapMarkView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        mark.backgroundColor = theme.markTile
        if let border = theme.markTileBorder {
            mark.layer.borderWidth = 1
            mark.layer.borderColor = border.cgColor
        }
        mark.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mark.widthAnchor.constraint(equalToConstant: 64),
            mark.heightAnchor.constraint(equalToConstant: 64)
        ])
        let markRow = UIStackView(arrangedSubviews: [mark, UIView()])
        markRow.axis = .horizontal

        let kicker = RecapTypography.label(22, weight: .bold, color: theme.secondary)
        kicker.text = Strings.WhatsNew.introKicker

        let headline = UILabel()
        headline.numberOfLines = 2
        headline.adjustsFontSizeToFitWidth = true
        headline.minimumScaleFactor = 0.6
        headline.adjustsFontForContentSizeCategory = true
        let headlineText = Strings.WhatsNew.introHeadline
        let attributed = NSMutableAttributedString(string: headlineText, attributes: [
            .font: RecapTypography.font(64, weight: .heavy), .foregroundColor: theme.ink, .kern: -2.6
        ])
        if theme == .graphite, let range = headlineText.range(of: Strings.WhatsNew.introHeadlineAccent) {
            attributed.addAttribute(.foregroundColor, value: theme.accent, range: NSRange(range, in: headlineText))
        }
        headline.attributedText = attributed

        let subline = RecapTypography.label(17, weight: .semibold, color: theme.ink(alpha: theme == .graphite ? 0.6 : 0.62))
        subline.text = Strings.WhatsNew.introSubline

        let list = UIStackView()
        list.axis = .vertical
        list.spacing = 8
        for feature in features {
            list.addArrangedSubview(makeRow(feature, theme: theme))
        }

        content.spacing = 0
        content.addArrangedSubview(markRow)
        content.setCustomSpacing(26, after: markRow)
        content.addArrangedSubview(kicker)
        content.setCustomSpacing(8, after: kicker)
        content.addArrangedSubview(headline)
        content.setCustomSpacing(12, after: headline)
        content.addArrangedSubview(subline)
        content.setCustomSpacing(30, after: subline)
        content.addArrangedSubview(list)

        isAccessibilityElement = true
        accessibilityLabel = "\(Strings.WhatsNew.introKicker) \(headlineText) \(Strings.WhatsNew.introSubline) " +
            features.map { "\($0.number). \($0.name)" }.joined(separator: ". ")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func makeRow(_ feature: WhatsNewPayload.Feature, theme: StoryIntroTheme) -> UIView {
        let row = UIView()
        row.backgroundColor = theme.rowBackground
        row.layer.cornerRadius = 14
        row.layer.cornerCurve = .continuous
        if let border = theme.rowBorder {
            row.layer.borderWidth = 1
            row.layer.borderColor = border.cgColor
        }
        if let shadow = theme.rowShadow {
            row.layer.shadowColor = shadow.color.cgColor
            row.layer.shadowOpacity = 1
            row.layer.shadowOffset = shadow.offset
            row.layer.shadowRadius = shadow.radius
        }
        let circle = UILabel()
        circle.backgroundColor = UIColor(hex: feature.circleHex)
        circle.textColor = UIColor(hex: feature.digitHex)
        circle.font = RecapTypography.font(12, weight: .heavy, tabular: true)
        circle.text = "\(feature.number)"
        circle.textAlignment = .center
        circle.layer.cornerRadius = 12
        circle.clipsToBounds = true
        circle.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            circle.widthAnchor.constraint(equalToConstant: 24),
            circle.heightAnchor.constraint(equalToConstant: 24)
        ])
        let name = RecapTypography.label(15, weight: .bold, color: theme.ink, lines: 1)
        name.text = feature.name
        let stack = UIStackView(arrangedSubviews: [circle, name])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: row.topAnchor, constant: 11),
            stack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -11),
            stack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14)
        ])
        return row
    }
}

// MARK: - 02…05 Feature cards

final class WhatsNewFeatureCardView: StoryCardView {

    private let visual: WhatsNewVisualView

    init(card: WhatsNewPayload.FeatureCard, palette: RecapPalette) {
        visual = WhatsNewVisualView.make(card.visual)
        super.init(palette: palette)

        let label = RecapTypography.label(12, weight: .heavy, color: UIColor(white: 1, alpha: 0.7))
        label.attributedText = NSAttributedString(string: card.label, attributes: [.kern: 0.8])
        let title = UILabel()
        title.numberOfLines = 0
        title.adjustsFontForContentSizeCategory = true
        title.attributedText = NSAttributedString(string: card.title, attributes: [
            .font: RecapTypography.font(32, weight: .heavy), .foregroundColor: UIColor.white, .kern: -0.8
        ])
        let body = RecapTypography.label(15, weight: .regular, color: UIColor(white: 1, alpha: 0.8))
        body.text = card.body
        let header = UIStackView(arrangedSubviews: [label, title, body])
        header.axis = .vertical
        header.spacing = 6

        let howTo = makeHowTo(card)

        content.spacing = 22
        content.addArrangedSubview(header)
        content.addArrangedSubview(visual)
        content.addArrangedSubview(howTo)

        isAccessibilityElement = true
        accessibilityLabel = "\(card.label). \(card.title) \(card.body) \(card.howToTitle). " +
            card.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: " ")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func makeHowTo(_ card: WhatsNewPayload.FeatureCard) -> UIView {
        let box = UIView()
        box.backgroundColor = UIColor(white: 0, alpha: 0.22)
        box.layer.cornerRadius = 18
        box.layer.cornerCurve = .continuous
        let title = RecapTypography.label(12, weight: .heavy, color: UIColor(white: 1, alpha: 0.65))
        title.attributedText = NSAttributedString(string: card.howToTitle, attributes: [.kern: 0.6])
        let stack = UIStackView(arrangedSubviews: [title])
        stack.axis = .vertical
        stack.spacing = 9
        for (index, step) in card.steps.enumerated() {
            let digit = UILabel()
            digit.backgroundColor = .white
            digit.textColor = UIColor(hex: card.baseHex)
            digit.font = RecapTypography.font(11, weight: .heavy, tabular: true)
            digit.text = "\(index + 1)"
            digit.textAlignment = .center
            digit.layer.cornerRadius = 10
            digit.clipsToBounds = true
            digit.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                digit.widthAnchor.constraint(equalToConstant: 20),
                digit.heightAnchor.constraint(equalToConstant: 20)
            ])
            let text = RecapTypography.label(14, weight: .medium, color: .white)
            text.text = step
            let row = UIStackView(arrangedSubviews: [digit, text])
            row.axis = .horizontal
            row.alignment = .top
            row.spacing = 10
            stack.addArrangedSubview(row)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: box.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16)
        ])
        return box
    }

    override func playEntrance(reduceMotion: Bool) {
        visual.playEntrance(reduceMotion: reduceMotion, card: self)
    }
}

// MARK: - 06 Recap finale

final class WhatsNewFinaleCardView: StoryCardView {

    private let ring = RecapStoryButton(metrics: .hero)
    private let button = UIButton(type: .system)
    var onDone: (() -> Void)?

    init(firstRecapDate: String?, palette: RecapPalette) {
        super.init(palette: palette)
        content.alignment = .center

        let label = RecapTypography.label(12, weight: .heavy, color: palette.accent, lines: 1)
        label.attributedText = NSAttributedString(string: Strings.WhatsNew.finaleLabel, attributes: [.kern: 0.8])
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8

        ring.isUserInteractionEnabled = false
        ring.tileColors = RecapStoryButton.TileColors(fill: UIColor(hex: "#22252C"), border: UIColor(hex: "#16181C"))
        ring.isAccessibilityElement = false

        let title = UILabel()
        title.numberOfLines = 0
        title.textAlignment = .center
        title.adjustsFontForContentSizeCategory = true
        title.attributedText = NSAttributedString(string: Strings.WhatsNew.finaleTitle, attributes: [
            .font: RecapTypography.font(32, weight: .heavy), .foregroundColor: palette.ink, .kern: -0.8
        ])
        let body = RecapTypography.label(15, weight: .regular, color: UIColor(red: 235/255, green: 238/255, blue: 245/255, alpha: 0.65))
        body.text = Strings.WhatsNew.finaleBody
        body.textAlignment = .center

        let callout = makeCallout(firstRecapDate: firstRecapDate, palette: palette)

        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor(hex: "#C8F169")
        config.baseForegroundColor = UIColor(hex: "#141609")
        config.cornerStyle = .capsule
        config.title = Strings.WhatsNew.finaleButton
        button.configuration = config
        button.titleLabel?.font = RecapTypography.font(17, weight: .bold)
        button.addAction(UIAction { [weak self] _ in self?.onDone?() }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 54).isActive = true

        content.spacing = 0
        content.addArrangedSubview(label)
        content.setCustomSpacing(26, after: label)
        content.addArrangedSubview(ring)
        content.setCustomSpacing(26, after: ring)
        content.addArrangedSubview(title)
        content.setCustomSpacing(12, after: title)
        content.addArrangedSubview(body)
        content.setCustomSpacing(22, after: body)
        content.addArrangedSubview(callout)
        content.setCustomSpacing(28, after: callout)
        content.addArrangedSubview(button)
        for view in [title, body, callout] {
            view.widthAnchor.constraint(lessThanOrEqualToConstant: 320).isActive = true
        }
        button.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        label.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func makeCallout(firstRecapDate: String?, palette: RecapPalette) -> UIView {
        let box = UIView()
        box.backgroundColor = UIColor(red: 200/255, green: 241/255, blue: 105/255, alpha: 0.1)
        box.layer.cornerRadius = 16
        box.layer.cornerCurve = .continuous
        box.layer.borderWidth = 1
        box.layer.borderColor = UIColor(red: 200/255, green: 241/255, blue: 105/255, alpha: 0.25).cgColor
        let title = RecapTypography.label(15, weight: .bold, color: palette.accent)
        title.text = Strings.WhatsNew.finaleCalloutTitle
        let body = RecapTypography.label(13.5, weight: .regular, color: UIColor(red: 235/255, green: 238/255, blue: 245/255, alpha: 0.7))
        if let firstRecapDate {
            let text = Strings.WhatsNew.finaleCalloutBody(date: firstRecapDate)
            let attributed = NSMutableAttributedString(string: text)
            if let range = text.range(of: firstRecapDate) {
                attributed.addAttributes([.foregroundColor: palette.ink, .font: RecapTypography.font(13.5, weight: .bold)], range: NSRange(range, in: text))
            }
            body.attributedText = attributed
        } else {
            body.text = Strings.WhatsNew.finaleCalloutBodyNoDate
        }
        let stack = UIStackView(arrangedSubviews: [title, body])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16)
        ])
        return box
    }

    override func playEntrance(reduceMotion: Bool) {
        ring.resumeSpin()
    }

    override func stopAnimations() {
        super.stopAnimations()
        ring.pauseSpin()
    }
}
