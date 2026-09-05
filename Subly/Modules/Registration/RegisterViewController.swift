import UIKit

/// v5 Register (screen 00B): small logo tile, headline "No account. This
/// device is your account.", subcopy, 3-row trust card with lime-tinted icon
/// tiles, bottom-pinned lime "Continue with the device" + legal caption.
/// The device ID itself is never shown. No back navigation.
final class RegisterViewController: UIViewController {

    private let viewModel: RegisterViewModel
    private let haptics: HapticsService

    init(viewModel: RegisterViewModel, haptics: HapticsService) {
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

    // MARK: - Setup

    private func configureHierarchy() {
        // Leading-aligned wrapper so the fixed-size tile keeps its 56pt width
        // inside the stack's `.fill` alignment.
        let logoView = SublyLogoView(side: 56)
        let logoWrapper = UIView()
        logoWrapper.translatesAutoresizingMaskIntoConstraints = false
        logoWrapper.addSubview(logoView)
        NSLayoutConstraint.activate([
            logoView.leadingAnchor.constraint(equalTo: logoWrapper.leadingAnchor),
            logoView.topAnchor.constraint(equalTo: logoWrapper.topAnchor),
            logoView.bottomAnchor.constraint(equalTo: logoWrapper.bottomAnchor)
        ])

        let headlineLabel = UILabel()
        headlineLabel.text = Strings.Registration.headline
        headlineLabel.font = DesignSystem.Typography.scaled(30, weight: .heavy, relativeTo: .largeTitle)
        headlineLabel.textColor = DesignSystem.Colors.textPrimary
        headlineLabel.numberOfLines = 0
        headlineLabel.adjustsFontForContentSizeCategory = true

        let subcopyLabel = UILabel()
        subcopyLabel.text = Strings.Registration.subcopy
        subcopyLabel.font = DesignSystem.Typography.body
        subcopyLabel.textColor = DesignSystem.Colors.textSecondary
        subcopyLabel.numberOfLines = 0
        subcopyLabel.adjustsFontForContentSizeCategory = true

        // Trust card — 3 grouped rows.
        let trustRowsStack = UIStackView()
        trustRowsStack.axis = .vertical
        trustRowsStack.spacing = 0
        for (index, row) in viewModel.trustRows.enumerated() {
            if index > 0 { trustRowsStack.addArrangedSubview(makeSeparator()) }
            trustRowsStack.addArrangedSubview(makeTrustRow(row))
        }
        let trustCard = SublyCardView()
        trustCard.translatesAutoresizingMaskIntoConstraints = false
        trustRowsStack.translatesAutoresizingMaskIntoConstraints = false
        trustCard.addSubview(trustRowsStack)
        let pad = DesignSystem.Spacing.cardPadding
        NSLayoutConstraint.activate([
            trustRowsStack.topAnchor.constraint(equalTo: trustCard.topAnchor, constant: 4),
            trustRowsStack.leadingAnchor.constraint(equalTo: trustCard.leadingAnchor, constant: pad),
            trustRowsStack.trailingAnchor.constraint(equalTo: trustCard.trailingAnchor, constant: -pad),
            trustRowsStack.bottomAnchor.constraint(equalTo: trustCard.bottomAnchor, constant: -4)
        ])

        let contentStack = UIStackView(arrangedSubviews: [
            logoWrapper, headlineLabel, subcopyLabel, trustCard
        ])
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = DesignSystem.Spacing.lg
        contentStack.setCustomSpacing(DesignSystem.Spacing.xl, after: logoWrapper)
        contentStack.setCustomSpacing(DesignSystem.Spacing.sm, after: headlineLabel)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.addSubview(contentStack)
        view.addSubview(scrollView)

        // Bottom-pinned primary button + legal caption.
        let continueButton = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = Strings.Registration.continueButton
        config.baseBackgroundColor = DesignSystem.Colors.accent
        config.baseForegroundColor = DesignSystem.Colors.accentOnFill
        config.background.cornerRadius = DesignSystem.Radius.button
        continueButton.configuration = config
        continueButton.titleLabel?.font = DesignSystem.Typography.rowTitle
        continueButton.titleLabel?.adjustsFontForContentSizeCategory = true
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        continueButton.addTarget(self, action: #selector(didTapContinue), for: .touchUpInside)

        let legalLabel = UILabel()
        legalLabel.text = Strings.Registration.legal
        legalLabel.font = DesignSystem.Typography.caption
        legalLabel.textColor = DesignSystem.Colors.textTertiary
        legalLabel.textAlignment = .center
        legalLabel.numberOfLines = 0
        legalLabel.adjustsFontForContentSizeCategory = true

        let bottomStack = UIStackView(arrangedSubviews: [continueButton, legalLabel])
        bottomStack.axis = .vertical
        bottomStack.spacing = DesignSystem.Spacing.sm
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomStack)

        let inset = DesignSystem.Spacing.screenH
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomStack.topAnchor, constant: -DesignSystem.Spacing.md),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: DesignSystem.Spacing.lg),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: inset),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -inset),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -inset * 2),

            bottomStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: inset),
            bottomStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -inset),
            bottomStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    private func makeTrustRow(_ row: RegisterViewModel.TrustRow) -> UIView {
        let iconTile = UIImageView(image: UIImage(systemName: row.systemIcon))
        iconTile.contentMode = .center
        iconTile.tintColor = DesignSystem.Colors.accentText
        iconTile.backgroundColor = DesignSystem.Colors.accentTint
        iconTile.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        iconTile.layer.cornerRadius = 10
        iconTile.layer.cornerCurve = .continuous
        iconTile.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconTile.widthAnchor.constraint(equalToConstant: 36),
            iconTile.heightAnchor.constraint(equalToConstant: 36)
        ])

        let titleLabel = UILabel()
        titleLabel.text = row.title
        titleLabel.font = DesignSystem.Typography.rowTitle
        titleLabel.textColor = DesignSystem.Colors.textPrimary
        titleLabel.adjustsFontForContentSizeCategory = true

        let bodyLabel = UILabel()
        bodyLabel.text = row.body
        bodyLabel.font = DesignSystem.Typography.footnote
        bodyLabel.textColor = DesignSystem.Colors.textSecondary
        bodyLabel.numberOfLines = 0
        bodyLabel.adjustsFontForContentSizeCategory = true

        let textColumn = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        textColumn.axis = .vertical
        textColumn.spacing = 1

        let rowStack = UIStackView(arrangedSubviews: [iconTile, textColumn])
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = DesignSystem.Spacing.md
        rowStack.isLayoutMarginsRelativeArrangement = true
        rowStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0)
        rowStack.isAccessibilityElement = true
        rowStack.accessibilityLabel = "\(row.title). \(row.body)"
        return rowStack
    }

    private func makeSeparator() -> UIView {
        let line = UIView()
        line.backgroundColor = DesignSystem.Colors.hairline
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    // MARK: - Actions

    @objc private func didTapContinue() {
        haptics.play(.lightImpact)
        viewModel.didTapContinue()
    }
}
