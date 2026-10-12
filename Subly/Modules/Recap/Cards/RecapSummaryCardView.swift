import UIKit

/// A summary tile: rounded, with its card's background layer sized in its
/// own layout pass.
final class RecapTileView: UIView {
    private let backgroundLayer: CALayer

    init(palette: RecapPalette) {
        backgroundLayer = palette.makeBackgroundLayer()
        super.init(frame: .zero)
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        clipsToBounds = true
        layer.insertSublayer(backgroundLayer, at: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundLayer.frame = bounds
        CATransaction.commit()
    }
}

/// The summary tiles (card 05 and the share image). Each tile reuses its
/// card's colours.
final class RecapSummaryTilesView: UIView {
    let totalTile = RecapTileView(palette: RecapPalette.palette(for: .total))
    let mostExpensiveTile = RecapTileView(palette: RecapPalette.palette(for: .mostExpensive))
    let priceTile = RecapTileView(palette: RecapPalette.palette(for: .priceIncreases))
    let longestTile = RecapTileView(palette: RecapPalette.palette(for: .longestRunning))

    /// Tiles in choreography order after the Total tile (only those shown).
    var secondaryTiles: [UIView] { [mostExpensiveTile, priceTile, longestTile].filter { !$0.isHidden } }

    init(recap: Recap, periodLabel: String, currencyFormatter: CurrencyFormatting) {
        super.init(frame: .zero)
        func amount(_ value: Decimal) -> String { currencyFormatter.string(from: value, currencyCode: recap.currencyCode) }
        let ink = UIColor(hex: "#141609")
        let inkSecondary = UIColor(red: 20/255, green: 22/255, blue: 9/255, alpha: 0.65)
        let white = UIColor.white
        let whiteSecondary = UIColor(white: 1, alpha: 0.75)

        // Total (span 2)
        let totalCaption = RecapTypography.label(13, weight: .bold, color: inkSecondary)
        totalCaption.text = Strings.Recap.tileTotal
        let totalAmount = RecapTypography.label(44, weight: .heavy, color: ink, tabular: true, lines: 1)
        totalAmount.text = amount(recap.total)
        totalAmount.adjustsFontSizeToFitWidth = true
        totalAmount.minimumScaleFactor = 0.5
        let totalCount = RecapTypography.label(14, weight: .bold, color: inkSecondary, lines: 1)
        totalCount.text = Strings.Recap.subscriptionsCount(recap.subscriptionCount)
        let totalRow = UIStackView(arrangedSubviews: [totalAmount, totalCount])
        totalRow.axis = .horizontal
        totalRow.alignment = .lastBaseline
        totalRow.spacing = 8
        fill(tile: totalTile, with: [totalCaption, totalRow], spacing: 30)

        // Most expensive
        if let top = recap.topItem {
            let caption = RecapTypography.label(13, weight: .bold, color: whiteSecondary)
            caption.text = Strings.Recap.tileMostExpensive
            let name = RecapTypography.label(18, weight: .heavy, color: white, lines: 1)
            name.text = top.subscription.name
            let detail = RecapTypography.label(13, weight: .semibold, color: whiteSecondary, tabular: true, lines: 1)
            detail.text = "\(amount(top.subscription.amount)) · \(Int((top.share * 100).rounded()))%"
            let column = UIStackView(arrangedSubviews: [name, detail])
            column.axis = .vertical
            fill(tile: mostExpensiveTile, with: [caption, column], spacing: 22)
        } else {
            mostExpensiveTile.isHidden = true
        }

        // Price increases
        if !recap.priceIncreases.isEmpty {
            let caption = RecapTypography.label(13, weight: .bold, color: whiteSecondary)
            caption.text = Strings.Recap.tilePriceIncreases
            let yearly = recap.priceIncreases.reduce(Decimal(0)) { $0 + $1.yearlyDelta }
            let value = RecapTypography.label(18, weight: .heavy, color: white, lines: 1)
            value.text = "+\(amount(yearly)) \(Strings.Recap.perYear)"
            let names = RecapTypography.label(13, weight: .semibold, color: whiteSecondary, lines: 1)
            names.text = recap.priceIncreases.map(\.subscription.name).joined(separator: ", ")
            let column = UIStackView(arrangedSubviews: [value, names])
            column.axis = .vertical
            fill(tile: priceTile, with: [caption, column], spacing: 22)
        } else {
            priceTile.isHidden = true
        }

        // Longest-running (span 2)
        if let longest = recap.longestRunning {
            let caption = RecapTypography.label(13, weight: .bold, color: UIColor(white: 1, alpha: 0.8))
            caption.text = Strings.Recap.tileLongest
            let value = RecapTypography.label(18, weight: .heavy, color: white, lines: 1)
            value.text = "\(longest.subscription.name) · \(longest.months) \(Strings.Recap.months)"
            let column = UIStackView(arrangedSubviews: [caption, value])
            column.axis = .vertical
            column.spacing = 2
            let total = RecapTypography.label(18, weight: .heavy, color: white, tabular: true, lines: 1)
            total.text = amount(longest.totalPaid)
            let row = UIStackView(arrangedSubviews: [column, UIView(), total])
            row.axis = .horizontal
            row.alignment = .center
            fill(tile: longestTile, with: [row], spacing: 0)
        } else {
            longestTile.isHidden = true
        }

        let middle = UIStackView(arrangedSubviews: [mostExpensiveTile, priceTile])
        middle.axis = .horizontal
        middle.distribution = .fillEqually
        middle.spacing = 10
        let grid = UIStackView(arrangedSubviews: [totalTile, middle, longestTile])
        grid.axis = .vertical
        grid.spacing = 10
        middle.isHidden = mostExpensiveTile.isHidden && priceTile.isHidden
        grid.translatesAutoresizingMaskIntoConstraints = false
        addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: topAnchor),
            grid.bottomAnchor.constraint(equalTo: bottomAnchor),
            grid.leadingAnchor.constraint(equalTo: leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func fill(tile: UIView, with views: [UIView], spacing: CGFloat) {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: tile.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: tile.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -16)
        ])
    }

}

// MARK: - 05 Summary card (tiles + Share / Done)

final class RecapSummaryCardView: RecapCardView {
    private let tiles: RecapSummaryTilesView
    private let buttons = UIStackView()
    var onShare: (() -> Void)?
    var onDone: (() -> Void)?

    override init(viewModel: RecapViewModel, palette: RecapPalette) {
        tiles = RecapSummaryTilesView(recap: viewModel.recap, periodLabel: viewModel.periodLabel, currencyFormatter: viewModel.currencyFormatter)
        super.init(viewModel: viewModel, palette: palette)
        let title = RecapTypography.label(30, weight: .heavy, color: palette.ink, lines: 1)
        title.text = Strings.Recap.summaryTitle(period: viewModel.periodLabel)

        let share = UIButton(type: .system)
        var shareConfig = UIButton.Configuration.filled()
        shareConfig.baseBackgroundColor = UIColor(white: 1, alpha: 0.08)
        shareConfig.baseForegroundColor = palette.ink
        shareConfig.cornerStyle = .capsule
        shareConfig.title = Strings.Recap.share
        shareConfig.image = UIImage(systemName: "square.and.arrow.up")
        shareConfig.imagePadding = 8
        shareConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        share.configuration = shareConfig
        share.layer.borderWidth = 1
        share.layer.borderColor = UIColor(white: 1, alpha: 0.1).cgColor
        share.layer.cornerRadius = 26
        share.addAction(UIAction { [weak self] _ in self?.onShare?() }, for: .touchUpInside)

        let done = UIButton(type: .system)
        var doneConfig = UIButton.Configuration.filled()
        doneConfig.baseBackgroundColor = UIColor(hex: "#C8F169")
        doneConfig.baseForegroundColor = UIColor(hex: "#141609")
        doneConfig.cornerStyle = .capsule
        doneConfig.title = Strings.Recap.done
        done.configuration = doneConfig
        done.addAction(UIAction { [weak self] _ in self?.onDone?() }, for: .touchUpInside)

        for button in [share, done] {
            button.titleLabel?.font = RecapTypography.font(16, weight: .bold)
            button.heightAnchor.constraint(equalToConstant: 52).isActive = true
        }
        buttons.axis = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = 10
        buttons.addArrangedSubview(share)
        buttons.addArrangedSubview(done)

        content.spacing = 14
        content.addArrangedSubview(title)
        content.addArrangedSubview(tiles)
        content.setCustomSpacing(28, after: tiles)
        content.addArrangedSubview(buttons)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The other tiles come out of the Total tile (handoff choreography,
    /// ~1.7s). Offsets are computed from the real frames.
    override func playEntrance(reduceMotion: Bool) {
        layoutIfNeeded()
        let total = tiles.totalTile
        let others = tiles.secondaryTiles
        if reduceMotion {
            let all: [UIView] = [total] + others + [buttons]
            all.forEach { $0.alpha = 0 }
            UIView.animate(withDuration: 0.2) { all.forEach { $0.alpha = 1 } }
            return
        }
        let totalCenter = total.center
        total.alpha = 0
        total.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
        for tile in others {
            let delta = CGPoint(x: totalCenter.x - tile.center.x, y: totalCenter.y - tile.center.y)
            tile.alpha = 0
            tile.transform = CGAffineTransform(translationX: delta.x, y: delta.y).scaledBy(x: 0.55, y: 0.55)
        }
        buttons.alpha = 0
        buttons.transform = CGAffineTransform(translationX: 0, y: 14)

        let duration = 1.7
        UIView.animate(withDuration: duration * 0.32, delay: 0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.4) {
            total.alpha = 1
            total.transform = .identity
        }
        let segments: [(start: Double, end: Double)] = [(0.28, 0.66), (0.36, 0.74), (0.46, 0.86)]
        for (index, tile) in others.enumerated() {
            let segment = segments[min(index, segments.count - 1)]
            UIView.animate(withDuration: duration * (segment.end - segment.start), delay: duration * segment.start,
                           usingSpringWithDamping: 0.72, initialSpringVelocity: 0.3) {
                tile.transform = .identity
            }
            UIView.animate(withDuration: duration * (segment.end - segment.start) * 0.45, delay: duration * segment.start) {
                tile.alpha = 1
            }
        }
        UIView.animate(withDuration: duration * 0.2, delay: duration * 0.8, options: .curveEaseOut) {
            self.buttons.alpha = 1
            self.buttons.transform = .identity
        }
    }
}

// MARK: - Share image

enum RecapShareRenderer {
    static let size = CGSize(width: 1080, height: 1920)

    /// Summary tiles + mark + period label on the summary background, no chrome.
    static func render(recap: Recap, periodLabel: String, currencyFormatter: CurrencyFormatting) -> UIImage {
        let scale: CGFloat = 2.7
        let canvas = UIView(frame: CGRect(origin: .zero, size: CGSize(width: size.width / scale, height: size.height / scale)))
        canvas.backgroundColor = UIColor(hex: "#16181C")

        let mark = RecapMarkView(frame: CGRect(x: 22, y: 60, width: 36, height: 36))
        canvas.addSubview(mark)
        let label = RecapTypography.label(16, weight: .bold, color: UIColor(red: 235/255, green: 238/255, blue: 245/255, alpha: 0.7), lines: 1)
        label.text = Strings.Recap.header(period: periodLabel)
        label.frame = CGRect(x: 70, y: 60, width: canvas.bounds.width - 92, height: 36)
        canvas.addSubview(label)

        let tiles = RecapSummaryTilesView(recap: recap, periodLabel: periodLabel, currencyFormatter: currencyFormatter)
        tiles.translatesAutoresizingMaskIntoConstraints = false
        canvas.addSubview(tiles)
        NSLayoutConstraint.activate([
            tiles.leadingAnchor.constraint(equalTo: canvas.leadingAnchor, constant: 22),
            tiles.trailingAnchor.constraint(equalTo: canvas.trailingAnchor, constant: -22),
            tiles.centerYAnchor.constraint(equalTo: canvas.centerYAnchor)
        ])
        canvas.setNeedsLayout()
        canvas.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.scaleBy(x: scale, y: scale)
            canvas.layer.render(in: context.cgContext)
        }
    }
}
