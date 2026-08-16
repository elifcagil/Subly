import UIKit

final class ReminderDefaultsViewController: UIViewController {

    private let viewModel: ReminderDefaultsViewModel
    private let haptics: HapticsService
    @IBOutlet private weak var tableView: UITableView!
    private let cellIdentifier = "ReminderDefaultsRow"
    private var rows: [ReminderDefaultsViewModel.Row] = []

    init(viewModel: ReminderDefaultsViewModel, haptics: HapticsService) {
        self.viewModel = viewModel
        self.haptics = haptics
        super.init(nibName: String(describing: Self.self), bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Strings.Settings.remindersPickerTitle
        view.backgroundColor = DesignSystem.Colors.background
        navigationItem.largeTitleDisplayMode = .never
        configureTable()
        configureBindings()
        viewModel.start()
    }

    private func configureTable() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = DesignSystem.Colors.background
    }

    private func configureBindings() {
        viewModel.onStateChange = { [weak self] state in
            guard case .loaded(let snapshot) = state else { return }
            self?.rows = snapshot.rows
            self?.tableView.reloadData()
        }
    }
}

extension ReminderDefaultsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        Strings.Settings.remindersPickerFooter
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        let row = rows[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = row.title
        content.textProperties.font = DesignSystem.Typography.body
        content.textProperties.color = DesignSystem.Colors.textPrimary
        cell.contentConfiguration = content
        cell.accessoryType = row.isSelected ? .checkmark : .none
        cell.tintColor = DesignSystem.Colors.accent
        cell.accessibilityLabel = row.title
        cell.accessibilityValue = row.isSelected ? "Selected" : nil
        cell.accessibilityTraits = row.isSelected ? [.button, .selected] : .button
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        haptics.play(.selection)
        viewModel.toggle(rows[indexPath.row].days)
    }
}
