import UIKit

/// v5 Onboarding (screen 01): centered logo tile (92×92) + headline
/// "Know exactly where money goes." + subcopy; bottom-pinned primary button
/// "Add your first subscription" + text button "Explore with sample data".
/// One primary action.
final class OnboardingViewController: UIViewController {

    private let viewModel: OnboardingViewModel
    private let haptics: HapticsService

    private let logoView = SublyLogoView(side: 92)
    private let headlineLabel = UILabel()
    private let subcopyLabel = UILabel()
    private let addButton = UIButton(type: .system)
    private let sampleButton = UIButton(type: .system)

    init(viewModel: OnboardingViewModel, haptics: HapticsService) {
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
    }

    private func configureHierarchy() {
        headlineLabel.text = Strings.Onboarding.headline
        headlineLabel.font = DesignSystem.Typography.scaled(33, weight: .heavy, relativeTo: .largeTitle)
        headlineLabel.textColor = DesignSystem.Colors.textPrimary
        headlineLabel.textAlignment = .center
        headlineLabel.numberOfLines = 0
        headlineLabel.adjustsFontForContentSizeCategory = true

        subcopyLabel.text = Strings.Onboarding.subcopy
        subcopyLabel.font = DesignSystem.Typography.body
        subcopyLabel.textColor = DesignSystem.Colors.textSecondary
        subcopyLabel.textAlignment = .center
        subcopyLabel.numberOfLines = 0
        subcopyLabel.adjustsFontForContentSizeCategory = true

        let heroStack = UIStackView(arrangedSubviews: [logoView, headlineLabel, subcopyLabel])
        heroStack.axis = .vertical
        heroStack.alignment = .center
        heroStack.spacing = DesignSystem.Spacing.lg
        heroStack.setCustomSpacing(DesignSystem.Spacing.sm, after: headlineLabel)
        heroStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(heroStack)

        var addConfig = UIButton.Configuration.filled()
        addConfig.title = Strings.Onboarding.addFirst
        addConfig.baseBackgroundColor = DesignSystem.Colors.accent
        addConfig.baseForegroundColor = DesignSystem.Colors.accentOnFill
        addConfig.background.cornerRadius = DesignSystem.Radius.button
        addConfig.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        addButton.configuration = addConfig
        addButton.titleLabel?.font = DesignSystem.Typography.rowTitle
        addButton.titleLabel?.adjustsFontForContentSizeCategory = true
        addButton.addTarget(self, action: #selector(didTapAdd), for: .touchUpInside)

        var sampleConfig = UIButton.Configuration.plain()
        sampleConfig.title = Strings.Onboarding.sampleData
        sampleConfig.baseForegroundColor = DesignSystem.Colors.accentText
        sampleConfig.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        sampleButton.configuration = sampleConfig
        sampleButton.titleLabel?.font = DesignSystem.Typography.body
        sampleButton.titleLabel?.adjustsFontForContentSizeCategory = true
        sampleButton.addTarget(self, action: #selector(didTapSample), for: .touchUpInside)

        let buttonsStack = UIStackView(arrangedSubviews: [addButton, sampleButton])
        buttonsStack.axis = .vertical
        buttonsStack.spacing = DesignSystem.Spacing.xs
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonsStack)

        let inset = DesignSystem.Spacing.screenH
        NSLayoutConstraint.activate([
            heroStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            heroStack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            heroStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            heroStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),

            buttonsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: inset),
            buttonsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -inset),
            buttonsStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    @objc private func didTapAdd() {
        haptics.play(.lightImpact)
        viewModel.didTapAddFirst()
    }

    @objc private func didTapSample() {
        haptics.play(.selection)
        viewModel.didTapSampleData()
    }
}
