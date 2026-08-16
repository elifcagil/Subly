import UIKit

/// v5 Reminder sheet (screen 13): "Remind me" title + calm subtitle, a
/// single-select list (Same day / 1 day / 3 days / 1 week before) with accent
/// check circles, and a full-width accent "Done" button. Medium detent with a
/// grabber.
final class ReminderSheetViewController: UIViewController {

    struct Option {
        let leadDays: Int
        let title: String
    }

    /// Called with the chosen offset when the user taps Done.
    var onDone: ((Int) -> Void)?

    private let options: [Option]
    private var selectedLeadDays: Int
    private let haptics: HapticsService

    private let optionsStack = UIStackView()

    init(selectedLeadDays: Int?, haptics: HapticsService) {
        self.options = [
            Option(leadDays: 0, title: Strings.Settings.remindersSameDay),
            Option(leadDays: 1, title: Strings.Settings.remindersOneDay),
            Option(leadDays: 3, title: String(format: Strings.Settings.remindersDaysFormat, 3)),
            Option(leadDays: 7, title: Strings.SubscriptionDetail.oneWeekBefore)
        ]
        self.selectedLeadDays = selectedLeadDays ?? 1
        self.haptics = haptics
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignSystem.Colors.sheet
        configureSheetPresentation()
        configureHierarchy()
    }

    private func configureSheetPresentation() {
        guard let sheet = sheetPresentationController else { return }
        sheet.detents = [.medium()]
        sheet.prefersGrabberVisible = true
        sheet.preferredCornerRadius = DesignSystem.Radius.sheet
    }

    private func configureHierarchy() {
        let titleLabel = UILabel()
        titleLabel.text = Strings.SubscriptionDetail.remindMe
        titleLabel.font = DesignSystem.Typography.title
        titleLabel.textColor = DesignSystem.Colors.textPrimary
        titleLabel.adjustsFontForContentSizeCategory = true

        let subtitleLabel = UILabel()
        subtitleLabel.text = Strings.ReminderSheet.subtitle
        subtitleLabel.font = DesignSystem.Typography.footnote
        subtitleLabel.textColor = DesignSystem.Colors.textSecondary
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.numberOfLines = 0

        optionsStack.axis = .vertical
        optionsStack.spacing = 0
        rebuildOptions()

        let doneButton = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = Strings.ReminderSheet.done
        config.baseBackgroundColor = DesignSystem.Colors.accent
        config.baseForegroundColor = DesignSystem.Colors.accentOnFill
        config.background.cornerRadius = DesignSystem.Radius.button
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        doneButton.configuration = config
        doneButton.titleLabel?.font = DesignSystem.Typography.rowTitle
        doneButton.titleLabel?.adjustsFontForContentSizeCategory = true
        doneButton.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, optionsStack, doneButton])
        stack.axis = .vertical
        stack.spacing = DesignSystem.Spacing.lg
        stack.setCustomSpacing(4, after: titleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let inset = DesignSystem.Spacing.screenH
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -inset),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    private func rebuildOptions() {
        optionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, option) in options.enumerated() {
            if index > 0 {
                let line = UIView()
                line.backgroundColor = DesignSystem.Colors.hairline
                line.translatesAutoresizingMaskIntoConstraints = false
                line.heightAnchor.constraint(equalToConstant: 1).isActive = true
                optionsStack.addArrangedSubview(line)
            }
            optionsStack.addArrangedSubview(makeOptionRow(option))
        }
    }

    private func makeOptionRow(_ option: Option) -> UIControl {
        let isSelected = option.leadDays == selectedLeadDays

        let titleLabel = UILabel()
        titleLabel.text = option.title
        titleLabel.font = DesignSystem.Typography.rowTitle
        titleLabel.textColor = DesignSystem.Colors.textPrimary
        titleLabel.adjustsFontForContentSizeCategory = true

        // 20pt radio circle: hollow when unselected, accent check when selected.
        let radio = UIImageView()
        radio.translatesAutoresizingMaskIntoConstraints = false
        radio.contentMode = .scaleAspectFit
        if isSelected {
            radio.image = UIImage(systemName: "checkmark.circle.fill")
            radio.tintColor = DesignSystem.Colors.accent
        } else {
            radio.image = UIImage(systemName: "circle")
            radio.tintColor = DesignSystem.Colors.strokeControl
        }
        NSLayoutConstraint.activate([
            radio.widthAnchor.constraint(equalToConstant: 22),
            radio.heightAnchor.constraint(equalToConstant: 22)
        ])

        let row = UIStackView(arrangedSubviews: [titleLabel, UIView(), radio])
        row.axis = .horizontal
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 14, leading: 0, bottom: 14, trailing: 0)
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false

        let control = ReminderOptionControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        control.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: control.topAnchor),
            row.leadingAnchor.constraint(equalTo: control.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: control.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: control.bottomAnchor),
            control.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        control.onTap = { [weak self] in
            guard let self else { return }
            self.haptics.play(.selection)
            self.selectedLeadDays = option.leadDays
            self.rebuildOptions()
        }
        control.isAccessibilityElement = true
        control.accessibilityLabel = option.title
        control.accessibilityTraits = isSelected ? [.button, .selected] : .button
        return control
    }

    @objc private func didTapDone() {
        haptics.play(.lightImpact)
        onDone?(selectedLeadDays)
        dismiss(animated: true)
    }
}

private final class ReminderOptionControl: UIControl {
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(fire), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported.") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.65 : 1 }
    }

    @objc private func fire() { onTap?() }
}
