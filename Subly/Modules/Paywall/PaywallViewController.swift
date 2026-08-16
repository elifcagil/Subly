import UIKit

final class PaywallViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: PaywallViewModel
    private let haptics: HapticsService

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentStack: UIStackView!
    @IBOutlet private weak var bottomBar: UIView!
    @IBOutlet private weak var bottomStack: UIStackView!

    private let heroIconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let benefitsStack = UIStackView()
    private let plansStack = UIStackView()
    private let trustLabel = UILabel()

    private let subscribeButton = SublyPrimaryButton(type: .system)
    private let restoreButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    private var saveBarItem: UIBarButtonItem?
    private var planCards: [PaywallPlanCard] = []

    // MARK: - Init

    init(viewModel: PaywallViewModel, haptics: HapticsService) {
        self.viewModel = viewModel
        self.haptics = haptics
        super.init(nibName: String(describing: Self.self), bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported.")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignSystem.Colors.background
        title = Strings.Paywall.navTitle
        configureNavigationBar()
        configureHierarchy()
        configureBindings()
        viewModel.load()
    }

    // MARK: - Configuration

    private func configureNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(didTapClose)
        )
    }

    private func configureHierarchy() {
        configureBottomBarContent()
        configureScrollContent()
        configureHero()
        configureBenefits()
        configurePlans()
        configureTrust()
    }

    private func configureBottomBarContent() {
        subscribeButton.translatesAutoresizingMaskIntoConstraints = false
        subscribeButton.setTitle(Strings.Paywall.subscribe)
        subscribeButton.addTarget(self, action: #selector(didTapSubscribe), for: .touchUpInside)

        restoreButton.translatesAutoresizingMaskIntoConstraints = false
        restoreButton.setTitle(Strings.Paywall.restore, for: .normal)
        restoreButton.titleLabel?.font = DesignSystem.Typography.footnote
        restoreButton.titleLabel?.adjustsFontForContentSizeCategory = true
        restoreButton.tintColor = DesignSystem.Colors.textSecondary
        restoreButton.addTarget(self, action: #selector(didTapRestore), for: .touchUpInside)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true

        bottomStack.addArrangedSubview(subscribeButton)
        bottomStack.addArrangedSubview(restoreButton)
        bottomBar.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            subscribeButton.leadingAnchor.constraint(equalTo: bottomStack.leadingAnchor),
            subscribeButton.trailingAnchor.constraint(equalTo: bottomStack.trailingAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: subscribeButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: subscribeButton.centerYAnchor)
        ])
    }

    private func configureScrollContent() {
        contentStack.spacing = DesignSystem.Spacing.xl
    }

    private func configureHero() {
        // Premium gradient header (coral → pink) with white content.
        heroIconView.translatesAutoresizingMaskIntoConstraints = false
        heroIconView.contentMode = .center
        heroIconView.tintColor = .white
        heroIconView.image = UIImage(systemName: "star.fill")
        heroIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
        heroIconView.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        heroIconView.layer.cornerCurve = .continuous
        heroIconView.layer.cornerRadius = 14
        heroIconView.isAccessibilityElement = false
        NSLayoutConstraint.activate([
            heroIconView.widthAnchor.constraint(equalToConstant: 44),
            heroIconView.heightAnchor.constraint(equalToConstant: 44)
        ])

        titleLabel.text = Strings.Paywall.headline
        titleLabel.font = DesignSystem.Typography.largeTitle
        titleLabel.textColor = .white
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 0

        subtitleLabel.text = Strings.Paywall.subtitle
        subtitleLabel.font = DesignSystem.Typography.body
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textAlignment = .left
        subtitleLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [heroIconView, titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = DesignSystem.Spacing.sm
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let heroCard = SublyGradientView()
        heroCard.configurePremium()
        heroCard.layer.cornerRadius = DesignSystem.Radius.hero
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        DesignSystem.Shadow.apply(DesignSystem.Shadow.premium, to: heroCard.layer)
        heroCard.addSubview(textStack)
        let pad: CGFloat = 22
        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: pad),
            textStack.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: pad),
            textStack.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -pad),
            textStack.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -pad)
        ])

        contentStack.addArrangedSubview(heroCard)
    }

    private func configureBenefits() {
        benefitsStack.axis = .vertical
        benefitsStack.spacing = DesignSystem.Spacing.md
        for benefit in [
            ("chart.line.uptrend.xyaxis", Strings.Paywall.benefitInsights),
            ("icloud", Strings.Paywall.benefitSync),
            ("calendar.badge.plus", Strings.Paywall.benefitCalendar),
            ("sparkles", Strings.Paywall.benefitFuture)
        ] {
            benefitsStack.addArrangedSubview(makeBenefitRow(icon: benefit.0, text: benefit.1))
        }
        contentStack.addArrangedSubview(benefitsStack)
    }

    private func configurePlans() {
        plansStack.axis = .vertical
        plansStack.spacing = DesignSystem.Spacing.md
        contentStack.addArrangedSubview(plansStack)
    }

    private func configureTrust() {
        trustLabel.text = Strings.Paywall.trust
        trustLabel.font = DesignSystem.Typography.caption
        trustLabel.textColor = DesignSystem.Colors.textTertiary
        trustLabel.adjustsFontForContentSizeCategory = true
        trustLabel.textAlignment = .center
        trustLabel.numberOfLines = 0
        contentStack.addArrangedSubview(trustLabel)
    }

    private func makeBenefitRow(icon: String, text: String) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = DesignSystem.Colors.accent
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(font: DesignSystem.Typography.body)
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = text
        label.font = DesignSystem.Typography.body
        label.textColor = DesignSystem.Colors.textPrimary
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = DesignSystem.Spacing.md
        stack.isAccessibilityElement = true
        stack.accessibilityLabel = text
        return stack
    }

    private func configureBindings() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        viewModel.onErrorMessage = { [weak self] message in
            self?.haptics.play(.error)
            self?.present(errorMessage: message)
        }
    }

    // MARK: - Rendering

    private func render(_ state: ViewState<PaywallViewModel.Snapshot>) {
        switch state {
        case .idle, .loading:
            subscribeButton.isHidden = true
            activityIndicator.startAnimating()
        case .loaded(let snapshot):
            activityIndicator.stopAnimating()
            subscribeButton.isHidden = false
            apply(snapshot)
        case .empty:
            activityIndicator.stopAnimating()
            subscribeButton.isHidden = true
        case .failed(let message):
            activityIndicator.stopAnimating()
            subscribeButton.isHidden = true
            present(errorMessage: message)
        }
    }

    private func apply(_ snapshot: PaywallViewModel.Snapshot) {
        if snapshot.isCurrentlyPlus {
            renderAlreadyPlus()
            return
        }
        if snapshot.products.isEmpty {
            renderUnavailable()
            return
        }
        renderPlans(snapshot)
        renderActionState(snapshot)
    }

    private func renderAlreadyPlus() {
        plansStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let label = UILabel()
        label.text = Strings.Paywall.alreadyPlus
        label.font = DesignSystem.Typography.body
        label.textColor = DesignSystem.Colors.textPrimary
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        plansStack.addArrangedSubview(label)
        subscribeButton.isHidden = true
        restoreButton.isHidden = true
        trustLabel.isHidden = true
    }

    private func renderUnavailable() {
        plansStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let label = UILabel()
        label.text = Strings.Paywall.unavailable
        label.font = DesignSystem.Typography.subhead
        label.textColor = DesignSystem.Colors.textSecondary
        label.numberOfLines = 0
        label.textAlignment = .center
        plansStack.addArrangedSubview(label)
        subscribeButton.isHidden = true
    }

    private func renderPlans(_ snapshot: PaywallViewModel.Snapshot) {
        plansStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        planCards.removeAll()

        for product in snapshot.products {
            let card = PaywallPlanCard()
            let viewModel = makePlanCardViewModel(for: product)
            let isSelected = product.id == snapshot.selectedProductID
            card.configure(with: viewModel, isSelected: isSelected)
            card.addTarget(self, action: #selector(planTapped(_:)), for: .touchUpInside)
            plansStack.addArrangedSubview(card)
            planCards.append(card)
        }
    }

    private func renderActionState(_ snapshot: PaywallViewModel.Snapshot) {
        subscribeButton.isHidden = false
        subscribeButton.isEnabled = !snapshot.isPurchasing && !snapshot.isRestoring && snapshot.selectedProductID != nil
        if snapshot.isPurchasing {
            subscribeButton.setTitle("…")
            activityIndicator.startAnimating()
        } else {
            subscribeButton.setTitle(Strings.Paywall.subscribe)
            activityIndicator.stopAnimating()
        }

        restoreButton.isHidden = false
        restoreButton.isEnabled = !snapshot.isPurchasing && !snapshot.isRestoring
        restoreButton.setTitle(snapshot.isRestoring ? Strings.Paywall.restoring : Strings.Paywall.restore, for: .normal)
        trustLabel.isHidden = false
    }

    private func makePlanCardViewModel(for product: SublyProduct) -> PaywallPlanCard.ViewModel {
        let planTitle = planTitle(for: product)
        let priceText = Strings.Paywall.pricePerPeriod(product.displayPrice, period: planTitle.lowercased())
        let perMonth = product.perMonthDisplayPrice.map { Strings.Paywall.perMonth($0) }
        return PaywallPlanCard.ViewModel(
            productID: product.id,
            planTitle: planTitle,
            priceText: priceText,
            perMonthText: perMonth,
            highlightAsBest: product.periodUnit == .year
        )
    }

    private func planTitle(for product: SublyProduct) -> String {
        switch product.periodUnit {
        case .month: return Strings.Paywall.planMonthly
        case .year: return Strings.Paywall.planYearly
        default: return product.displayName
        }
    }

    private func present(errorMessage: String) {
        let alert = UIAlertController(title: nil, message: errorMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Strings.Common.ok, style: .default))
        present(alert, animated: true)
    }

    // MARK: - Actions

    @objc private func didTapClose() {
        viewModel.didTapClose()
    }

    @objc private func didTapSubscribe() {
        haptics.play(.lightImpact)
        viewModel.purchaseSelected()
    }

    @objc private func didTapRestore() {
        haptics.play(.lightImpact)
        viewModel.restore()
    }

    @objc private func planTapped(_ sender: PaywallPlanCard) {
        haptics.play(.selection)
        viewModel.didSelectProduct(sender.productID)
    }
}
