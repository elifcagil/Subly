import UIKit

final class AddEditSubscriptionViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: AddEditSubscriptionViewModel
    private let haptics: HapticsService

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var formStack: UIStackView!
    private let savingIndicator = UIActivityIndicatorView(style: .medium)

    private let nameField = UITextField()
    private let amountField = UITextField()
    private let currencyButton = UIButton(type: .system)
    private let billingCyclePills = SublySegmentedPills()
    private let renewalDatePicker = UIDatePicker()
    private let categoryButton = UIButton(type: .system)
    private let reminderStack = UIStackView()
    private let notesTextView = UITextView()
    private var reminderButtons: [Int: UIButton] = [:]

    /// v5 live impact footer (accent-tint card).
    private let impactCard = SublyCardView()
    private let impactLabel = UILabel()

    private var saveBarItem: UIBarButtonItem?
    private var currentDraft: SubscriptionDraft?
    private var currentCategories: [Category] = []
    private let billingCycleOrder: [BillingCycle] = BillingCycle.allCases
    private var reminderOptionValues: [Int] = []

    /// Called when the user taps the Currency row. The coordinator handles
    /// presenting the picker and feeds the chosen code back to the view model.
    var onPickCurrencyRequested: ((String) -> Void)?

    // MARK: - Init

    init(viewModel: AddEditSubscriptionViewModel, haptics: HapticsService) {
        self.viewModel = viewModel
        self.haptics = haptics
        super.init(nibName: String(describing: Self.self), bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported. Use init(viewModel:haptics:).")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignSystem.Colors.background
        title = viewModel.title
        configureNavigationBar()
        configureHierarchy()
        configureBindings()
        viewModel.load()
    }

    // MARK: - Configuration

    private func configureNavigationBar() {
        let cancel = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(didTapCancel)
        )
        cancel.accessibilityHint = Strings.AddEdit.cancelHint
        navigationItem.leftBarButtonItem = cancel

        let save = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(didTapSave)
        )
        save.accessibilityHint = Strings.AddEdit.saveHint
        navigationItem.rightBarButtonItem = save
        saveBarItem = save
    }

    private func configureHierarchy() {
        scrollView.alwaysBounceVertical = true
        configureFields()
    }

    private func configureFields() {
        styleTextField(nameField, placeholder: Strings.AddEdit.namePlaceholder)
        nameField.autocapitalizationType = .words
        nameField.returnKeyType = .next
        nameField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)

        styleTextField(amountField, placeholder: Strings.AddEdit.amountPlaceholder)
        amountField.keyboardType = .decimalPad
        amountField.addTarget(self, action: #selector(amountChanged), for: .editingChanged)

        currencyButton.translatesAutoresizingMaskIntoConstraints = false
        currencyButton.contentHorizontalAlignment = .leading
        currencyButton.titleLabel?.font = DesignSystem.Typography.body
        currencyButton.titleLabel?.adjustsFontForContentSizeCategory = true
        currencyButton.tintColor = DesignSystem.Colors.accent
        currencyButton.accessibilityHint = Strings.AddEdit.currencyHint
        currencyButton.addTarget(self, action: #selector(didTapCurrency), for: .touchUpInside)

        billingCyclePills.translatesAutoresizingMaskIntoConstraints = false
        billingCyclePills.configure(
            segments: billingCycleOrder.map { .init(title: $0.localizedName) },
            selectedIndex: 0
        )
        billingCyclePills.onSelect = { [weak self] index in
            guard let self, self.billingCycleOrder.indices.contains(index) else { return }
            self.haptics.play(.selection)
            self.viewModel.updateBillingCycle(self.billingCycleOrder[index])
        }

        renewalDatePicker.translatesAutoresizingMaskIntoConstraints = false
        renewalDatePicker.datePickerMode = .date
        renewalDatePicker.preferredDatePickerStyle = .compact
        // A renewal is always upcoming — no past dates.
        renewalDatePicker.minimumDate = Date()
        renewalDatePicker.addTarget(self, action: #selector(renewalDateChanged), for: .valueChanged)

        categoryButton.translatesAutoresizingMaskIntoConstraints = false
        categoryButton.contentHorizontalAlignment = .leading
        categoryButton.titleLabel?.font = DesignSystem.Typography.body
        categoryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        categoryButton.tintColor = DesignSystem.Colors.accent
        categoryButton.showsMenuAsPrimaryAction = true

        reminderStack.axis = .horizontal
        reminderStack.spacing = DesignSystem.Spacing.sm
        reminderStack.distribution = .fillProportionally
        reminderStack.translatesAutoresizingMaskIntoConstraints = false

        notesTextView.translatesAutoresizingMaskIntoConstraints = false
        notesTextView.font = DesignSystem.Typography.body
        notesTextView.backgroundColor = DesignSystem.Colors.surface
        notesTextView.layer.cornerRadius = DesignSystem.Radius.md
        notesTextView.layer.cornerCurve = .continuous
        notesTextView.textContainerInset = UIEdgeInsets(
            top: DesignSystem.Spacing.sm,
            left: DesignSystem.Spacing.sm,
            bottom: DesignSystem.Spacing.sm,
            right: DesignSystem.Spacing.sm
        )
        notesTextView.adjustsFontForContentSizeCategory = true
        notesTextView.delegate = self
        notesTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true

        // v5 live impact footer — accent-tint card, olive/lime text.
        impactLabel.font = DesignSystem.Typography.subhead
        impactLabel.textColor = DesignSystem.Colors.accentText
        impactLabel.adjustsFontForContentSizeCategory = true
        impactLabel.numberOfLines = 0
        impactLabel.translatesAutoresizingMaskIntoConstraints = false
        impactCard.style = .accentTint
        impactCard.translatesAutoresizingMaskIntoConstraints = false
        impactCard.isHidden = true
        impactCard.addSubview(impactLabel)
        NSLayoutConstraint.activate([
            impactLabel.topAnchor.constraint(equalTo: impactCard.topAnchor, constant: 14),
            impactLabel.leadingAnchor.constraint(equalTo: impactCard.leadingAnchor, constant: DesignSystem.Spacing.cardPadding),
            impactLabel.trailingAnchor.constraint(equalTo: impactCard.trailingAnchor, constant: -DesignSystem.Spacing.cardPadding),
            impactLabel.bottomAnchor.constraint(equalTo: impactCard.bottomAnchor, constant: -14)
        ])

        formStack.addArrangedSubview(makeField(title: Strings.AddEdit.fieldName, content: nameField))
        formStack.addArrangedSubview(makeField(title: Strings.AddEdit.fieldAmount, content: amountField))
        formStack.addArrangedSubview(makeField(title: Strings.AddEdit.fieldCurrency, content: currencyButton))
        formStack.addArrangedSubview(makeField(title: Strings.AddEdit.fieldBillingCycle, content: billingCyclePills))
        formStack.addArrangedSubview(makeField(title: Strings.AddEdit.fieldNextRenewal, content: renewalDatePicker))
        formStack.addArrangedSubview(makeField(title: Strings.AddEdit.fieldCategory, content: categoryButton))
        formStack.addArrangedSubview(makeField(title: Strings.AddEdit.fieldReminders, content: reminderStack))
        formStack.addArrangedSubview(makeField(title: Strings.AddEdit.fieldNotes, content: notesTextView))
        formStack.addArrangedSubview(impactCard)
    }

    private func styleTextField(_ field: UITextField, placeholder: String) {
        field.translatesAutoresizingMaskIntoConstraints = false
        field.borderStyle = .roundedRect
        field.font = DesignSystem.Typography.body
        field.adjustsFontForContentSizeCategory = true
        field.placeholder = placeholder
        field.backgroundColor = DesignSystem.Colors.surface
    }

    private func makeField(title: String, content: UIView) -> FormFieldView {
        let field = FormFieldView(title: title)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.contentView = content
        return field
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

    private func render(_ state: ViewState<AddEditSubscriptionViewModel.Snapshot>) {
        switch state {
        case .idle, .loading, .empty:
            return
        case .failed(let message):
            present(errorMessage: message)
        case .loaded(let snapshot):
            apply(snapshot)
        }
    }

    private func apply(_ snapshot: AddEditSubscriptionViewModel.Snapshot) {
        currentDraft = snapshot.draft
        currentCategories = snapshot.categories
        saveBarItem?.isEnabled = snapshot.isSaveEnabled
        applySavingState(snapshot.isSaving)

        if nameField.text != snapshot.draft.name {
            nameField.text = snapshot.draft.name
        }
        if amountField.text != snapshot.draft.amountText {
            amountField.text = snapshot.draft.amountText
        }
        currencyButton.setTitle(snapshot.currencyDisplay, for: .normal)
        currencyButton.accessibilityLabel = "\(Strings.AddEdit.fieldCurrency): \(snapshot.currencyDisplay)"
        if let index = billingCycleOrder.firstIndex(of: snapshot.draft.billingCycle),
           billingCyclePills.selectedIndex != index {
            billingCyclePills.setSelectedIndex(index)
        }

        // Live impact footer.
        if let impact = snapshot.impactText {
            impactCard.isHidden = false
            impactLabel.text = impact
            impactCard.accessibilityLabel = impact
        } else {
            impactCard.isHidden = true
        }
        if renewalDatePicker.date != snapshot.draft.nextRenewalDate {
            renewalDatePicker.date = snapshot.draft.nextRenewalDate
        }
        if notesTextView.text != snapshot.draft.notes {
            notesTextView.text = snapshot.draft.notes
        }
        configureCategoryMenu(for: snapshot.draft, categories: snapshot.categories)
        configureReminderControl(for: snapshot.draft, options: snapshot.availableLeadOptions)
    }

    private func configureCategoryMenu(for draft: SubscriptionDraft, categories: [Category]) {
        let actions: [UIAction] = [
            UIAction(title: Strings.AddEdit.categoryNone, state: draft.categoryID == nil ? .on : .off) { [weak self] _ in
                self?.viewModel.updateCategory(nil)
            }
        ] + categories.map { category in
            UIAction(
                title: category.localizedName,
                image: UIImage(systemName: category.systemIconName),
                state: draft.categoryID == category.id ? .on : .off
            ) { [weak self] _ in
                self?.viewModel.updateCategory(category.id)
            }
        }
        categoryButton.menu = UIMenu(title: Strings.AddEdit.fieldCategory, children: actions)

        let selectedTitle: String
        if let id = draft.categoryID, let category = categories.first(where: { $0.id == id }) {
            selectedTitle = category.localizedName
        } else {
            selectedTitle = Strings.AddEdit.categoryChoose
        }
        categoryButton.setTitle(selectedTitle, for: .normal)
    }

    private func configureReminderControl(for draft: SubscriptionDraft, options: [Int]) {
        if reminderOptionValues != options {
            reminderOptionValues = options
            reminderStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            reminderButtons.removeAll()
            for value in options {
                let button = makeReminderToggle(value: value)
                reminderStack.addArrangedSubview(button)
                reminderButtons[value] = button
            }
        }
        for (value, button) in reminderButtons {
            let isOn = draft.reminderLeadDays.contains(value)
            applyReminderState(button, isOn: isOn)
        }
    }

    private func makeReminderToggle(value: Int) -> UIButton {
        let title = reminderTitle(for: value)
        var config = UIButton.Configuration.bordered()
        config.title = title
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(
            top: DesignSystem.Spacing.xs,
            leading: DesignSystem.Spacing.md,
            bottom: DesignSystem.Spacing.xs,
            trailing: DesignSystem.Spacing.md
        )
        let button = UIButton(configuration: config)
        button.titleLabel?.font = DesignSystem.Typography.caption
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.tag = value
        button.addTarget(self, action: #selector(reminderTapped(_:)), for: .touchUpInside)
        button.accessibilityLabel = "\(title) reminder"
        return button
    }

    private func applyReminderState(_ button: UIButton, isOn: Bool) {
        var config = button.configuration ?? UIButton.Configuration.bordered()
        config.baseBackgroundColor = isOn ? DesignSystem.Colors.accent : DesignSystem.Colors.surfaceElevated
        config.baseForegroundColor = isOn ? DesignSystem.Colors.accentOnFill : DesignSystem.Colors.textSecondary
        button.configuration = config
        button.accessibilityValue = isOn ? "Enabled" : "Disabled"
    }

    private func reminderTitle(for value: Int) -> String {
        switch value {
        case 0: return Strings.AddEdit.reminderSameDay
        case 1: return Strings.AddEdit.reminderOneDay
        default: return Strings.AddEdit.reminderDays(value)
        }
    }

    private func applySavingState(_ isSaving: Bool) {
        if isSaving {
            savingIndicator.startAnimating()
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: savingIndicator)
            view.isUserInteractionEnabled = false
        } else {
            savingIndicator.stopAnimating()
            if navigationItem.rightBarButtonItem !== saveBarItem {
                navigationItem.rightBarButtonItem = saveBarItem
            }
            view.isUserInteractionEnabled = true
        }
    }

    private func present(errorMessage: String) {
        let alert = UIAlertController(
            title: Strings.AddEdit.couldNotSave,
            message: errorMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Strings.Common.ok, style: .default))
        present(alert, animated: true)
    }

    // MARK: - Actions

    @objc private func nameChanged() {
        viewModel.updateName(nameField.text ?? "")
    }

    @objc private func amountChanged() {
        viewModel.updateAmount(amountField.text ?? "")
    }

    @objc private func didTapCurrency() {
        haptics.play(.selection)
        let code = currentDraft?.currencyCode ?? ""
        onPickCurrencyRequested?(code)
    }

    @objc private func renewalDateChanged() {
        viewModel.updateNextRenewalDate(renewalDatePicker.date)
    }

    @objc private func reminderTapped(_ sender: UIButton) {
        haptics.play(.selection)
        viewModel.toggleReminderLeadDay(sender.tag)
    }

    @objc private func didTapCancel() {
        viewModel.didTapCancel()
    }

    @objc private func didTapSave() {
        view.endEditing(true)
        viewModel.didTapSave()
    }
}

extension AddEditSubscriptionViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        viewModel.updateNotes(textView.text ?? "")
    }
}
