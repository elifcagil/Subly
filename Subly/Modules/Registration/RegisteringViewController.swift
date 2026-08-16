import UIKit

/// v5 Registering (screen 00C): logo tile that gains a lime check badge on
/// success, "Device registered" title, masked ID, "Taking you to your
/// dashboard…" caption and an indeterminate lime progress bar. On failure the
/// bar is replaced by a calm message + "Try again".
final class RegisteringViewController: UIViewController {

    private let viewModel: RegisteringViewModel
    private let haptics: HapticsService

    private let logoView = SublyLogoView(side: 92)
    private let checkBadge = UIImageView()
    private let titleLabel = UILabel()
    private let captionLabel = UILabel()
    private let progressBar = UIProgressView(progressViewStyle: .bar)
    private let retryButton = UIButton(type: .system)

    private var hasStarted = false

    init(viewModel: RegisteringViewModel, haptics: HapticsService) {
        self.viewModel = viewModel
        self.haptics = haptics
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported. Use init(viewModel:haptics:).")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignSystem.Colors.background
        configureHierarchy()
        configureBindings()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasStarted else { return }
        hasStarted = true
        viewModel.start()
    }

    // MARK: - Setup

    private func configureHierarchy() {
        // Lime check badge, bottom-right of the tile, ring in background color.
        checkBadge.image = UIImage(systemName: "checkmark.circle.fill")
        checkBadge.tintColor = DesignSystem.Colors.accent
        checkBadge.backgroundColor = DesignSystem.Colors.background
        checkBadge.layer.cornerRadius = 15
        checkBadge.layer.borderWidth = 3
        checkBadge.layer.borderColor = DesignSystem.Colors.background.cgColor
        checkBadge.clipsToBounds = true
        checkBadge.alpha = 0
        checkBadge.translatesAutoresizingMaskIntoConstraints = false

        let logoContainer = UIView()
        logoContainer.translatesAutoresizingMaskIntoConstraints = false
        logoContainer.addSubview(logoView)
        logoContainer.addSubview(checkBadge)

        titleLabel.text = Strings.Registration.registeredTitle
        titleLabel.font = DesignSystem.Typography.title
        titleLabel.textColor = DesignSystem.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.alpha = 0

        captionLabel.text = Strings.Registration.takingToDashboard
        captionLabel.font = DesignSystem.Typography.footnote
        captionLabel.textColor = DesignSystem.Colors.textSecondary
        captionLabel.textAlignment = .center
        captionLabel.numberOfLines = 0
        captionLabel.adjustsFontForContentSizeCategory = true

        progressBar.progressTintColor = DesignSystem.Colors.accent
        progressBar.trackTintColor = DesignSystem.Colors.accent.withAlphaComponent(0.18)
        progressBar.layer.cornerRadius = 2
        progressBar.clipsToBounds = true
        progressBar.translatesAutoresizingMaskIntoConstraints = false

        var retryConfig = UIButton.Configuration.filled()
        retryConfig.title = Strings.Common.retry
        retryConfig.baseBackgroundColor = DesignSystem.Colors.accent
        retryConfig.baseForegroundColor = DesignSystem.Colors.accentOnFill
        retryConfig.background.cornerRadius = DesignSystem.Radius.button
        retryConfig.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 26, bottom: 13, trailing: 26)
        retryButton.configuration = retryConfig
        retryButton.titleLabel?.font = DesignSystem.Typography.rowTitle
        retryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        retryButton.isHidden = true
        retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [logoContainer, titleLabel, captionLabel, retryButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = DesignSystem.Spacing.sm
        stack.setCustomSpacing(DesignSystem.Spacing.lg, after: logoContainer)
        stack.setCustomSpacing(DesignSystem.Spacing.md, after: captionLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        view.addSubview(progressBar)

        NSLayoutConstraint.activate([
            logoContainer.widthAnchor.constraint(equalToConstant: 92),
            logoContainer.heightAnchor.constraint(equalToConstant: 92),
            logoView.centerXAnchor.constraint(equalTo: logoContainer.centerXAnchor),
            logoView.centerYAnchor.constraint(equalTo: logoContainer.centerYAnchor),
            checkBadge.widthAnchor.constraint(equalToConstant: 30),
            checkBadge.heightAnchor.constraint(equalToConstant: 30),
            checkBadge.trailingAnchor.constraint(equalTo: logoContainer.trailingAnchor, constant: 8),
            checkBadge.bottomAnchor.constraint(equalTo: logoContainer.bottomAnchor, constant: 8),

            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),

            progressBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            progressBar.widthAnchor.constraint(equalToConstant: 140),
            progressBar.heightAnchor.constraint(equalToConstant: 4)
        ])
    }

    private func configureBindings() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
    }

    // MARK: - Rendering

    private func render(_ state: RegisteringViewModel.State) {
        switch state {
        case .working:
            titleLabel.alpha = 0
            checkBadge.alpha = 0
            captionLabel.text = Strings.Registration.takingToDashboard
            captionLabel.textColor = DesignSystem.Colors.textSecondary
            retryButton.isHidden = true
            progressBar.isHidden = false
            startIndeterminateBar()
        case .succeeded:
            haptics.play(.success)
            UIView.animate(withDuration: 0.25) {
                self.titleLabel.alpha = 1
                self.checkBadge.alpha = 1
            }
        case .failed(let message):
            haptics.play(.error)
            titleLabel.alpha = 0
            checkBadge.alpha = 0
            captionLabel.text = message
            captionLabel.textColor = DesignSystem.Colors.textPrimary
            retryButton.isHidden = false
            progressBar.isHidden = true
        }
    }

    /// Loops the bar fill to read as indeterminate.
    private func startIndeterminateBar() {
        progressBar.setProgress(0, animated: false)
        UIView.animate(withDuration: 1.1, delay: 0.1, options: [.repeat, .curveEaseInOut]) {
            self.progressBar.setProgress(1, animated: true)
        }
    }

    // MARK: - Actions

    @objc private func didTapRetry() {
        haptics.play(.lightImpact)
        viewModel.retry()
    }
}
