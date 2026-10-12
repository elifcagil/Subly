import UIKit

/// Story container shared by the Recap and What's New: card background,
/// segmented progress bar, header, the current card, bottom hint. Tap right
/// 2/3 → next, left 1/3 → previous, long-press → pause, swipe down → dismiss.
final class StoryViewController: UIViewController {

    private let content: StoryContent
    private let haptics: HapticsService

    private var backgroundLayer: CALayer?
    private let chrome = UIView()
    private let progressStack = UIStackView()
    private var progressFills: [(fill: UIView, width: NSLayoutConstraint, track: UIView)] = []
    private let headerLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let cardHost = UIView()
    private let hintLabel = UILabel()
    private var currentCard: StoryCardView?
    private var currentPalette: RecapPalette?
    private var dismissStartCenter: CGPoint = .zero
    private var renderedIndex = -1

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }
    private var theme: StoryIntroTheme { StoryIntroTheme.resolve(traitCollection) }

    init(content: StoryContent, haptics: HapticsService) {
        self.content = content
        self.haptics = haptics
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        (currentPalette?.prefersLightStatusBar ?? true) ? .lightContent : .darkContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        configureChrome()
        configureGestures()
        bind()
        content.player.start()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundLayer?.frame = view.bounds
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        content.player.stop()
    }

    /// Follow the appearance live: intro cards crossfade to the other theme.
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard let previous = previousTraitCollection,
              previous.userInterfaceStyle != traitCollection.userInterfaceStyle,
              renderedIndex >= 0, currentCard?.followsAppearance == true else { return }
        showCard(at: renderedIndex, playEntrance: false, crossfade: true)
    }

    func resume() {
        content.player.setPaused(false)
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
        headerLabel.text = content.headerTitle
        headerLabel.adjustsFontForContentSizeCategory = true

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 11, weight: .heavy)
        closeButton.configuration = config
        closeButton.layer.cornerRadius = 15
        closeButton.accessibilityLabel = Strings.Recap.close
        closeButton.addAction(UIAction { [weak self] _ in
            self?.haptics.play(.lightImpact)
            self?.content.close()
        }, for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        let headerRow = UIStackView(arrangedSubviews: [headerLabel, UIView(), closeButton])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(headerRow)

        hintLabel.font = RecapTypography.font(12, weight: .semibold)
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

        for _ in 0..<content.player.count {
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
        content.player.onSnapshot = { [weak self] snapshot in self?.render(snapshot) }
        content.player.onProgress = { [weak self] progress in self?.renderProgress(progress) }
    }

    // MARK: - Rendering

    private func render(_ snapshot: StoryPlayer.Snapshot) {
        UIView.animate(withDuration: 0.2) {
            self.chrome.alpha = snapshot.isPaused ? 0.4 : 1
        }
        guard snapshot.index != renderedIndex else { return }
        if renderedIndex >= 0 { haptics.play(.selection) }
        renderedIndex = snapshot.index
        showCard(at: snapshot.index, playEntrance: true, crossfade: false)
    }

    private func showCard(at index: Int, playEntrance: Bool, crossfade: Bool) {
        let palette = content.palette(at: index, theme: theme)
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
            fade.duration = crossfade ? 0.2 : 0.25
            newBackground.add(fade, forKey: "fade")
            newBackground.opacity = 1
            CATransaction.commit()
        } else {
            view.layer.insertSublayer(newBackground, at: 0)
        }
        backgroundLayer = newBackground

        let applyChrome = {
            self.headerLabel.textColor = palette.secondary
            self.hintLabel.textColor = palette.tertiary
            self.hintLabel.text = self.content.hint(at: index)
            self.hintLabel.isHidden = self.hintLabel.text == nil
            self.closeButton.tintColor = palette.ink
            self.closeButton.backgroundColor = palette.closeBackground
            for (segmentIndex, segment) in self.progressFills.enumerated() {
                segment.track.backgroundColor = palette.progressUpcoming
                segment.fill.backgroundColor = palette.progressDone
                if !crossfade {
                    segment.width.constant = segmentIndex < index ? segment.track.bounds.width : 0
                }
            }
        }
        if crossfade {
            UIView.transition(with: chrome, duration: 0.2, options: .transitionCrossDissolve, animations: applyChrome)
        } else {
            applyChrome()
        }
        setNeedsStatusBarAppearanceUpdate()

        let outgoing = currentCard
        outgoing?.stopAnimations()
        let cardView = content.makeCard(at: index, palette: palette)
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
        if crossfade {
            UIView.animate(withDuration: 0.2, animations: {
                cardView.alpha = 1
                outgoing?.alpha = 0
            }, completion: { _ in
                outgoing?.removeFromSuperview()
            })
        } else {
            outgoing?.removeFromSuperview()
            UIView.animate(withDuration: 0.2) { cardView.alpha = 1 }
        }
        // Rebuilt for a theme change → final state, no replayed entrance.
        cardView.playEntrance(reduceMotion: playEntrance ? reduceMotion : true)
        if playEntrance { UIAccessibility.post(notification: .screenChanged, argument: cardView) }
    }

    private func renderProgress(_ progress: Double) {
        let index = content.player.index
        guard index < progressFills.count else { return }
        let segment = progressFills[index]
        segment.width.constant = segment.track.bounds.width * CGFloat(progress)
    }

    // MARK: - Gestures

    @objc private func didTap(_ recognizer: UITapGestureRecognizer) {
        // Buttons handle their own taps; only bare card/background taps navigate.
        let location = recognizer.location(in: view)
        if let hit = view.hitTest(location, with: nil), hit is UIControl || hit.superview is UIControl { return }
        if location.x < view.bounds.width / 3 {
            content.player.previous()
        } else if !content.player.isLastCard {
            content.player.next()
        }
    }

    @objc private func didHold(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began: content.player.setPaused(true)
        case .ended, .cancelled, .failed: content.player.setPaused(false)
        default: break
        }
    }

    @objc private func didPan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: view)
        switch recognizer.state {
        case .began:
            content.player.setPaused(true)
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
                content.close()
            } else {
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.4) {
                    self.view.center = self.dismissStartCenter
                    self.view.transform = .identity
                    self.view.layer.cornerRadius = 0
                }
                content.player.setPaused(false)
            }
        default:
            break
        }
    }
}
