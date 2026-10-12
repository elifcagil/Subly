import UIKit

/// Settings → Quiet hours (screen 01): ring card, presets, days / renewal-day
/// toggle, footnote. Master switch lives in the nav bar.
final class QuietHoursViewController: UIViewController {

    private let viewModel: QuietHoursViewModel
    let hapticsService: HapticsService

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let masterSwitch = UISwitch()
    private let ringCard = SublyCardView()
    private let ring = QuietHoursRingView()
    private let startTile = TimeTile()
    private let endTile = TimeTile()
    private var presetButtons: [UIButton] = []
    private let daysValueLabel = UILabel()
    private let renewalSwitch = UISwitch()
    private var isDragging = false

    var onOpenPicker: ((QuietHoursTimePickerViewController.Tab) -> Void)?
    var onOpenDays: (() -> Void)?

    init(viewModel: QuietHoursViewModel, haptics: HapticsService) {
        self.viewModel = viewModel
        self.hapticsService = haptics
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignSystem.Colors.background
        navigationItem.title = Strings.QuietHours.title
        navigationItem.largeTitleDisplayMode = .always
        masterSwitch.onTintColor = DesignSystem.Colors.accent
        masterSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.hapticsService.play(.selection)
            self.viewModel.setEnabled(self.masterSwitch.isOn)
        }, for: .valueChanged)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: masterSwitch)
        configureHierarchy()
        viewModel.onSnapshot = { [weak self] snapshot in self?.render(snapshot) }
        viewModel.start()
    }

    // MARK: - Hierarchy

    private func configureHierarchy() {
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        let side = DesignSystem.Spacing.screenH
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: side),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -side),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * side)
        ])

        let subtitle = UILabel()
        subtitle.text = Strings.QuietHours.subtitle
        subtitle.font = DesignSystem.Typography.subhead
        subtitle.textColor = DesignSystem.Colors.textSecondary
        subtitle.numberOfLines = 0
        contentStack.addArrangedSubview(subtitle)

        // Ring card
        ring.haptics = hapticsService
        ring.onChange = { [weak self] start, end, final in
            guard let self else { return }
            self.isDragging = !final
            self.viewModel.setRange(startMinutes: start, endMinutes: end)
        }
        startTile.configure(title: Strings.QuietHours.starts)
        endTile.configure(title: Strings.QuietHours.ends)
        startTile.addAction(UIAction { [weak self] _ in self?.hapticsService.play(.lightImpact); self?.onOpenPicker?(.start) }, for: .touchUpInside)
        endTile.addAction(UIAction { [weak self] _ in self?.hapticsService.play(.lightImpact); self?.onOpenPicker?(.end) }, for: .touchUpInside)
        let tiles = UIStackView(arrangedSubviews: [startTile, endTile])
        tiles.axis = .horizontal
        tiles.distribution = .fillEqually
        tiles.spacing = 10
        let ringColumn = UIStackView(arrangedSubviews: [ring, tiles])
        ringColumn.axis = .vertical
        ringColumn.alignment = .center
        ringColumn.spacing = 14
        tiles.widthAnchor.constraint(equalTo: ringColumn.widthAnchor).isActive = true
        ringColumn.translatesAutoresizingMaskIntoConstraints = false
        ringCard.addSubview(ringColumn)
        NSLayoutConstraint.activate([
            ringColumn.topAnchor.constraint(equalTo: ringCard.topAnchor, constant: 16),
            ringColumn.bottomAnchor.constraint(equalTo: ringCard.bottomAnchor, constant: -16),
            ringColumn.leadingAnchor.constraint(equalTo: ringCard.leadingAnchor, constant: 18),
            ringColumn.trailingAnchor.constraint(equalTo: ringCard.trailingAnchor, constant: -18)
        ])
        contentStack.addArrangedSubview(ringCard)

        // Presets
        let presets = UIStackView()
        presets.axis = .horizontal
        presets.distribution = .fillEqually
        presets.spacing = 8
        for (index, preset) in QuietHours.presets.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(String(format: "%02d–%02d", preset.start, preset.end), for: .normal)
            button.titleLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .bold)
            button.layer.cornerRadius = 17
            button.layer.borderWidth = 1
            button.heightAnchor.constraint(equalToConstant: 34).isActive = true
            button.addAction(UIAction { [weak self] _ in
                self?.hapticsService.play(.lightImpact)
                self?.viewModel.applyPreset(index)
            }, for: .touchUpInside)
            presets.addArrangedSubview(button)
            presetButtons.append(button)
        }
        contentStack.addArrangedSubview(presets)

        // Days + renewal-day alerts card
        let card = SublyCardView()
        let daysRow = UIControl()
        let daysTitle = UILabel()
        daysTitle.text = Strings.QuietHours.days
        daysTitle.font = DesignSystem.Typography.body
        daysTitle.textColor = DesignSystem.Colors.textPrimary
        daysValueLabel.font = DesignSystem.Typography.body
        daysValueLabel.textColor = DesignSystem.Colors.textSecondary
        daysValueLabel.textAlignment = .right
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = DesignSystem.Colors.textTertiary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let daysStack = UIStackView(arrangedSubviews: [daysTitle, daysValueLabel, chevron])
        daysStack.axis = .horizontal
        daysStack.alignment = .center
        daysStack.spacing = 6
        daysStack.isUserInteractionEnabled = false
        daysStack.translatesAutoresizingMaskIntoConstraints = false
        daysRow.addSubview(daysStack)
        daysRow.addAction(UIAction { [weak self] _ in self?.hapticsService.play(.selection); self?.onOpenDays?() }, for: .touchUpInside)
        daysRow.accessibilityTraits = .button
        NSLayoutConstraint.activate([
            daysStack.topAnchor.constraint(equalTo: daysRow.topAnchor, constant: 12),
            daysStack.bottomAnchor.constraint(equalTo: daysRow.bottomAnchor, constant: -12),
            daysStack.leadingAnchor.constraint(equalTo: daysRow.leadingAnchor),
            daysStack.trailingAnchor.constraint(equalTo: daysRow.trailingAnchor)
        ])
        let separator = UIView()
        separator.backgroundColor = DesignSystem.Colors.separator
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let renewalTitle = UILabel()
        renewalTitle.text = Strings.QuietHours.renewalAlerts
        renewalTitle.font = DesignSystem.Typography.body
        renewalTitle.textColor = DesignSystem.Colors.textPrimary
        let renewalSubtitle = UILabel()
        renewalSubtitle.text = Strings.QuietHours.renewalAlertsSubtitle
        renewalSubtitle.font = DesignSystem.Typography.footnote
        renewalSubtitle.textColor = DesignSystem.Colors.textSecondary
        renewalSubtitle.numberOfLines = 0
        let renewalColumn = UIStackView(arrangedSubviews: [renewalTitle, renewalSubtitle])
        renewalColumn.axis = .vertical
        renewalColumn.spacing = 1
        renewalSwitch.onTintColor = DesignSystem.Colors.accent
        renewalSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.hapticsService.play(.selection)
            self.viewModel.setRenewalDayAlerts(self.renewalSwitch.isOn)
        }, for: .valueChanged)
        let renewalRow = UIStackView(arrangedSubviews: [renewalColumn, renewalSwitch])
        renewalRow.axis = .horizontal
        renewalRow.alignment = .center
        renewalRow.spacing = 12
        renewalRow.layoutMargins = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        renewalRow.isLayoutMarginsRelativeArrangement = true

        let cardColumn = UIStackView(arrangedSubviews: [daysRow, separator, renewalRow])
        cardColumn.axis = .vertical
        cardColumn.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardColumn)
        NSLayoutConstraint.activate([
            cardColumn.topAnchor.constraint(equalTo: card.topAnchor, constant: 2),
            cardColumn.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -2),
            cardColumn.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            cardColumn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18)
        ])
        contentStack.addArrangedSubview(card)

        // Footnote with accent emphasis
        let footnote = UILabel()
        footnote.numberOfLines = 0
        let text = Strings.QuietHours.footnote
        let attributed = NSMutableAttributedString(string: text, attributes: [
            .font: DesignSystem.Typography.footnote, .foregroundColor: DesignSystem.Colors.textTertiary
        ])
        if let range = text.range(of: Strings.QuietHours.footnoteEmphasis) {
            attributed.addAttributes([
                .foregroundColor: DesignSystem.Colors.accentText,
                .font: DesignSystem.Typography.scaled(13, weight: .bold, relativeTo: .footnote)
            ], range: NSRange(range, in: text))
        }
        footnote.attributedText = attributed
        contentStack.addArrangedSubview(footnote)
    }

    // MARK: - Render

    private func render(_ snapshot: QuietHoursViewModel.Snapshot) {
        masterSwitch.setOn(snapshot.isEnabled, animated: false)
        if !isDragging {
            ring.setRange(startMinutes: snapshot.value.startMinutes, endMinutes: snapshot.value.endMinutes, animated: ring.window != nil)
        }
        ring.durationText = snapshot.durationText
        ring.accessibilityValueText = Strings.QuietHours.accessibilityRing(
            start: snapshot.startText, end: snapshot.endText, duration: snapshot.durationText
        )
        startTile.setValue(snapshot.startText)
        endTile.setValue(snapshot.endText)
        daysValueLabel.text = snapshot.daysText
        renewalSwitch.setOn(snapshot.value.renewalDayAlertsWithSound, animated: false)
        for (index, button) in presetButtons.enumerated() {
            let selected = index == snapshot.selectedPreset
            button.backgroundColor = selected ? DesignSystem.Colors.accent : DesignSystem.Colors.surface
            button.layer.borderColor = (selected ? DesignSystem.Colors.accent : DesignSystem.Colors.strokeControl).cgColor
            button.setTitleColor(selected ? DesignSystem.Colors.accentOnFill : DesignSystem.Colors.textSecondary, for: .normal)
        }
        // Master switch off → ring card dimmed and inert.
        UIView.animate(withDuration: 0.2) {
            self.ringCard.alpha = snapshot.isEnabled ? 1 : 0.4
        }
        ringCard.isUserInteractionEnabled = snapshot.isEnabled
        presetButtons.forEach { $0.isEnabled = snapshot.isEnabled }
    }

    /// "Starts / 22:00" tile below the ring.
    private final class TimeTile: UIControl {
        private let titleLabel = UILabel()
        private let valueLabel = UILabel()

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = DesignSystem.Colors.background
            layer.cornerRadius = 14
            layer.cornerCurve = .continuous
            layer.borderWidth = 1
            layer.borderColor = DesignSystem.Colors.separator.cgColor
            titleLabel.font = DesignSystem.Typography.scaled(12, weight: .semibold, relativeTo: .caption1)
            titleLabel.textColor = DesignSystem.Colors.textSecondary
            valueLabel.font = DesignSystem.Typography.scaled(22, weight: .heavy, relativeTo: .title2, tabular: true)
            valueLabel.textColor = DesignSystem.Colors.textPrimary
            valueLabel.adjustsFontSizeToFitWidth = true
            valueLabel.minimumScaleFactor = 0.7
            let column = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
            column.axis = .vertical
            column.spacing = 1
            column.isUserInteractionEnabled = false
            column.translatesAutoresizingMaskIntoConstraints = false
            addSubview(column)
            NSLayoutConstraint.activate([
                column.topAnchor.constraint(equalTo: topAnchor, constant: 10),
                column.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
                column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
                column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
            ])
            accessibilityTraits = .button
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        func configure(title: String) { titleLabel.text = title }
        func setValue(_ value: String) {
            valueLabel.text = value
            accessibilityLabel = "\(titleLabel.text ?? ""), \(value)"
        }

        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            layer.borderColor = DesignSystem.Colors.separator.cgColor
        }
    }
}
