import UIKit

/// Recap cards: the shared story card plus the recap view model and a
/// currency count-up helper.
class RecapCardView: StoryCardView {
    let viewModel: RecapViewModel

    init(viewModel: RecapViewModel, palette: RecapPalette) {
        self.viewModel = viewModel
        super.init(palette: palette)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func countUp(_ value: Decimal, reduceMotion: Bool, into label: UILabel, render: @escaping (String) -> NSAttributedString) {
        animate(reduceMotion: reduceMotion) { [weak self, weak label] t in
            guard let self, let label else { return }
            let partial = value * Decimal(t)
            label.attributedText = render(self.viewModel.amount(t >= 1 ? value : partial))
        }
    }
}

// MARK: - 01 Total

final class RecapTotalCardView: RecapCardView {
    private let amountLabel = UILabel()
    private var barFills: [(view: UIView, height: NSLayoutConstraint, target: CGFloat)] = []

    /// Card 01 is graphite / paper by appearance.
    override var followsAppearance: Bool { true }

    override init(viewModel: RecapViewModel, palette: RecapPalette) {
        super.init(viewModel: viewModel, palette: palette)
        let recap = viewModel.recap
        let title = RecapTypography.label(22, weight: .bold, color: palette.secondary)
        title.text = Strings.Recap.totalTitle

        amountLabel.numberOfLines = 1
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.minimumScaleFactor = 0.5
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.attributedText = heroText(viewModel.amount(0))

        let subline = RecapTypography.label(17, weight: .semibold, color: palette.secondary)
        let perDay = viewModel.amount(recap.perDay)
        let sublineText = Strings.Recap.totalSubline(count: recap.subscriptionCount, perDay: perDay)
        let attributed = NSMutableAttributedString(string: sublineText)
        if let range = sublineText.range(of: perDay) {
            attributed.addAttribute(.foregroundColor, value: palette.ink, range: NSRange(range, in: sublineText))
            attributed.addAttribute(.font, value: RecapTypography.font(17, weight: .bold, tabular: true), range: NSRange(range, in: sublineText))
        }
        subline.attributedText = attributed

        let bars = makeBars(recap.monthBars)

        content.spacing = 0
        content.addArrangedSubview(title)
        content.setCustomSpacing(10, after: title)
        content.addArrangedSubview(amountLabel)
        content.setCustomSpacing(14, after: amountLabel)
        content.addArrangedSubview(subline)
        content.setCustomSpacing(40, after: subline)
        content.addArrangedSubview(bars)

        if let comparison = recap.comparison {
            let delta = RecapTypography.label(13.5, weight: .semibold, color: palette.accent, tabular: true)
            let amount = viewModel.amount(abs(comparison.delta))
            delta.text = comparison.delta >= 0 ? Strings.Recap.moreThanPrevious(amount) : Strings.Recap.lessThanPrevious(amount)
            content.setCustomSpacing(12, after: bars)
            content.addArrangedSubview(delta)
        }
        isAccessibilityElement = true
        accessibilityLabel = "\(title.text ?? "") \(viewModel.amount(recap.total)). \(sublineText)"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func heroText(_ text: String) -> NSAttributedString {
        RecapTypography.dimmedAmount(
            text, font: RecapTypography.font(92, weight: .heavy, tabular: true),
            ink: palette.ink, dim: palette.tertiary, tracking: -4
        )
    }

    private func makeBars(_ months: [Recap.MonthBar]) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .bottom
        row.distribution = .fillEqually
        row.spacing = 8
        let maxTotal = months.map(\.total).max() ?? 0
        let maxHeight: CGFloat = 96
        for (index, month) in months.enumerated() {
            let column = UIStackView()
            column.axis = .vertical
            column.alignment = .fill
            column.spacing = 6
            let track = UIView()
            track.translatesAutoresizingMaskIntoConstraints = false
            track.heightAnchor.constraint(equalToConstant: maxHeight).isActive = true
            let fill = UIView()
            fill.backgroundColor = index == months.count - 1 ? palette.accent : palette.muted
            fill.layer.cornerRadius = 8
            fill.layer.cornerCurve = .continuous
            fill.translatesAutoresizingMaskIntoConstraints = false
            track.addSubview(fill)
            let ratio = maxTotal > 0 ? NSDecimalNumber(decimal: month.total / maxTotal).doubleValue : 0
            let target = max(8, maxHeight * CGFloat(ratio))
            let height = fill.heightAnchor.constraint(equalToConstant: 8)
            NSLayoutConstraint.activate([
                fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
                fill.trailingAnchor.constraint(equalTo: track.trailingAnchor),
                fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
                height
            ])
            barFills.append((fill, height, target))
            let label = RecapTypography.label(11, weight: .bold, color: palette.tertiary, lines: 1)
            label.text = viewModel.monthLetterLabel(month.monthStart)
            label.textAlignment = .center
            column.addArrangedSubview(track)
            column.addArrangedSubview(label)
            row.addArrangedSubview(column)
        }
        return row
    }

    override func playEntrance(reduceMotion: Bool) {
        countUp(viewModel.recap.total, reduceMotion: reduceMotion, into: amountLabel) { [weak self] text in
            self?.heroText(text) ?? NSAttributedString(string: text)
        }
        animate(reduceMotion: reduceMotion) { [weak self] t in
            guard let self else { return }
            for bar in self.barFills { bar.height.constant = 8 + (bar.target - 8) * CGFloat(t) }
            self.layoutIfNeeded()
        }
    }
}

// MARK: - 02 Most expensive

final class RecapMostExpensiveCardView: RecapCardView {
    private let ring = CAShapeLayer()
    private let ringHost = UIView()
    private let share: Double

    override init(viewModel: RecapViewModel, palette: RecapPalette) {
        let top = viewModel.recap.topItem
        share = top?.share ?? 0
        super.init(viewModel: viewModel, palette: palette)
        guard let top else { return }
        content.alignment = .center
        let title = RecapTypography.label(22, weight: .bold, color: palette.secondary)
        title.text = Strings.Recap.mostExpensiveTitle
        title.textAlignment = .center

        ringHost.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ringHost.widthAnchor.constraint(equalToConstant: 200),
            ringHost.heightAnchor.constraint(equalToConstant: 200)
        ])
        let track = CAShapeLayer()
        let path = UIBezierPath(arcCenter: CGPoint(x: 100, y: 100), radius: 86, startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true)
        for layer in [track, ring] {
            layer.path = path.cgPath
            layer.fillColor = UIColor.clear.cgColor
            layer.lineWidth = 14
            layer.lineCap = .round
            ringHost.layer.addSublayer(layer)
        }
        track.strokeColor = UIColor(white: 1, alpha: 0.16).cgColor
        ring.strokeColor = UIColor.white.cgColor
        ring.strokeEnd = 0
        let tile = RecapServiceTileView(name: top.subscription.name, side: 84, radius: 24, fontSize: 36)
        ringHost.addSubview(tile)
        NSLayoutConstraint.activate([
            tile.centerXAnchor.constraint(equalTo: ringHost.centerXAnchor),
            tile.centerYAnchor.constraint(equalTo: ringHost.centerYAnchor)
        ])

        let name = RecapTypography.label(34, weight: .heavy, color: palette.ink, lines: 2)
        name.text = top.subscription.name
        name.textAlignment = .center
        let price = RecapTypography.label(20, weight: .bold, color: palette.secondary, tabular: true)
        price.text = "\(viewModel.amount(top.subscription.amount)) · \(top.subscription.billingCycle.displayName)"
        price.textAlignment = .center
        let shareLabel = RecapTypography.label(16, weight: .medium, color: palette.secondary)
        let percent = Int((top.share * 100).rounded())
        let shareText = Strings.Recap.shareOfTotal(percent: percent, period: viewModel.periodLabel)
        let attributed = NSMutableAttributedString(string: shareText)
        if let range = shareText.range(of: "\(percent)%") {
            attributed.addAttributes([.foregroundColor: palette.ink, .font: RecapTypography.font(16, weight: .bold)], range: NSRange(range, in: shareText))
        }
        shareLabel.attributedText = attributed
        shareLabel.textAlignment = .center

        content.addArrangedSubview(title)
        content.setCustomSpacing(30, after: title)
        content.addArrangedSubview(ringHost)
        content.setCustomSpacing(28, after: ringHost)
        content.addArrangedSubview(name)
        content.setCustomSpacing(4, after: name)
        content.addArrangedSubview(price)
        content.setCustomSpacing(18, after: price)
        content.addArrangedSubview(shareLabel)
        isAccessibilityElement = true
        accessibilityLabel = "\(Strings.Recap.mostExpensiveTitle): \(top.subscription.name), \(price.text ?? ""). \(shareText)"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func playEntrance(reduceMotion: Bool) {
        animate(reduceMotion: reduceMotion) { [weak self] t in
            guard let self else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.ring.strokeEnd = CGFloat(self.share * t)
            CATransaction.commit()
        }
    }
}

// MARK: - 03 Price increases

final class RecapPriceIncreasesCardView: RecapCardView {
    private let amountLabel = UILabel()
    var onReview: (() -> Void)?

    override init(viewModel: RecapViewModel, palette: RecapPalette) {
        super.init(viewModel: viewModel, palette: palette)
        let increases = viewModel.recap.priceIncreases
        let title = RecapTypography.label(22, weight: .bold, color: palette.secondary)
        title.text = Strings.Recap.pricesWentUp(increases.count)
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.attributedText = heroText(viewModel.amount(0))

        let list = UIStackView()
        list.axis = .vertical
        list.spacing = 10
        for increase in increases {
            list.addArrangedSubview(makeRow(increase))
        }
        let prompt = RecapTypography.label(15, weight: .medium, color: palette.secondary)
        prompt.text = Strings.Recap.priceReviewPrompt

        let review = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .white
        config.baseForegroundColor = UIColor(hex: "#1E2750")
        config.cornerStyle = .capsule
        config.title = Strings.Recap.reviewSubscriptions
        review.configuration = config
        review.titleLabel?.font = RecapTypography.font(16, weight: .bold)
        review.heightAnchor.constraint(equalToConstant: 50).isActive = true
        review.addAction(UIAction { [weak self] _ in self?.onReview?() }, for: .touchUpInside)

        content.addArrangedSubview(title)
        content.setCustomSpacing(10, after: title)
        content.addArrangedSubview(amountLabel)
        content.setCustomSpacing(32, after: amountLabel)
        content.addArrangedSubview(list)
        content.setCustomSpacing(20, after: list)
        content.addArrangedSubview(prompt)
        content.setCustomSpacing(28, after: prompt)
        content.addArrangedSubview(review)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var yearlyTotal: Decimal {
        viewModel.recap.priceIncreases.reduce(Decimal(0)) { $0 + $1.yearlyDelta }
    }

    private func heroText(_ amount: String) -> NSAttributedString {
        let text = NSMutableAttributedString(string: "+\(amount)", attributes: [
            .font: RecapTypography.font(64, weight: .heavy, tabular: true), .foregroundColor: palette.ink, .kern: -2.4
        ])
        text.append(NSAttributedString(string: " \(Strings.Recap.perYear)", attributes: [
            .font: RecapTypography.font(28, weight: .heavy), .foregroundColor: palette.secondary, .kern: -0.6
        ]))
        return text
    }

    private func makeRow(_ increase: Recap.PriceIncrease) -> UIView {
        let row = UIView()
        row.backgroundColor = UIColor(white: 1, alpha: 0.12)
        row.layer.cornerRadius = 20
        row.layer.cornerCurve = .continuous
        row.layer.borderWidth = 1
        row.layer.borderColor = UIColor(white: 1, alpha: 0.12).cgColor
        let tile = RecapServiceTileView(name: increase.subscription.name, side: 44, radius: 13, fontSize: 18)
        let name = RecapTypography.label(17, weight: .bold, color: palette.ink, lines: 1)
        name.text = increase.subscription.name
        let change = RecapTypography.label(14, weight: .semibold, color: palette.secondary, tabular: true, lines: 1)
        change.text = "\(viewModel.amount(increase.from)) → \(viewModel.amount(increase.to))"
        let column = UIStackView(arrangedSubviews: [name, change])
        column.axis = .vertical
        column.spacing = 2
        let pill = RecapTypography.label(13, weight: .heavy, color: UIColor(hex: "#1E2750"), tabular: true, lines: 1)
        pill.text = "+\(viewModel.amount(increase.yearlyDelta))\(Strings.Recap.perYear)"
        let pillHost = UIView()
        pillHost.backgroundColor = .white
        pillHost.layer.cornerRadius = 14
        pill.translatesAutoresizingMaskIntoConstraints = false
        pillHost.addSubview(pill)
        pillHost.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pill.topAnchor.constraint(equalTo: pillHost.topAnchor, constant: 6),
            pill.bottomAnchor.constraint(equalTo: pillHost.bottomAnchor, constant: -6),
            pill.leadingAnchor.constraint(equalTo: pillHost.leadingAnchor, constant: 10),
            pill.trailingAnchor.constraint(equalTo: pillHost.trailingAnchor, constant: -10)
        ])
        let stack = UIStackView(arrangedSubviews: [tile, column, pillHost])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16)
        ])
        return row
    }

    override func playEntrance(reduceMotion: Bool) {
        countUp(yearlyTotal, reduceMotion: reduceMotion, into: amountLabel) { [weak self] text in
            self?.heroText(text) ?? NSAttributedString(string: text)
        }
    }
}

// MARK: - 04 Longest-running

final class RecapLongestRunningCardView: RecapCardView {
    private let monthsLabel = UILabel()
    private var squares: [UIView] = []
    private let totalLabel = UILabel()
    private static let maxSquares = 120

    override init(viewModel: RecapViewModel, palette: RecapPalette) {
        super.init(viewModel: viewModel, palette: palette)
        guard let longest = viewModel.recap.longestRunning else { return }
        let title = RecapTypography.label(22, weight: .bold, color: palette.secondary)
        title.text = Strings.Recap.longestTitle

        let tile = RecapServiceTileView(name: longest.subscription.name, side: 64, radius: 18, fontSize: 26)
        let name = RecapTypography.label(30, weight: .heavy, color: palette.ink, lines: 1)
        name.text = longest.subscription.name
        let since = RecapTypography.label(15, weight: .semibold, color: palette.secondary, lines: 1)
        since.text = Strings.Recap.since(viewModel.monthYearLabel(longest.subscription.startDate))
        let column = UIStackView(arrangedSubviews: [name, since])
        column.axis = .vertical
        column.spacing = 2
        let header = UIStackView(arrangedSubviews: [tile, column])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 14

        monthsLabel.font = RecapTypography.font(96, weight: .heavy, tabular: true)
        monthsLabel.textColor = palette.ink
        monthsLabel.adjustsFontForContentSizeCategory = true
        monthsLabel.text = "0"
        let monthsCaption = RecapTypography.label(24, weight: .bold, color: palette.secondary, lines: 1)
        monthsCaption.text = Strings.Recap.months
        let monthsRow = UIStackView(arrangedSubviews: [monthsLabel, monthsCaption, UIView()])
        monthsRow.axis = .horizontal
        monthsRow.alignment = .lastBaseline
        monthsRow.spacing = 10

        content.addArrangedSubview(title)
        content.setCustomSpacing(22, after: title)
        content.addArrangedSubview(header)
        content.setCustomSpacing(34, after: header)
        content.addArrangedSubview(monthsRow)

        if longest.months <= Self.maxSquares {
            let grid = makeGrid(count: longest.months)
            content.setCustomSpacing(22, after: monthsRow)
            content.addArrangedSubview(grid)
        }

        let total = viewModel.amount(longest.totalPaid)
        let totalText = Strings.Recap.totalSince(total)
        let attributed = NSMutableAttributedString(string: totalText)
        if let range = totalText.range(of: total) {
            attributed.addAttributes([.foregroundColor: palette.ink, .font: RecapTypography.font(16, weight: .bold, tabular: true)], range: NSRange(range, in: totalText))
        }
        totalLabel.font = RecapTypography.font(16, weight: .medium)
        totalLabel.textColor = palette.secondary
        totalLabel.numberOfLines = 0
        totalLabel.attributedText = attributed
        content.setCustomSpacing(20, after: content.arrangedSubviews.last ?? monthsRow)
        content.addArrangedSubview(totalLabel)
        isAccessibilityElement = true
        accessibilityLabel = "\(Strings.Recap.longestTitle): \(longest.subscription.name), \(longest.months) \(Strings.Recap.months). \(totalText)"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func makeGrid(count: Int) -> UIView {
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 4
        grid.distribution = .fillEqually
        let perRow = 12
        let rows = Int(ceil(Double(count) / Double(perRow)))
        for rowIndex in 0..<max(rows, 1) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 4
            row.distribution = .fillEqually
            for column in 0..<perRow {
                let index = rowIndex * perRow + column
                let square = UIView()
                square.layer.cornerRadius = 3
                let isCurrent = index == count - 1
                square.backgroundColor = UIColor(white: 1, alpha: isCurrent ? 0.18 : 0.88)
                square.isHidden = index >= count
                square.alpha = 0
                square.translatesAutoresizingMaskIntoConstraints = false
                square.heightAnchor.constraint(equalTo: square.widthAnchor).isActive = true
                row.addArrangedSubview(square)
                if index < count { squares.append(square) }
            }
            grid.addArrangedSubview(row)
        }
        return grid
    }

    override func playEntrance(reduceMotion: Bool) {
        let months = viewModel.recap.longestRunning?.months ?? 0
        // Months count up over ~2.2s; squares fill left-to-right in step.
        animate(duration: 2.2, reduceMotion: reduceMotion) { [weak self] t in
            self?.monthsLabel.text = "\(Int((Double(months) * t).rounded()))"
        }
        let total = max(2.2, Double(squares.count) * 0.06)
        animate(duration: max(0.3, total), reduceMotion: reduceMotion) { [weak self] t in
            guard let self else { return }
            let visible = Int(Double(self.squares.count) * t)
            for (index, square) in self.squares.enumerated() { square.alpha = index < visible || t >= 1 ? 1 : 0 }
        }
    }
}
