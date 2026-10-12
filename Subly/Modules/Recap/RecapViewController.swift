import UIKit

/// Story container: card background, segmented progress bar, header, the
/// current card, "Tap to continue". Tap right 2/3 → next, left 1/3 →
/// previous, long-press → pause, swipe down → dismiss.
final class RecapViewController: UIViewController {

    private let viewModel: RecapViewModel
    private let haptics: HapticsService

    private var backgroundLayer: CALayer?
    private let chrome = UIView()
    private let progressStack = UIStackView()
    private var progressFills: [(fill: UIView, width: NSLayoutConstraint, track: UIView)] = []
    private let headerLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let cardHost = UIView()
    private let hintLabel = UILabel()
    private var currentCard: RecapCardView?
    private var currentPalette = RecapPalette.palette(for: .total)
    private var dismissStartCenter: CGPoint = .zero

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    init(viewModel: RecapViewModel, haptics: HapticsService) {
        self.viewModel = viewModel
        self.haptics = haptics
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        viewModel.currentCard == .total ? .darkContent : .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        configureChrome()
        configureGestures()
        bind()
        viewModel.start()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundLayer?.frame = view.bounds
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.stop()
    }

    func resumeAfterShare() {
        viewModel.setPaused(false)
    }

    // MARK: - Setup

    private func configureChrome() {
        chrome.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chrome)

        progressStack.axis = .horizontal
        progressStack.distribution = .fillEqually
        progressStack.spacing = 4
        progressStack.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(progressStack)

        headerLabel.font = RecapTypography.font(13, weight: .bold)
        headerLabel.text = Strings.Recap.header(period: viewModel.periodLabel)
        headerLabel.adjustsFontForContentSizeCategory = true

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 11, weight: .heavy)
        closeButton.configuration = config
        closeButton.layer.cornerRadius = 15
        closeButton.accessibilityLabel = Strings.Recap.close
        closeButton.addAction(UIAction { [weak self] _ in
            self?.haptics.play(.lightImpact)
            self?.viewModel.close()
        }, for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        let headerRow = UIStackView(arrangedSubviews: [headerLabel, UIView(), closeButton])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(headerRow)

        hintLabel.font = RecapTypography.font(12, weight: .semibold)
        hintLabel.text = Strings.Recap.tapToContinue
        hintLabel.textAlignment = .center
        hintLabel.adjustsFontForContentSizeCategory = true
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(hintLabel)

        cardHost.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardHost)

        let side: CGFloat = 22
        NSLayoutConstraint.activate([
            chrome.topAnchor.constraint(equalTo: view.topAnchor),
            chrome.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            chrome.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            progressStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 62),
            progressStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: side),
            progressStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -side),
            progressStack.heightAnchor.constraint(equalToConstant: 3),

            headerRow.topAnchor.constraint(equalTo: progressStack.bottomAnchor, constant: 14),
            headerRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: side),
            headerRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -side),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),

            hintLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -42),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: side),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -side),

            cardHost.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 12),
            cardHost.bottomAnchor.constraint(equalTo: hintLabel.topAnchor, constant: -12),
            cardHost.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: side),
            cardHost.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -side)
        ])

        for _ in viewModel.cards {
            let track = UIView()
            track.layer.cornerRadius = 1.5
            let fill = UIView()
            fill.layer.cornerRadius = 1.5
            fill.translatesAutoresizingMaskIntoConstraints = false
            track.addSubview(fill)
            let width = fill.widthAnchor.constraint(equalToConstant: 0)
            NSLayoutConstraint.activate([
                fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
                fill.topAnchor.constraint(equalTo: track.topAnchor),
                fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
                width
            ])
            progressStack.addArrangedSubview(track)
            progressFills.append((fill, width, track))
        }
    }

    private func configureGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(didHold(_:)))
        hold.minimumPressDuration = 0.25
        let pan = UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
        tap.require(toFail: pan)
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(hold)
        view.addGestureRecognizer(pan)
    }

    private func bind() {
        viewModel.onSnapshot = { [weak self] snapshot in self?.render(snapshot) }
        viewModel.onProgress = { [weak self] progress in self?.renderProgress(progress) }
    }

    // MARK: - Rendering

    private var renderedIndex = -1

    private func render(_ snapshot: RecapViewModel.Snapshot) {
        UIView.animate(withDuration: 0.2) {
            self.chrome.alpha = snapshot.isPaused ? 0.4 : 1
        }
        guard snapshot.index != renderedIndex else { return }
        if renderedIndex >= 0 { haptics.play(.selection) }
        renderedIndex = snapshot.index
        showCard(snapshot.cards[snapshot.index], at: snapshot.index)
    }

    private func showCard(_ card: Recap.Card, at index: Int) {
        let palette = RecapPalette.palette(for: card)
        currentPalette = palette

        let newBackground = palette.makeBackgroundLayer()
        newBackground.frame = view.bounds
        if let old = backgroundLayer {
            view.layer.insertSublayer(newBackground, above: old)
            newBackground.opacity = 0
            CATransaction.begin()
            CATransaction.setCompletionBlock { old.removeFromSuperlayer() }
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = 0.25
            newBackground.add(fade, forKey: "fade")
            newBackground.opacity = 1
            CATransaction.commit()
        } else {
            view.layer.insertSublayer(newBackground, at: 0)
        }
        backgroundLayer = newBackground

        headerLabel.textColor = palette.secondary
        hintLabel.textColor = palette.tertiary
        hintLabel.isHidden = card == .summary
        closeButton.tintColor = palette.ink
        closeButton.backgroundColor = palette.ink.withAlphaComponent(0.12)
        for (segmentIndex, segment) in progressFills.enumerated() {
            segment.track.backgroundColor = palette.ink.withAlphaComponent(0.2)
            segment.fill.backgroundColor = palette.ink.withAlphaComponent(0.9)
            segment.width.constant = segmentIndex < index ? segment.track.bounds.width : 0
            segment.fill.isHidden = false
        }
        setNeedsStatusBarAppearanceUpdate()

        currentCard?.stopAnimations()
        currentCard?.removeFromSuperview()
        let cardView = makeCard(card, palette: palette)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.alpha = 0
        cardHost.addSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: cardHost.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: cardHost.bottomAnchor),
            cardView.leadingAnchor.constraint(equalTo: cardHost.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: cardHost.trailingAnchor)
        ])
        currentCard = cardView
        view.layoutIfNeeded()
        UIView.animate(withDuration: 0.2) { cardView.alpha = 1 }
        cardView.playEntrance(reduceMotion: reduceMotion)
        UIAccessibility.post(notification: .screenChanged, argument: cardView)
    }

    private func makeCard(_ card: Recap.Card, palette: RecapPalette) -> RecapCardView {
        switch card {
        case .total:
            return RecapTotalCardView(viewModel: viewModel, palette: palette)
        case .mostExpensive:
            return RecapMostExpensiveCardView(viewModel: viewModel, palette: palette)
        case .priceIncreases:
            let view = RecapPriceIncreasesCardView(viewModel: viewModel, palette: palette)
            view.onReview = { [weak self] in
                self?.haptics.play(.lightImpact)
                self?.viewModel.reviewSubscriptions()
            }
            return view
        case .longestRunning:
            return RecapLongestRunningCardView(viewModel: viewModel, palette: palette)
        case .summary:
            let view = RecapSummaryCardView(viewModel: viewModel, palette: palette)
            view.onShare = { [weak self] in
                self?.haptics.play(.lightImpact)
                self?.viewModel.share()
            }
            view.onDone = { [weak self] in
                self?.haptics.play(.lightImpact)
                self?.viewModel.finish()
            }
            return view
        }
    }

    private func renderProgress(_ progress: Double) {
        guard viewModel.index < progressFills.count else { return }
        let segment = progressFills[viewModel.index]
        segment.width.constant = segment.track.bounds.width * CGFloat(progress)
    }

    // MARK: - Gestures

    @objc private func didTap(_ recognizer: UITapGestureRecognizer) {
        // Buttons handle their own taps; only bare card/background taps navigate.
        let location = recognizer.location(in: view)
        if let hit = view.hitTest(location, with: nil), hit is UIControl || hit.superview is UIControl { return }
        if location.x < view.bounds.width / 3 {
            viewModel.previous()
        } else if !viewModel.isLastCard {
            viewModel.next()
        }
    }

    @objc private func didHold(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began: viewModel.setPaused(true)
        case .ended, .cancelled, .failed: viewModel.setPaused(false)
        default: break
        }
    }

    @objc private func didPan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: view)
        switch recognizer.state {
        case .began:
            viewModel.setPaused(true)
            dismissStartCenter = view.center
        case .changed:
            let dy = max(0, translation.y)
            let progress = min(1, dy / 300)
            view.center = CGPoint(x: dismissStartCenter.x, y: dismissStartCenter.y + dy)
            let scale = 1 - 0.08 * progress
            view.transform = CGAffineTransform(scaleX: scale, y: scale)
            view.layer.cornerRadius = 40 * progress
        case .ended, .cancelled:
            let velocity = recognizer.velocity(in: view).y
            if translation.y > 120 || velocity > 900 {
                viewModel.close()
            } else {
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.4) {
                    self.view.center = self.dismissStartCenter
                    self.view.transform = .identity
                    self.view.layer.cornerRadius = 0
                }
                viewModel.setPaused(false)
            }
        default:
            break
        }
    }
}
