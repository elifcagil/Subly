import UIKit

/// v5 branded launch screen: calm base background (warm-white / graphite),
/// centered dark logo tile with the 3-bar lime mark, wordmark "Subly",
/// tagline, and a thin determinate accent progress bar near the bottom.
/// See `SplashViewModel`.
final class SplashViewController: UIViewController {

    private let viewModel: SplashViewModel

    private let logoView = SublyLogoView(side: 92)
    private let wordmarkLabel = UILabel()
    private let taglineLabel = UILabel()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private let preparingLabel = UILabel()
    private var progressFillWidth: NSLayoutConstraint?

    private var hasStarted = false

    init(viewModel: SplashViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported. Use init(viewModel:).")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureHierarchy()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasStarted else { return }
        hasStarted = true
        viewModel.start()
        playSequence()
    }

    // MARK: - Setup

    private func configureHierarchy() {
        view.backgroundColor = DesignSystem.Colors.background

        wordmarkLabel.text = "Subly"
        wordmarkLabel.font = DesignSystem.Typography.title
        wordmarkLabel.textColor = DesignSystem.Colors.textPrimary
        wordmarkLabel.textAlignment = .center
        wordmarkLabel.adjustsFontForContentSizeCategory = true

        taglineLabel.text = Strings.Splash.tagline
        taglineLabel.font = DesignSystem.Typography.secondaryMeta
        taglineLabel.textColor = DesignSystem.Colors.textSecondary
        taglineLabel.textAlignment = .center
        taglineLabel.numberOfLines = 0
        taglineLabel.adjustsFontForContentSizeCategory = true

        let stack = UIStackView(arrangedSubviews: [logoView, wordmarkLabel, taglineLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = DesignSystem.Spacing.md
        stack.setCustomSpacing(DesignSystem.Spacing.lg, after: logoView)
        stack.setCustomSpacing(DesignSystem.Spacing.xs, after: wordmarkLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.backgroundColor = DesignSystem.Colors.accent.withAlphaComponent(0.18)
        progressTrack.layer.cornerRadius = 2
        progressTrack.clipsToBounds = true
        view.addSubview(progressTrack)

        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressFill.backgroundColor = DesignSystem.Colors.accent
        progressFill.layer.cornerRadius = 2
        progressTrack.addSubview(progressFill)

        // "Preparing your device profile…" — Keychain registration check
        // happens behind this splash (00).
        preparingLabel.text = Strings.Splash.preparing
        preparingLabel.font = DesignSystem.Typography.footnote
        preparingLabel.textColor = DesignSystem.Colors.textTertiary
        preparingLabel.textAlignment = .center
        preparingLabel.adjustsFontForContentSizeCategory = true
        preparingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(preparingLabel)

        let fillWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)
        progressFillWidth = fillWidth

        NSLayoutConstraint.activate([
            preparingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            preparingLabel.bottomAnchor.constraint(equalTo: progressTrack.topAnchor, constant: -10),
            preparingLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),

            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),

            progressTrack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressTrack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            progressTrack.widthAnchor.constraint(equalToConstant: 140),
            progressTrack.heightAnchor.constraint(equalToConstant: 4),

            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            fillWidth
        ])

        // VoiceOver: announce the brand; the progress bar is decorative.
        view.accessibilityElements = [logoView]
        progressTrack.isAccessibilityElement = false
    }

    // MARK: - Motion

    private func playSequence() {
        view.layoutIfNeeded()
        let duration = viewModel.displayDuration

        // Fill the progress bar across the display window.
        progressFillWidth?.constant = 140
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseInOut],
            animations: { [weak self] in self?.progressTrack.layoutIfNeeded() }
        )

        // Hand off once the fill completes — AppCoordinator cross-dissolves the
        // window root, so the splash must stay visible (fading it here would
        // expose a black window frame mid-transition).
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.viewModel.didFinishAnimation()
        }
    }
}
