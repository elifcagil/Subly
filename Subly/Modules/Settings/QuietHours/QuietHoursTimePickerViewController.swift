import UIKit

/// Medium-detent sheet: Starts/Ends segment + wheel time picker (5-minute steps).
final class QuietHoursTimePickerViewController: UIViewController {

    enum Tab: Int { case start = 0, end = 1 }

    private let viewModel: QuietHoursViewModel
    private var activeTab: Tab
    private var startMinutes: Int
    private var endMinutes: Int
    private let titleLabel = UILabel()
    private let segments = SublySegmentedPills()
    private let picker = UIDatePicker()
    var onSet: ((_ startMinutes: Int, _ endMinutes: Int) -> Void)?

    init(viewModel: QuietHoursViewModel, tab: Tab) {
        self.viewModel = viewModel
        self.activeTab = tab
        self.startMinutes = viewModel.value.startMinutes
        self.endMinutes = viewModel.value.endMinutes
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = DesignSystem.Radius.sheet
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignSystem.Colors.sheet

        let cancel = UIButton(type: .system)
        cancel.setTitle(Strings.Common.cancel, for: .normal)
        cancel.titleLabel?.font = DesignSystem.Typography.body
        cancel.setTitleColor(DesignSystem.Colors.textSecondary, for: .normal)
        cancel.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)

        titleLabel.font = DesignSystem.Typography.scaled(17, weight: .heavy, relativeTo: .headline)
        titleLabel.textColor = DesignSystem.Colors.textPrimary
        titleLabel.textAlignment = .center

        let set = UIButton(type: .system)
        set.setTitle(Strings.QuietHours.set, for: .normal)
        set.titleLabel?.font = DesignSystem.Typography.scaled(15, weight: .bold, relativeTo: .body)
        set.setTitleColor(DesignSystem.Colors.accentText, for: .normal)
        set.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onSet?(self.startMinutes, self.endMinutes)
            self.dismiss(animated: true)
        }, for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [cancel, titleLabel, set])
        header.axis = .horizontal
        header.distribution = .equalCentering
        header.alignment = .center

        segments.onSelect = { [weak self] index in
            self?.haptics(.selection)
            self?.switchTab(Tab(rawValue: index) ?? .start)
        }

        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.minuteInterval = 5
        picker.addTarget(self, action: #selector(pickerChanged), for: .valueChanged)

        let caption = UILabel()
        caption.text = Strings.QuietHours.pickerCaption
        caption.font = DesignSystem.Typography.footnote
        caption.textColor = DesignSystem.Colors.textTertiary
        caption.textAlignment = .center
        caption.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [header, segments, picker, caption])
        stack.axis = .vertical
        stack.spacing = DesignSystem.Spacing.lg
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignSystem.Spacing.screenH),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignSystem.Spacing.screenH),
            picker.heightAnchor.constraint(equalToConstant: 200)
        ])
        refreshSegments()
        switchTab(activeTab)
    }

    private func refreshSegments() {
        segments.configure(
            segments: [
                .init(title: "\(Strings.QuietHours.starts) \(viewModel.timeText(minutes: startMinutes))"),
                .init(title: "\(Strings.QuietHours.ends) \(viewModel.timeText(minutes: endMinutes))")
            ],
            selectedIndex: activeTab.rawValue
        )
    }

    private func switchTab(_ newTab: Tab) {
        activeTab = newTab
        titleLabel.text = activeTab == .start ? Strings.QuietHours.startsAt : Strings.QuietHours.endsAt
        let minutes = activeTab == .start ? startMinutes : endMinutes
        picker.setDate(Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date(), animated: true)
        segments.setSelectedIndex(activeTab.rawValue, notify: false)
    }

    @objc private func pickerChanged() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: picker.date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        if activeTab == .start { startMinutes = minutes } else { endMinutes = minutes }
        refreshSegments()
    }

    private func haptics(_ event: HapticEvent) {
        (presentingViewController as? QuietHoursViewController)?.hapticsService.play(event)
    }
}

/// Multi-select weekday list ("Days" row). At least one day stays selected.
final class QuietHoursWeekdaysViewController: UITableViewController {

    private let calendar: Calendar
    private var selected: Set<Int>
    private let order: [Int]
    var onChange: ((Set<Int>) -> Void)?

    init(selected: Set<Int>, calendar: Calendar) {
        self.calendar = calendar
        self.selected = selected
        let first = calendar.firstWeekday
        self.order = (0..<7).map { ((first - 1 + $0) % 7) + 1 }
        super.init(style: .insetGrouped)
        title = Strings.QuietHours.days
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignSystem.Colors.background
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "day")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { order.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "day", for: indexPath)
        let weekday = order[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = calendar.standaloneWeekdaySymbols[weekday - 1]
        content.textProperties.font = DesignSystem.Typography.body
        content.textProperties.color = DesignSystem.Colors.textPrimary
        cell.contentConfiguration = content
        cell.backgroundColor = DesignSystem.Colors.surface
        cell.tintColor = DesignSystem.Colors.accentText
        cell.accessoryType = selected.contains(weekday) ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let weekday = order[indexPath.row]
        if selected.contains(weekday) {
            guard selected.count > 1 else { return }
            selected.remove(weekday)
        } else {
            selected.insert(weekday)
        }
        tableView.reloadRows(at: [indexPath], with: .none)
        onChange?(selected)
    }
}
